/// Cột kiểu date của Postgres trả về chuỗi "YYYY-MM-DD".
DateTime? parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.parse(value as String);
}