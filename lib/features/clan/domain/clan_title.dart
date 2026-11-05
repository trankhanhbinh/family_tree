/// Lấy họ từ tên dòng họ: bỏ chữ "Họ" ở đầu nếu có.
String clanSurnameOf(String clanName) {
  final trimmed = clanName.trim();
  if (trimmed.toLowerCase().startsWith('họ ')) {
    return trimmed.substring(3).trim();
  }
  return trimmed;
}

/// Dòng chữ nhãn đầu cây, ví dụ "Gia phả họ Nguyễn".
String clanTitleOf(String? clanName) {
  final surname = clanSurnameOf(clanName ?? '');
  if (surname.isEmpty) {
    return 'Gia phả dòng họ';
  }
  return 'Gia phả họ $surname';
}
