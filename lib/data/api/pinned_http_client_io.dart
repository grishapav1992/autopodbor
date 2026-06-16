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
    return http.Client();
  }
  return IOClient(pinnedHttpClient);
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
  return _instance ??= HttpClient()
    ..badCertificateCallback = _pinningCallback;
}

HttpClient? _instance;

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
