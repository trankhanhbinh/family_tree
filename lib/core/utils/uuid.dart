import 'dart:math';

final Random _secureRandom = Random.secure();

/// Sinh UUID v4 (id cho người mới; app tự sinh để request sau tham chiếu được).
/// Tham số random chỉ để test cho kết quả cố định.
String generateUuidV4({Random? random}) {
  final rng = random ?? _secureRandom;
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // phiên bản 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // biến thể RFC 4122
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}