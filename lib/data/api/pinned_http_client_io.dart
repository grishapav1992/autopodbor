import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_application_1/core/config/cert_pins.dart';
import 'package:flutter_application_1/data/api/spki_extractor.dart';

/// Builds the [http.Client] used by every RPC client (Storage / AiQueue /
/// Notification / Feedback).
///
/// - When [CertPins.enabled] is false (debug builds): returns a plain
///   [http.Client()], so developers can use Charles / mitmproxy.
/// - When enabled (release builds): returns an [http.IOClient] wrapping an
///   [HttpClient] whose `badCertificateCallback` rejects any chain whose
///   leaf certificate's SPKI does not match a pinned hash for the host.
///   This blocks MITM by a user-installed CA / malicious proxy / compromised
///   CA while the device carries auth tokens.
///
/// The WebSocket transport shares the same pinning via [pinnedHttpClient].
http.Client makePinnedHttpClient() {
  if (!CertPins.enabled) {
    // In debug we mirror the behaviour of the top-level `http.post` helper,
    // which opens a fresh client per request and closes it afterwards. A
    // long-lived singleton client here was observed to hang the first RPC
    // (Storage.Auth) for 30s on a physical iOS device: a stuck keep-alive
    // connection blocks subsequent requests on the shared pool. Returning a
    // short-lived client lets each request own its own connection lifecycle.
    return http.Client();
  }
  // Release: give EACH RPC client its own pinned [HttpClient] (NOT the shared
  // singleton). On iOS a stale keep-alive connection left in the *shared* pool
  // by an earlier call (bootstrap RefreshToken / the notification WebSocket)
  // hung the next Storage.Auth for ~30s — the release-only login failure
  // (debug works because it returns a plain per-client http.Client() above, so
  // it never shared a pool). Per-client pools + a short idleTimeout (see
  // [_newPinnedHttpClient]) stop a dead connection from being reused. Pinning
  // is preserved via badCertificateCallback.
  return IOClient(_newPinnedHttpClient());
}

/// Opens a WebSocket channel to [uri] using the same pinning policy as the
/// HTTP clients. In release the underlying [HttpClient] enforces cert
/// public-key pinning; in debug it's the system default (Charles works).
///
/// Used by NotificationWebsocketService so the realtime channel inherits the
/// same MITM defence as RPC calls.
WebSocketChannel connectPinnedWebSocketChannel(Uri uri) {
  if (!CertPins.enabled) {
    return WebSocketChannel.connect(uri);
  }
  return IOWebSocketChannel.connect(uri, customClient: pinnedHttpClient);
}

/// The shared pinned [HttpClient]. Held as a single instance so every caller
/// reuses one connection pool; `badCertificateCallback` is stateless so
/// sharing is safe. Lazily initialized and never closed for the app's
/// lifetime (closing would break subsequent RPC calls).
@visibleForTesting
HttpClient? pinnedHttpClientForTest;

HttpClient get pinnedHttpClient {
  // Test seam: allow tests to inject a fresh client after toggling
  // CertPins.enabled via --dart-define between runs.
  if (pinnedHttpClientForTest != null) return pinnedHttpClientForTest!;
  return _instance ??= _newPinnedHttpClient();
}

HttpClient? _instance;

/// Builds a fresh pinned [HttpClient]: pins the leaf SPKI via
/// [_pinningCallback], and bounds the connection lifecycle so a stale
/// keep-alive connection can't hang a later request on iOS:
/// - [HttpClient.connectionTimeout] caps a stuck TCP/TLS connect.
/// - A short [HttpClient.idleTimeout] (3s vs the 15s default) reaps idle
///   keep-alive connections quickly, so one left over from a prior call isn't
///   reused dead across the (idle) login wait.
///
/// Used per-RPC-client by [makePinnedHttpClient] (no shared pool) and once for
/// the WebSocket singleton via [pinnedHttpClient].
HttpClient _newPinnedHttpClient() {
  final test = pinnedHttpClientForTest;
  if (test != null) return test;
  return HttpClient()
    ..badCertificateCallback = _pinningCallback
    ..connectionTimeout = const Duration(seconds: 10)
    ..idleTimeout = const Duration(seconds: 3);
}

/// Pinning validation: returns `true` ONLY when the leaf cert's SPKI matches
/// a pinned hash for [host]. Fail-closed: unpinned hosts are rejected —
/// every endpoint we hit is listed in [CertPins.byHost], so an unknown host
/// means something is misconfigured.
bool _pinningCallback(X509Certificate cert, String host, int port) {
  final pins = CertPins.pinsFor(host);
  if (pins == null || pins.isEmpty) return false;
  final spki = extractSubjectPublicKeyInfo(cert.der);
  if (spki == null) return false;
  final hash = crypto.sha256.convert(spki);
  final b64 = base64.encode(hash.bytes);
  return pins.contains(b64);
}
