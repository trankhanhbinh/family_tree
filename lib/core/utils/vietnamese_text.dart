/// Chuẩn hóa chuỗi tiếng Việt để so khớp: chữ thường, bỏ dấu, đ -> d.
String normalizeVietnamese(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_map[ch] ?? ch);
  }
  // Xóa dấu tổ hợp (trường hợp chuỗi ở dạng NFD).
  return buffer.toString().replaceAll(RegExp(r'[\u0300-\u036f]'), '');
}

const Map<String, String> _groups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<String, String> _map = _buildMap();

Map<String, String> _buildMap() {
  final map = <String, String>{};
  _groups.forEach((base, chars) {
    for (final rune in chars.runes) {
      map[String.fromCharCode(rune)] = base;
    }
  });
  return map;
}