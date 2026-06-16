import 'package:flutter/foundation.dart';

/// Certificate (public-key) pinning configuration.
///
/// Pinning guards against MITM by a device with a user-installed CA, a
/// malicious proxy (Charles / mitmproxy on a rooted device), or a compromised
/// CA: even if the attacker presents a validly-chained certificate, it won't
/// match the pinned SubjectPublicKeyInfo (SPKI) hashes and the TLS handshake
/// is rejected.
///
/// Each value is the base64-encoded SHA-256 of the certificate's DER-encoded
/// SubjectPublicKeyInfo — the same format used by HPKP / TrustKit / OkHttp's
/// CertificatePinner. We pin the public *key*, not the certificate itself, so
/// a renewal that reuses the key keeps working.
///
/// ⚠️ IMPORTANT — DART LIMITATION:
/// `HttpClient.badCertificateCallback` exposes ONLY the leaf certificate,
/// not the full chain. We therefore verify leaf SPKI only. The intermediate
/// CA pin is documented below for the rotation runbook (see SECURITY.md) but
/// is NOT actively checked by the client. A proper chain pin would require a
/// native TLS plugin or a raw SecureSocket transport — tracked separately.
///
/// ⚠️ ROTATION CADENCE:
/// carreports.ru uses Let's Encrypt, which rotates the LEAF roughly every 90
/// days (and issues a fresh key pair each time). The current pin set must be
/// extended with each rotation and a new app build shipped BEFORE the old
/// leaf expires — otherwise release builds fail to connect. See the runbook
/// in SECURITY.md → "Cert pinning rotation".
class CertPins {
  CertPins._();

  /// Master switch. Defaults to ON in release builds only — debug builds skip
  /// pinning so developers can inspect traffic with Charles / mitmproxy.
  ///
  /// Override at build time with
  ///   --dart-define=CERT_PINNING=true|false
  /// to force a specific mode (e.g. QA a release build without pinning).
  static const bool enabled = bool.fromEnvironment(
    'CERT_PINNING',
    defaultValue: kReleaseMode,
  );

  /// Pinned SPKI hashes per host. Multiple pins per host are accepted — keep
  /// the PREVIOUS leaf pin around for one rotation cycle as a safety net, so
  /// a back-end rollback or a second renewal doesn't break already-shipped
  /// builds.
  ///
  /// All three carreports.ru hosts share one certificate, so they share one
  /// pin set.
  static const Map<String, Set<String>> byHost = {
    'app.carreports.ru': {
      // Current leaf — CN=app.carreports.ru, valid 2026-06-16 .. 2026-09-14.
      'XCR1wYjnywKkDVarf6Y7NnE3T+AxpL4n+CqNfG3d5WE=',
      // Previous leaf — CN=app.carreports.ru (rotated out 2026-06-16). Kept
      // for one cycle as a rollback safety net; remove after the next
      // rotation is confirmed stable in production.
      'yq74wyn28jTDXpEfFimpWRng2BxD6LuR2lDQHOO75IA=',
    },
    'ai.carreports.ru': {
      'XCR1wYjnywKkDVarf6Y7NnE3T+AxpL4n+CqNfG3d5WE=',
      'yq74wyn28jTDXpEfFimpWRng2BxD6LuR2lDQHOO75IA=',
    },
    'ws.carreports.ru': {
      'XCR1wYjnywKkDVarf6Y7NnE3T+AxpL4n+CqNfG3d5WE=',
      'yq74wyn28jTDXpEfFimpWRng2BxD6LuR2lDQHOO75IA=',
    },
  };

  /// Intermediate CA reference (NOT verified by the client — see class docs).
  /// CN=YE1, Let's Encrypt, valid 2025-09-03 .. 2028-09-02. Documented so the
  /// rotation runbook knows which CA the leaves chain to.
  static const String intermediateYe1Pin =
      'brzvtCELCIZUo4sD/qPX0ccRtPsd3DY6RfmxpOU9oB4=';

  /// Returns the accepted pin set for [host], or null when the host is not
  /// pinned (the caller must fail closed — never silently accept).
  static Set<String>? pinsFor(String host) => byHost[host];
}
