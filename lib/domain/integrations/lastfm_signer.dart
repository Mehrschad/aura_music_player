import 'dart:typed_data';
import 'dart:convert';

/// Pure-Dart MD5-based Last.fm API signature helper.
class LastFmSigner {
  /// Builds the api_sig from sorted params + appended secret (RFC 1321 MD5).
  static String sign(Map<String, String> params, String secret) {
    final keys = params.keys.toList()..sort();
    final sb = StringBuffer();
    for (final k in keys) {
      sb.write(k);
      sb.write(params[k]);
    }
    sb.write(secret);
    return _md5(sb.toString());
  }

  static String _md5(String input) {
    final bytes = utf8.encode(input);
    return _md5Bytes(Uint8List.fromList(bytes));
  }

  // ignore: long-method
  static String _md5Bytes(Uint8List data) {
    // RFC 1321 shift amounts per round.
    const s = [
      7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
      5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20,
      4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
      6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
    ];
    // Pre-computed table of 2^32 * |sin(i+1)| constants.
    const k = [
      0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
      0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
      0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
      0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
      0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
      0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
      0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
      0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
      0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
      0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
      0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
      0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
      0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
      0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
      0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
      0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
    ];

    // Pre-processing: append 0x80 then zero-pad to 56 mod 64 bytes.
    final origLen = data.length;
    final bitLen = origLen * 8;
    final padLen = (origLen % 64 < 56)
        ? 56 - origLen % 64
        : 120 - origLen % 64;
    final msg = Uint8List(origLen + padLen + 8);
    msg.setRange(0, origLen, data);
    msg[origLen] = 0x80;
    // Append bit-length as 64-bit little-endian.
    for (var i = 0; i < 8; i++) {
      msg[origLen + padLen + i] = (bitLen >> (8 * i)) & 0xff;
    }

    var a0 = 0x67452301;
    var b0 = 0xefcdab89;
    var c0 = 0x98badcfe;
    var d0 = 0x10325476;

    for (var chunk = 0; chunk < msg.length; chunk += 64) {
      // Load 16 little-endian 32-bit words.
      final w = List<int>.generate(16, (i) {
        final o = chunk + i * 4;
        return msg[o] | (msg[o + 1] << 8) | (msg[o + 2] << 16) | (msg[o + 3] << 24);
      });

      var a = a0, b = b0, c = c0, d = d0;
      for (var i = 0; i < 64; i++) {
        int f, g;
        if (i < 16) {
          f = (b & c) | (~b & d);
          g = i;
        } else if (i < 32) {
          f = (d & b) | (~d & c);
          g = (5 * i + 1) % 16;
        } else if (i < 48) {
          f = b ^ c ^ d;
          g = (3 * i + 5) % 16;
        } else {
          f = c ^ (b | ~d);
          g = (7 * i) % 16;
        }
        f = _u32(f + a + k[i] + w[g]);
        a = d;
        d = c;
        c = b;
        b = _u32(b + _rotl32(f, s[i]));
      }
      a0 = _u32(a0 + a);
      b0 = _u32(b0 + b);
      c0 = _u32(c0 + c);
      d0 = _u32(d0 + d);
    }

    // Emit result as 32 hex chars in little-endian word order.
    return [a0, b0, c0, d0]
        .map((v) => _u32le(v).map((b) => b.toRadixString(16).padLeft(2, '0')).join())
        .join();
  }

  static int _u32(int x) => x & 0xFFFFFFFF;
  static int _rotl32(int x, int n) => _u32((x << n) | (x >> (32 - n)));
  static List<int> _u32le(int v) =>
      [v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff];
}
