import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/person/domain/memorial_date.dart';

DateTime? _next(int day, int month, DateTime today) {
  return nextMemorialDate(lunarDay: day, lunarMonth: month, today: today);
}

void main() {
  group('daysBetween', () {
    test('qua ngày 29/02 năm nhuận dương lịch', () {
      expect(daysBetween(DateTime(2024, 2, 28), DateTime(2024, 3, 1)), 2);
    });

    test('bỏ qua giờ, âm nếu đảo thứ tự', () {
      expect(
        daysBetween(DateTime(2024, 8, 18, 23, 59), DateTime(2024, 8, 19, 0, 1)),
        1,
      );
      expect(daysBetween(DateTime(2024, 8, 19), DateTime(2024, 8, 18)), -1);
    });
  });

  group('memorialSolarDateInLunarYear', () {
    test('15/7 năm 2024 = 18/08/2024', () {
      expect(
        memorialSolarDateInLunarYear(
          lunarDay: 15,
          lunarMonth: 7,
          lunarYear: 2024,
        ),
        DateTime(2024, 8, 18),
      );
    });

    test('ngày 30 mà tháng chỉ có 29 ngày thì giỗ ngày 29', () {
      expect(
        memorialSolarDateInLunarYear(
          lunarDay: 30,
          lunarMonth: 1,
          lunarYear: 2023,
        ),
        DateTime(2023, 2, 19),
      );
    });

    test('ngày 30 mà tháng có 30 ngày thì giữ ngày 30', () {
      expect(
        memorialSolarDateInLunarYear(
          lunarDay: 30,
          lunarMonth: 2,
          lunarYear: 2023,
        ),
        DateTime(2023, 3, 21),
      );
    });

    test('năm có tháng nhuận vẫn dùng tháng thường (2/2/2023 = 21/02/2023)',
        () {
      expect(
        memorialSolarDateInLunarYear(
          lunarDay: 2,
          lunarMonth: 2,
          lunarYear: 2023,
        ),
        DateTime(2023, 2, 21),
      );
    });

    test('dữ liệu không hợp lệ trả null', () {
      expect(
        memorialSolarDateInLunarYear(
          lunarDay: 0,
          lunarMonth: 7,
          lunarYear: 2024,
        ),
        isNull,
      );
      expect(
        memorialSolarDateInLunarYear(
          lunarDay: 31,
          lunarMonth: 7,
          lunarYear: 2024,
        ),
        isNull,
      );
      expect(
        memorialSolarDateInLunarYear(
          lunarDay: 15,
          lunarMonth: 13,
          lunarYear: 2024,
        ),
        isNull,
      );
    });
  });

  group('nextMemorialDate', () {
    test('giỗ 15/7 tính từ 01/01/2024 -> 18/08/2024', () {
      expect(_next(15, 7, DateTime(2024, 1, 1)), DateTime(2024, 8, 18));
    });

    test('đúng ngày giỗ thì trả về chính hôm nay', () {
      expect(_next(15, 7, DateTime(2024, 8, 18)), DateTime(2024, 8, 18));
    });

    test('đúng ngày giỗ nhưng có giờ trong ngày vẫn trả hôm nay', () {
      expect(
        _next(15, 7, DateTime(2024, 8, 18, 23, 30)),
        DateTime(2024, 8, 18),
      );
    });

    test('ngày giỗ vừa qua thì sang năm sau (19/08/2024 -> 06/09/2025)', () {
      expect(_next(15, 7, DateTime(2024, 8, 19)), DateTime(2025, 9, 6));
    });

    test('giỗ 30/1 từ 01/01/2023: tháng 1 chỉ 29 ngày -> 19/02/2023', () {
      expect(_next(30, 1, DateTime(2023, 1, 1)), DateTime(2023, 2, 19));
    });

    test('giỗ 30/1 từ 20/02/2023 -> 09/03/2024 (năm sau, tháng 1 chỉ 29 ngày)',
        () {
      expect(_next(30, 1, DateTime(2023, 2, 20)), DateTime(2024, 3, 9));
    });

    test('giỗ 30/12 từ 15/01/2025: tháng Chạp 2024 chỉ 29 ngày -> 28/01/2025',
        () {
      expect(_next(30, 12, DateTime(2025, 1, 15)), DateTime(2025, 1, 28));
    });

    test('hôm nay còn thuộc năm âm trước (05/01/2024): giỗ 20/12 -> 30/01/2024',
        () {
      expect(_next(20, 12, DateTime(2024, 1, 5)), DateTime(2024, 1, 30));
    });

    test('hôm nay còn thuộc năm âm trước (05/01/2024): giỗ 15/1 -> 24/02/2024',
        () {
      expect(_next(15, 1, DateTime(2024, 1, 5)), DateTime(2024, 2, 24));
    });

    test('giỗ 15/12 từ 25/02/2024 -> 14/01/2025 (sang năm dương sau)', () {
      expect(_next(15, 12, DateTime(2024, 2, 25)), DateTime(2025, 1, 14));
    });

    test('dữ liệu không hợp lệ hoặc ngoài phạm vi thư viện trả null', () {
      expect(_next(0, 7, DateTime(2024, 1, 1)), isNull);
      expect(_next(15, 13, DateTime(2024, 1, 1)), isNull);
      expect(_next(15, 7, DateTime(2200, 1, 1)), isNull);
    });
  });
}