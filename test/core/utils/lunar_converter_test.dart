import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/core/utils/lunar_converter.dart';

LunarDate _lunar(int d, int m, int y, {bool leap = false}) {
  return LunarDate(day: d, month: m, year: y, isLeap: leap);
}

void main() {
  group('solarToLunar', () {
    test('Tết 2024: 10/02/2024 = mùng 1 tháng 1', () {
      expect(solarToLunar(DateTime(2024, 2, 10)), _lunar(1, 1, 2024));
    });

    test('2023 có tháng 2 nhuận: 23/03/2023 = mùng 2 tháng 2 nhuận', () {
      expect(
        solarToLunar(DateTime(2023, 3, 23)),
        _lunar(2, 2, 2023, leap: true),
      );
    });

    test('09/02/2024 = 30 tháng Chạp 2023 (thuộc năm âm 2023)', () {
      expect(solarToLunar(DateTime(2024, 2, 9)), _lunar(30, 12, 2023));
    });

    test('18/08/2024 = 15 tháng 7', () {
      expect(solarToLunar(DateTime(2024, 8, 18)), _lunar(15, 7, 2024));
    });

    test('bỏ qua giờ trong ngày', () {
      expect(
        solarToLunar(DateTime(2024, 2, 10, 23, 59)),
        _lunar(1, 1, 2024),
      );
    });

    test('ngoài phạm vi 1800-2199 trả null', () {
      expect(solarToLunar(DateTime(1799, 12, 31)), isNull);
      expect(solarToLunar(DateTime(2200, 1, 1)), isNull);
    });
  });

  group('lunarToSolar', () {
    test('mùng 1 Tết các năm 2023, 2024, 2025', () {
      expect(lunarToSolar(_lunar(1, 1, 2023)), DateTime(2023, 1, 22));
      expect(lunarToSolar(_lunar(1, 1, 2024)), DateTime(2024, 2, 10));
      expect(lunarToSolar(_lunar(1, 1, 2025)), DateTime(2025, 1, 29));
    });

    test('2/2/2023: tháng nhuận khác tháng thường', () {
      expect(
        lunarToSolar(_lunar(2, 2, 2023, leap: true)),
        DateTime(2023, 3, 23),
      );
      expect(lunarToSolar(_lunar(2, 2, 2023)), DateTime(2023, 2, 21));
    });

    test('tháng nhuận không tồn tại trả null', () {
      expect(lunarToSolar(_lunar(2, 2, 2024, leap: true)), isNull);
      expect(lunarToSolar(_lunar(2, 3, 2023, leap: true)), isNull);
    });

    test('ngày 30 của tháng chỉ có 29 ngày trả null, tháng có 30 ngày thì được',
        () {
      expect(lunarToSolar(_lunar(30, 1, 2023)), isNull);
      expect(lunarToSolar(_lunar(30, 2, 2023)), DateTime(2023, 3, 21));
    });

    test('dữ liệu không hợp lệ trả null', () {
      expect(lunarToSolar(_lunar(0, 5, 2024)), isNull);
      expect(lunarToSolar(_lunar(31, 5, 2024)), isNull);
      expect(lunarToSolar(_lunar(10, 13, 2024)), isNull);
      expect(lunarToSolar(_lunar(10, 0, 2024)), isNull);
      expect(lunarToSolar(_lunar(10, 5, 1799)), isNull);
      expect(lunarToSolar(_lunar(10, 5, 2200)), isNull);
    });
  });

  test('quy đổi xuôi rồi ngược khớp nhau trong 1500 ngày liên tiếp', () {
    for (var i = 0; i < 1500; i++) {
      final date = DateTime(2022, 1, 1 + i);
      final lunar = solarToLunar(date);
      expect(lunar, isNotNull, reason: 'ngày $date');
      expect(lunarToSolar(lunar!), date, reason: 'ngày $date -> $lunar');
    }
  });
}