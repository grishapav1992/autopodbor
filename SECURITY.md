# Security policy

This document covers operational security runbooks for the `autopodbor`
(carreports.ru) Flutter client. It is aimed at the on-call / release engineer
audience and complements the in-code comments in
`lib/core/config/cert_pins.dart` and `lib/data/api/pinned_http_client.dart`.

---

## 🔴 Action required: rotate exposed tokens (2026-06-15)

A Postman collection (`autopodbor_11_04.postman_collection.json`) was found in
the working tree with three **live** credentials hardcoded:

| Location (line) | Field            | Value (masked)            | Likely role                |
|-----------------|------------------|---------------------------|----------------------------|
| 503             | integration `key`| `MlnC…A1H`                | Postman integration key    |
| 531             | bearer `token`   | `7bNm…6LCk`               | RPC access token           |
| 937             | query `token`    | `40fd3e…61220` (64 hex)   | Notification WebSocket auth |

The file was `.gitignore`d and **never tracked by git**, so there is no leak
via the repository. However, the credentials existed on disk and must be
treated as compromised.

**Status:** the file has been deleted from the working tree.

**Required backend action:** rotate all three tokens. They must be considered
compromised regardless of deletion — a local copy may persist in backups,
IDE caches, or screenshots.

**Prevention:** when sharing a Postman collection, scrub token values to
environment variables (`{{access_token}}`) and never commit the environment.

---

## Cert pinning rotation runbook

The app pins certificate public keys (SPKI SHA-256) for
`app.carreports.ru`, `ai.carreports.ru`, `ws.carreports.ru` — see
`lib/core/config/cert_pins.dart`. Pinning is **active in release builds
only** (`kReleaseMode`); debug builds skip it so developers can inspect
traffic with Charles / mitmproxy.

### Why pinning breaks

The backend uses **Let's Encrypt**, which rotates the leaf certificate
roughly every 90 days **and issues a fresh key pair each time**. Each
rotation invalidates the matching leaf pin. Without an app update, every
installed release build will fail TLS handshakes → no RPC, no WebSocket.

> Observed live on 2026-06-16: the leaf SPKI rotated from
> `yq74wyn2…75IA=` to `XCR1wYjn…d5WE=` during the security audit itself.
>
> Observed live on 2026-07-06 (incident): the leaf rotated EARLY on
> 2026-07-02 (`XCR1wYjn…d5WE=` → `5Nj0yToN…U1n8=`, ~2.5 months before the
> old leaf's expiry) and the intermediate switched YE1 → YE2. Shipped
> release builds (RuStore 1.0.0+3 / iOS) carried only the stale pins:
> devices whose OS trust store fails to validate the new chain themselves
> (observed on iPhone) got `badCertificateCallback` → pin mismatch → every
> RPC failed, i.e. login was impossible. Rotation timing is NOT tied to
> expiry — re-capture the pin before every release build.

### Before every leaf rotation

1. **Capture the new pin** (run from a machine with network access):
   ```sh
   echo | openssl s_client -servername app.carreports.ru \
     -connect app.carreports.ru:443 2>/dev/null \
     | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' \
     > /tmp/leaf.pem
   openssl x509 -in /tmp/leaf.pem -pubkey -noout \
     | openssl pkey -pubin -outform der \
     | openssl dgst -sha256 -binary | openssl base64
   ```
2. **Add the new pin** to `CertPins.byHost` for all three hosts. **Keep the
   previous pin** for one rotation cycle — it is the rollback safety net and
   prevents breaking already-shipped builds. Remove the oldest entry only
   after the new one is confirmed stable in production.
3. **Ship an app update** (`x.y.z+N`) **before** the server cert actually
   rotates. Store/Play review lead time must be budgeted in.
4. The test `cert_pins_test.dart › "keeps the previous leaf pin as backup"`
   fails if someone removes the backup pin prematurely — treat a red test as
   a release blocker.

### If pinning breaks production (incident)

Two escape hatches, in order of preference:

1. **Server-side rollback** to the previously-pinned leaf key (if still
   available). Already-shipped builds resume working immediately.
2. **Hotfix app update** with the new pin added (not replacing). This still
   requires Store/Play review time.

There is intentionally **no remote kill-switch** for pinning. A remote switch
would itself be the MITM vector pinning defends against. The only in-app
override is `--dart-define=CERT_PINNING=false`, which only takes effect in a
freshly compiled build.

### Platform note

`HttpClient.badCertificateCallback` exposes only the **leaf** certificate, so
only the leaf SPKI is actively verified. The intermediate CA pin
(`intermediateYe2Pin`) is documented for reference but is **not** checked by
the client. Full chain pinning would require a native TLS plugin or a raw
`SecureSocket` transport — tracked as a future hardening task.

---

## Release signing

Release builds require `android/key.properties` with the real release
keystore credentials. If the file is absent, the build now **fails fast**
instead of silently signing with the public debug key (which would let an
attacker forge/replace the app on a device).

### Local development with `flutter run --release`

Pass the opt-in flag:

```sh
flutter run --release -- -Pandroid.allowDebugSigning=true
# or, for a build:
flutter build apk --release -- -Pandroid.allowDebugSigning=true
```

**Production / CI builds must NEVER set this flag.** The warning
`⚠️ Release build using DEBUG signing key` is logged when it is used; treat
sighting of it in CI output as a release blocker.

---

## Security-hardening checklist (applied)

- [x] All `launchUrl` sites with server-supplied URLs are validated via
      `sparkNormalizeExternalUrl` (http/https + host required).
- [x] Token storage uses `flutter_secure_storage` (Keychain / Keystore).
- [x] Logout wipes on-disk inspection media (`spark_joy_media/`,
      `spark_joy_thumbs/`) in addition to prefs/secure-storage keys.
- [x] Certificate public-key pinning on RPC + WebSocket transports
      (release builds).
- [x] HTTPS / WSS only — no cleartext, no ATS exceptions.
- [x] Backup disabled (`allowBackup=false`, `fullBackupContent=false`).
- [x] Release build signed with real key (fail-fast without `key.properties`).
- [x] No hardcoded secrets in app code; Postman collection with live tokens
      removed from the working tree.
