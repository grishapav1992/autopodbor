import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Web implementation — no certificate pinning.
///
/// Browsers do not expose the certificate chain to JS, so application-level
/// pinning is impossible on the web platform. Web builds rely entirely on the
/// browser/OS TLS stack (which enforces CA validation and HSTS). This is an
/// accepted platform limitation: pinning here is a no-op rather than a
/// failure, so RPC clients and the WebSocket keep working.
http.Client makePinnedHttpClient() => http.Client();

/// Web WebSocket connector — delegates to the platform default. Pinning is a
/// no-op on web (see [makePinnedHttpClient]).
WebSocketChannel connectPinnedWebSocketChannel(Uri uri) =>
    WebSocketChannel.connect(uri);
