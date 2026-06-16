/// Extracts the DER-encoded SubjectPublicKeyInfo (SPKI) from a DER-encoded
/// X.509 certificate.
///
/// Used by certificate public-key pinning: the SPKI is hashed (SHA-256) and
/// compared against pinned hashes. We pin the *public key*, not the
/// certificate, so normal server-side leaf rotation (renewing the cert with
/// the same key) does not break the app.
///
/// This is a minimal DER TLV walker — not a full ASN.1 parser. It reaches the
/// SPKI field by skipping the fixed-prefix fields of TBSCertificate. The
/// structure is:
///
/// ```
/// Certificate ::= SEQUENCE {
///   tbsCertificate       SEQUENCE {
///     version         [0] EXPLICIT INTEGER OPTIONAL,   -- skip
///     serialNumber        INTEGER,                      -- skip
///     signature           AlgorithmIdentifier,          -- skip
///     issuer              Name,                         -- skip
///     validity            SEQUENCE { notBefore, notAfter }, -- skip
///     subject             Name,                         -- skip
///     subjectPki          SubjectPublicKeyInfo,         -- <-- extract
///     ...
///   },
///   signatureAlgorithm   AlgorithmIdentifier,
///   signatureValue       BIT STRING
/// }
/// ```
///
/// Returns the full TLV bytes of the SPKI element (tag + length + value) on
/// success, or null if the DER does not match the expected layout (treated as
/// a pin mismatch by the caller — fail-closed).
List<int>? extractSubjectPublicKeyInfo(List<int> der) {
  try {
    final r = _DerReader(der);
    final certSeq = r.readSequence(); // Certificate
    final tbs = certSeq.readSequence(); // TBSCertificate
    tbs.skipOptionalExplicit(0xa0); // version [0]
    tbs.skip(); // serialNumber
    tbs.skip(); // signature AlgorithmIdentifier
    tbs.skip(); // issuer Name
    tbs.skip(); // validity
    tbs.skip(); // subject Name
    // Next element is SubjectPublicKeyInfo — return its full TLV bytes.
    return tbs.readElementBytes();
  } catch (_) {
    return null;
  }
}

/// Minimal DER reader for the few TLV hops the extractor needs.
/// Throws [_DerError] on malformed input; callers treat exceptions as a pin
/// mismatch (fail-closed).
class _DerReader {
  _DerReader(this.bytes);
  final List<int> bytes;
  int offset = 0;

  _DerReader readSequence() {
    final tag = _readByte();
    if (tag != 0x30) throw _DerError('expected SEQUENCE (0x30), got 0x${tag.toRadixString(16)}');
    final len = _readLength();
    final end = offset + len;
    if (end > bytes.length) throw _DerError('SEQ length overrun');
    final view = bytes.sublist(offset, end);
    offset = end;
    return _DerReader(view);
  }

  /// If the next byte is [expectedTag], skip the whole element; otherwise
  /// leave the cursor untouched.
  void skipOptionalExplicit(int expectedTag) {
    if (offset < bytes.length && bytes[offset] == expectedTag) {
      skip();
    }
  }

  void skip() {
    final _ = readElementBytes();
  }

  /// Reads one full TLV element and returns its raw bytes
  /// (tag + length + value), advancing past it.
  List<int> readElementBytes() {
    final start = offset;
    _readByte(); // tag
    final len = _readLength();
    offset += len;
    if (offset > bytes.length) throw _DerError('TLV length overrun');
    return bytes.sublist(start, offset);
  }

  int _readByte() {
    if (offset >= bytes.length) throw _DerError('unexpected EOF');
    return bytes[offset++];
  }

  int _readLength() {
    final first = _readByte();
    if (first < 0x80) return first;
    final numBytes = first & 0x7f;
    if (numBytes == 0 || numBytes > 4) throw _DerError('bad/unsupported length');
    var len = 0;
    for (var i = 0; i < numBytes; i++) {
      len = (len << 8) | _readByte();
    }
    return len;
  }
}

class _DerError implements Exception {
  _DerError(this.message);
  final String message;
  @override
  String toString() => '_DerError: $message';
}
