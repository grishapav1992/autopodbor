/// Platform-routed entry point for the pinned HTTP client.
///
/// On IO platforms (Android / iOS / macOS / Windows / Linux) the IO variant
/// wires up certificate public-key pinning via a pinned [dart:io HttpClient].
/// On the web platform pinning is impossible (browsers don't expose the cert
/// chain to JS), so the web variant returns a plain client.
///
/// Consumers (RPC clients, WebSocket service) import THIS file and call
/// [makePinnedHttpClient]; they never import the platform variants directly.
library;

export 'pinned_http_client_io.dart'
    if (dart.library.html) 'pinned_http_client_web.dart';
