import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter_application_1/data/api/ai_queue_api.dart';
import 'package:flutter_application_1/data/api/storage_api.dart'
    show StorageApi, SessionExpiredException;
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';

/// Persisted file reference for an AiQueue pending op. We never store
/// presigned URLs because they expire in hours while a pending op may
/// live for days; instead we keep the key pieces and resolve a fresh
/// presigned URL right before the actual `chatCompletions` call.
class AiQueueFileRef {
  final String reportNumber;
  final String filename;

  const AiQueueFileRef({required this.reportNumber, required this.filename});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'reportNumber': reportNumber,
        'filename': filename,
      };

  static AiQueueFileRef? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final reportNumber = m['reportNumber']?.toString() ?? '';
    final filename = m['filename']?.toString() ?? '';
    if (filename.isEmpty) return null;
    return AiQueueFileRef(reportNumber: reportNumber, filename: filename);
  }
}

class AiQueuePendingOp {
  final String opId;
  final int chatId;
  final String sourceKey;
  final String text;
  final String cliche;
  final String? model;
  final List<AiQueueFileRef> fileRefs;
  final String createdAt;
  int attempts;
  String? lastError;

  AiQueuePendingOp({
    required this.opId,
    required this.chatId,
    required this.sourceKey,
    required this.text,
    required this.cliche,
    this.model,
    this.fileRefs = const <AiQueueFileRef>[],
    String? createdAt,
    this.attempts = 0,
    this.lastError,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toJson() => <String, dynamic>{
        'opId': opId,
        'chatId': chatId,
        'sourceKey': sourceKey,
        'text': text,
        'cliche': cliche,
        if (model != null) 'model': model,
        'fileRefs': fileRefs.map((f) => f.toJson()).toList(),
        'createdAt': createdAt,
        'attempts': attempts,
        if (lastError != null) 'lastError': lastError,
      };

  static AiQueuePendingOp? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final opId = m['opId']?.toString() ?? '';
    final chatId = m['chatId'] is int
        ? m['chatId'] as int
        : int.tryParse(m['chatId']?.toString() ?? '');
    final sourceKey = m['sourceKey']?.toString() ?? '';
    final text = m['text']?.toString() ?? '';
    final cliche = m['cliche']?.toString() ?? '';
    if (opId.isEmpty || chatId == null || sourceKey.isEmpty || cliche.isEmpty) {
      return null;
    }
    final fileRefs = <AiQueueFileRef>[];
    final rawRefs = m['fileRefs'];
    if (rawRefs is List) {
      for (final r in rawRefs) {
        final ref = AiQueueFileRef.tryFromJson(r);
        if (ref != null) fileRefs.add(ref);
      }
    }
    return AiQueuePendingOp(
      opId: opId,
      chatId: chatId,
      sourceKey: sourceKey,
      text: text,
      cliche: cliche,
      model: m['model']?.toString(),
      fileRefs: fileRefs,
      createdAt: m['createdAt']?.toString(),
      attempts: m['attempts'] is int ? m['attempts'] as int : 0,
      lastError: m['lastError']?.toString(),
    );
  }
}

/// Snapshot of runner state per draft for UI consumption.
class AiQueueRunnerStatus {
  final String draftId;
  final int pendingCount;
  final bool inflight;
  final int failedCount;
  const AiQueueRunnerStatus({
    required this.draftId,
    required this.pendingCount,
    required this.inflight,
    required this.failedCount,
  });
}

/// Single result of an op: text body + chatId + sourceKey.
class AiQueueRunnerResult {
  final String draftId;
  final String sourceKey;
  final int chatId;
  final String text;
  const AiQueueRunnerResult({
    required this.draftId,
    required this.sourceKey,
    required this.chatId,
    required this.text,
  });
}

class _DraftState {
  final String draftId;
  final List<AiQueuePendingOp> pending = <AiQueuePendingOp>[];
  bool inflight = false;
  Timer? backoffTimer;
  final StreamController<AiQueueRunnerStatus> statusCtrl =
      StreamController<AiQueueRunnerStatus>.broadcast();
  final StreamController<AiQueueRunnerResult> resultCtrl =
      StreamController<AiQueueRunnerResult>.broadcast();

  _DraftState(this.draftId);

  int get failedCount => pending.where((op) => (op.lastError ?? '').isNotEmpty).length;

  AiQueueRunnerStatus snapshot() => AiQueueRunnerStatus(
        draftId: draftId,
        pendingCount: pending.length,
        inflight: inflight,
        failedCount: failedCount,
      );

  void emitStatus() {
    if (!statusCtrl.isClosed) statusCtrl.add(snapshot());
  }

  Future<void> dispose() async {
    backoffTimer?.cancel();
    await statusCtrl.close();
    await resultCtrl.close();
  }
}

/// Single-instance offline-aware queue for `AiQueue.ChatCompletions`.
///
/// Lifecycle:
///   - [enqueue] → persist op into draft, attempt immediate send. On
///     transport / 5xx failure the op stays in the queue and a periodic
///     health probe takes over.
///   - [flush] → drain pending one-by-one until success / max attempts /
///     blocking-timeout (callers pre-submit the report this way).
///   - [watchStatus] / [watchResults] → UI streams.
///
/// Connectivity is probed via `AiQueue.Health` because we deliberately
/// avoid pulling `connectivity_plus` for one feature; a short timeout
/// against the same backend we'd be hitting anyway is the cheapest
/// reliable signal.
class AiQueueOfflineRunner {
  AiQueueOfflineRunner._();
  static final AiQueueOfflineRunner instance = AiQueueOfflineRunner._();

  final Map<String, _DraftState> _states = <String, _DraftState>{};
  Timer? _healthTimer;

  static const _backoffSchedule = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 60),
  ];
  static const _maxAttempts = 3;
  static const _healthProbeInterval = Duration(seconds: 30);

  Stream<AiQueueRunnerStatus> watchStatus(String draftId) {
    return _stateFor(draftId).statusCtrl.stream;
  }

  Stream<AiQueueRunnerResult> watchResults(String draftId) {
    return _stateFor(draftId).resultCtrl.stream;
  }

  AiQueueRunnerStatus statusOf(String draftId) {
    final existing = _states[draftId];
    if (existing != null) return existing.snapshot();
    return AiQueueRunnerStatus(
      draftId: draftId,
      pendingCount: 0,
      inflight: false,
      failedCount: 0,
    );
  }

  /// Snapshot of the current pending list for [draftId] in JSON shape.
  /// Used by the autosave path so the full draft write doesn't drop
  /// pending ops the runner already accepted.
  List<Map<String, dynamic>> snapshotPendingForDraft(String draftId) {
    final existing = _states[draftId];
    if (existing == null) return const <Map<String, dynamic>>[];
    return existing.pending.map((p) => p.toJson()).toList();
  }

  /// Loads any pending ops from the persisted draft into the runner.
  /// Synchronous: callers rely on this finishing before the UI can
  /// race-enqueue a new op for the same draft. The follow-up drain
  /// attempt is fire-and-forget.
  void hydrateFromDraft({
    required String draftId,
    required Map<String, dynamic>? rawAiQueue,
  }) {
    if (rawAiQueue == null) return;
    final state = _stateFor(draftId);
    state.pending.clear();
    final rawPending = rawAiQueue['pending'];
    if (rawPending is List) {
      for (final raw in rawPending) {
        final op = AiQueuePendingOp.tryFromJson(raw);
        if (op != null) state.pending.add(op);
      }
    }
    state.emitStatus();
    if (state.pending.isNotEmpty) {
      _scheduleHealthProbe();
      // Try immediately — if we just resumed from background and the
      // network is up, the op should fly without waiting 30s.
      unawaited(_tryDrain(state));
    }
  }

  /// Persists [op] into the draft and tries to send right away. The
  /// returned future resolves to:
  ///   - non-null result text if the call landed online,
  ///   - null if the op is queued (offline / transient failure).
  Future<String?> enqueue({
    required String draftId,
    required AiQueuePendingOp op,
  }) async {
    final state = _stateFor(draftId);
    // Dedupe by sourceKey: if the user re-clicks AI on the same
    // element, replace the previous pending request — the latest
    // input is what they want sent.
    state.pending.removeWhere((p) => p.sourceKey == op.sourceKey);
    state.pending.add(op);
    state.emitStatus();
    await _persistPending(draftId, state);

    try {
      final text = await _sendOnce(op);
      _onOpSucceeded(state, op, text);
      await _persistPending(draftId, state);
      _emitResult(state, op, text);
      return text;
    } on SessionExpiredException {
      // Auth dead — bubble up to the UI immediately; do NOT keep this
      // op in the queue under another user's session later. We pop it
      // and let the global expiry handler take over.
      state.pending.removeWhere((p) => p.opId == op.opId);
      state.emitStatus();
      await _persistPending(draftId, state);
      rethrow;
    } catch (e) {
      op.attempts += 1;
      op.lastError = e.toString();
      _log('enqueue-failed', draftId: draftId, extra: 'op=${op.opId} err=$e');
      state.emitStatus();
      await _persistPending(draftId, state);
      _scheduleHealthProbe();
      return null;
    }
  }

  /// Drains pending ops until the queue is empty or [timeout] expires.
  /// Returns the number of successfully sent ops. When [blocking] is
  /// true, throws [TimeoutException] on partial completion so callers
  /// (submit handler) can show a fallback dialog.
  Future<int> flush({
    required String draftId,
    bool blocking = false,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final state = _states[draftId];
    if (state == null || state.pending.isEmpty) return 0;
    final deadline = DateTime.now().add(timeout);
    var sent = 0;
    while (state.pending.isNotEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        if (blocking) {
          throw TimeoutException(
            'AiQueue flush did not finish within ${timeout.inSeconds}s '
            '(${state.pending.length} ops left)',
          );
        }
        break;
      }
      final op = state.pending.first;
      try {
        final text = await _sendOnce(op);
        _onOpSucceeded(state, op, text);
        await _persistPending(draftId, state);
        _emitResult(state, op, text);
        sent += 1;
      } on SessionExpiredException {
        rethrow;
      } catch (e) {
        op.attempts += 1;
        op.lastError = e.toString();
        await _persistPending(draftId, state);
        if (op.attempts >= _maxAttempts) {
          // Give up on this op for the current flush window — keep it
          // around for manual retry, move on so the rest don't starve.
          _log('flush-give-up', draftId: draftId, extra: 'op=${op.opId} err=$e');
          if (blocking) {
            throw Exception(
              'AiQueue op ${op.opId} failed after ${op.attempts} attempts: $e',
            );
          }
          break;
        }
        // Online retry backoff (we know we're online enough to have
        // gotten an error from the server, vs a connectivity timeout).
        final delay = _backoffSchedule[
            math.min(op.attempts - 1, _backoffSchedule.length - 1)];
        await Future<void>.delayed(delay);
      }
    }
    state.emitStatus();
    return sent;
  }

  /// Wipes all per-draft state (used on logout / draft purge).
  Future<void> dropDraft(String draftId) async {
    final state = _states.remove(draftId);
    if (state != null) await state.dispose();
    if (_states.isEmpty) {
      _healthTimer?.cancel();
      _healthTimer = null;
    }
  }

  /// Tear down everything (logout). Cleans memory state but does NOT
  /// touch the persisted draft contents — callers handle draft wipe.
  Future<void> resetAll() async {
    _healthTimer?.cancel();
    _healthTimer = null;
    final futures = _states.values.map((s) => s.dispose()).toList();
    _states.clear();
    await Future.wait(futures);
  }

  // ── Internals ─────────────────────────────────────────────────────────

  _DraftState _stateFor(String draftId) {
    return _states.putIfAbsent(draftId, () => _DraftState(draftId));
  }

  void _onOpSucceeded(_DraftState state, AiQueuePendingOp op, String text) {
    state.pending.removeWhere((p) => p.opId == op.opId);
    state.emitStatus();
  }

  void _emitResult(_DraftState state, AiQueuePendingOp op, String text) {
    if (!state.resultCtrl.isClosed) {
      state.resultCtrl.add(AiQueueRunnerResult(
        draftId: state.draftId,
        sourceKey: op.sourceKey,
        chatId: op.chatId,
        text: text,
      ));
    }
  }

  /// Calls aiqueue once for a single op. Resolves presigned URLs lazily
  /// — if the file is not yet on S3 (presigned returns empty), we drop
  /// it from this call and continue text-only rather than failing the
  /// whole op.
  Future<String> _sendOnce(AiQueuePendingOp op) async {
    final fileUrls = <String>[];
    for (final ref in op.fileRefs) {
      if (ref.reportNumber.isEmpty) continue; // draft hasn't been prepared yet
      final url = await StorageApi.getTemporaryViewUrl(
        reportNumber: ref.reportNumber,
        filename: ref.filename,
      );
      if (url.isNotEmpty) fileUrls.add(url);
    }
    final result = await AiQueueApi.chatCompletions(
      chatId: op.chatId,
      text: op.text,
      cliche: op.cliche,
      fileUrls: fileUrls.isEmpty ? null : fileUrls,
      model: op.model,
    );
    // Empty content is not an error — the call landed and history is
    // updated server-side. Returning '' lets the UI surface the
    // queue-success path without dumping a raw map dictionary into
    // the inspector's note field.
    return result.text;
  }

  Future<void> _tryDrain(_DraftState state) async {
    if (state.inflight || state.pending.isEmpty) return;
    state.inflight = true;
    state.emitStatus();
    try {
      // Probe network with a lightweight Health call; bail early when
      // offline so we don't burn through retries against a dead pipe.
      final isUp = await _probeOnline();
      if (!isUp) return;
      while (state.pending.isNotEmpty) {
        final op = state.pending.first;
        try {
          final text = await _sendOnce(op);
          _onOpSucceeded(state, op, text);
          await _persistPending(state.draftId, state);
          _emitResult(state, op, text);
        } on SessionExpiredException {
          rethrow;
        } catch (e) {
          op.attempts += 1;
          op.lastError = e.toString();
          await _persistPending(state.draftId, state);
          // On online failure, pause the drain — backoff before next
          // attempt instead of hot-looping.
          final delay = _backoffSchedule[
              math.min(op.attempts - 1, _backoffSchedule.length - 1)];
          await Future<void>.delayed(delay);
          if (op.attempts >= _maxAttempts) break;
        }
      }
    } finally {
      state.inflight = false;
      state.emitStatus();
    }
  }

  Future<bool> _probeOnline() async {
    try {
      final h = await AiQueueApi.health();
      return h.isOk;
    } catch (_) {
      return false;
    }
  }

  void _scheduleHealthProbe() {
    if (_healthTimer != null) return;
    _healthTimer = Timer.periodic(_healthProbeInterval, (_) async {
      // Stop probing if every state is empty — saves battery.
      final hasPending = _states.values.any((s) => s.pending.isNotEmpty);
      if (!hasPending) {
        _healthTimer?.cancel();
        _healthTimer = null;
        return;
      }
      for (final state in _states.values) {
        if (state.pending.isEmpty) continue;
        unawaited(_tryDrain(state));
      }
    });
  }

  Future<void> _persistPending(String draftId, _DraftState state) async {
    await SparkJoyStorage.applyDraftPatch(
      draftId: draftId,
      mutate: (draft) {
        final aiQueue = draft['aiQueue'] is Map
            ? Map<String, dynamic>.from(draft['aiQueue'] as Map)
            : <String, dynamic>{};
        aiQueue['pending'] = state.pending.map((p) => p.toJson()).toList();
        draft['aiQueue'] = aiQueue;
      },
    );
  }

  static void _log(String stage, {required String draftId, String extra = ''}) {
    final suffix = extra.trim().isEmpty ? '' : ' $extra';
    developer.log(
      '[$stage][draft=$draftId]$suffix',
      name: 'AiQueueOfflineRunner',
    );
  }
}
