import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../domain/lyrics/lrc_parser.dart';
import '../../../domain/models/lyrics.dart';

/// Reads lyrics embedded inside the audio file itself — the fastest possible
/// source (local disk, zero network, no extra package). Pure Dart byte parsing
/// so it adds no native dependency and runs on a background isolate.
///
/// Supports the two formats that carry the overwhelming majority of embedded
/// lyrics in the wild:
///   • MP3 / ID3v2 `USLT` frame (unsynchronized lyrics) — and because countless
///     taggers store *LRC-formatted* text inside USLT, [parseLyrics] auto-detects
///     and yields fully synced lyrics when the embedded text has timestamps.
///   • FLAC / Vorbis comment `LYRICS` / `UNSYNCEDLYRICS` / `SYNCEDLYRICS`.
///
/// Only the metadata region is read (header-sized for ID3, the comment block
/// for FLAC) — never the whole file. Every failure path returns null so the
/// resolver simply falls through to the next source; it can never throw.
///
/// Top-level + isolate-safe so it can be handed to `runOffMainThread`.
Future<Lyrics?> readEmbeddedLyrics(String path) async {
  if (path.isEmpty) return null;
  RandomAccessFile? raf;
  try {
    final file = File(path);
    if (!await file.exists()) return null;
    raf = await file.open();
    final length = await raf.length();
    if (length < 16) return null;

    final magic = await _readAt(raf, 0, 4);
    String? text;
    if (magic[0] == 0x49 && magic[1] == 0x44 && magic[2] == 0x33) {
      text = await _id3Uslt(raf, length); // 'ID3'
    } else if (magic[0] == 0x66 &&
        magic[1] == 0x4C &&
        magic[2] == 0x61 &&
        magic[3] == 0x43) {
      text = await _flacLyrics(raf, length); // 'fLaC'
    }
    if (text == null || text.trim().isEmpty) return null;

    final lyrics = parseLyrics(text);
    return lyrics.isEmpty ? null : lyrics;
  } catch (_) {
    return null;
  } finally {
    await raf?.close();
  }
}

Future<Uint8List> _readAt(RandomAccessFile raf, int pos, int n) async {
  await raf.setPosition(pos);
  return raf.read(n);
}

int _syncsafe(Uint8List b, int o) =>
    ((b[o] & 0x7f) << 21) |
    ((b[o + 1] & 0x7f) << 14) |
    ((b[o + 2] & 0x7f) << 7) |
    (b[o + 3] & 0x7f);

// ── ID3v2 (MP3) ──────────────────────────────────────────────────────────────

Future<String?> _id3Uslt(RandomAccessFile raf, int fileLen) async {
  final header = await _readAt(raf, 0, 10);
  if (header.length < 10) return null;
  final major = header[3];
  final tagSize = _syncsafe(header, 6);
  final tagEnd = (10 + tagSize).clamp(10, fileLen);

  var pos = 10;
  // Skip an extended header if present (ID3v2.3/2.4 flag bit 6).
  if ((header[5] & 0x40) != 0 && pos + 4 <= tagEnd) {
    final ext = await _readAt(raf, pos, 4);
    final extSize = major >= 4
        ? _syncsafe(ext, 0)
        : (ext[0] << 24) | (ext[1] << 16) | (ext[2] << 8) | ext[3];
    pos += (major >= 4 ? extSize : extSize + 4);
  }

  while (pos + 10 <= tagEnd) {
    final fh = await _readAt(raf, pos, 10);
    if (fh.length < 10 || fh[0] == 0) break; // padding
    final id = String.fromCharCodes(fh.sublist(0, 4));
    final frameSize = major >= 4
        ? _syncsafe(fh, 4)
        : (fh[4] << 24) | (fh[5] << 16) | (fh[6] << 8) | fh[7];
    if (frameSize <= 0 || pos + 10 + frameSize > tagEnd) break;

    if (id == 'USLT') {
      final body = await _readAt(raf, pos + 10, frameSize);
      return _decodeUslt(body);
    }
    pos += 10 + frameSize;
  }
  return null;
}

/// USLT body: [encoding:1][language:3][descriptor: null-terminated][text].
String? _decodeUslt(Uint8List body) {
  if (body.length < 5) return null;
  final enc = body[0];
  var p = 4; // skip encoding + 3-byte language
  if (enc == 1 || enc == 2) {
    // UTF-16: terminator is a 0x00 0x00 pair on an even boundary.
    while (p + 1 < body.length && !(body[p] == 0 && body[p + 1] == 0)) {
      p += 2;
    }
    p += 2;
  } else {
    while (p < body.length && body[p] != 0) {
      p++;
    }
    p += 1;
  }
  if (p >= body.length) return null;
  return _decodeText(enc, body.sublist(p));
}

String _decodeText(int enc, Uint8List bytes) {
  switch (enc) {
    case 0:
      return latin1.decode(bytes, allowInvalid: true);
    case 1:
      return _utf16(bytes); // BOM-detected
    case 2:
      return _utf16(bytes, bigEndian: true);
    case 3:
    default:
      return utf8.decode(bytes, allowMalformed: true);
  }
}

String _utf16(Uint8List bytes, {bool bigEndian = false}) {
  var start = 0;
  var be = bigEndian;
  if (bytes.length >= 2) {
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      be = false;
      start = 2;
    } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      be = true;
      start = 2;
    }
  }
  final units = <int>[];
  for (var i = start; i + 1 < bytes.length; i += 2) {
    units.add(be ? (bytes[i] << 8) | bytes[i + 1] : bytes[i] | (bytes[i + 1] << 8));
  }
  return String.fromCharCodes(units);
}

// ── FLAC (Vorbis comment) ────────────────────────────────────────────────────

const Set<String> _vorbisLyricKeys = {
  'LYRICS',
  'UNSYNCEDLYRICS',
  'SYNCEDLYRICS',
  'LYRICS-XXX',
};

Future<String?> _flacLyrics(RandomAccessFile raf, int fileLen) async {
  var pos = 4; // after 'fLaC'
  while (pos + 4 <= fileLen) {
    final h = await _readAt(raf, pos, 4);
    if (h.length < 4) break;
    final last = (h[0] & 0x80) != 0;
    final type = h[0] & 0x7f;
    final blockLen = (h[1] << 16) | (h[2] << 8) | h[3];
    final dataPos = pos + 4;
    if (type == 4) {
      // VORBIS_COMMENT — read just this block.
      final take = blockLen.clamp(0, fileLen - dataPos).toInt();
      final data = await _readAt(raf, dataPos, take);
      return _vorbisLyrics(data);
    }
    if (last) break;
    pos = dataPos + blockLen;
  }
  return null;
}

String? _vorbisLyrics(Uint8List data) {
  var p = 0;
  int u32() {
    final v = data[p] |
        (data[p + 1] << 8) |
        (data[p + 2] << 16) |
        (data[p + 3] << 24);
    p += 4;
    return v;
  }

  if (data.length < 8) return null;
  final vendorLen = u32();
  p += vendorLen; // skip vendor string
  if (p + 4 > data.length) return null;
  final count = u32();
  for (var i = 0; i < count; i++) {
    if (p + 4 > data.length) break;
    final clen = u32();
    if (clen < 0 || p + clen > data.length) break;
    final comment = utf8.decode(data.sublist(p, p + clen), allowMalformed: true);
    p += clen;
    final eq = comment.indexOf('=');
    if (eq <= 0) continue;
    if (_vorbisLyricKeys.contains(comment.substring(0, eq).toUpperCase())) {
      final value = comment.substring(eq + 1);
      if (value.trim().isNotEmpty) return value;
    }
  }
  return null;
}
