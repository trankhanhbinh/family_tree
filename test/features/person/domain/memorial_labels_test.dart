import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/person/domain/memorial_labels.dart';

void main() {
  group('formatMemorialLunar', () {
    test('tháng thường', () {
      expect(
        formatMemorialLunar(day: 15, month: 7, isLeap: false),
        '15 tháng 7 (âm lịch)',
      );
    });

    test('tháng nhuận', () {
      expect(
        formatMemorialLunar(day: 2, month: 2, isLeap: true),
        '2 tháng 2 nhuận (âm lịch)',
      );
    });
  });

  group('formatDaysLeft', () {
    test('hôm nay và ngày mai', () {
      expect(formatDaysLeft(0), 'hôm nay');
      expect(formatDaysLeft(1), 'ngày mai');
    });

    test('còn nhiều ngày', () {
      expect(formatDaysLeft(2), 'còn 2 ngày');
      expect(formatDaysLeft(12), 'còn 12 ngày');
    });

    test('số âm (không nên xảy ra) -> đã qua', () {
      expect(formatDaysLeft(-1), 'đã qua');
    });
  });

  test('formatNextMemorial ghép ngày dd/MM/yyyy với số ngày còn lại', () {
    expect(
      formatNextMemorial(DateTime(2024, 8, 18), 12),
      '18/08/2024 (còn 12 ngày)',
    );
    expect(
      formatNextMemorial(DateTime(2024, 8, 18), 0),
      '18/08/2024 (hôm nay)',
    );
  });

  group('describeMemorialInput', () {
    test('đủ và hợp lệ', () {
      expect(
        describeMemorialInput(day: '15', month: '7', isLeap: false),
        '15 tháng 7 (âm lịch)',
      );
      expect(
        describeMemorialInput(day: '2', month: '2', isLeap: true),
        '2 tháng 2 nhuận (âm lịch)',
      );
    });

    test('thiếu ngày hoặc tháng', () {
      expect(
        describeMemorialInput(day: '15', month: '', isLeap: false),
        'ngày 15, tháng ?',
      );
      expect(
        describeMemorialInput(day: '', month: '7', isLeap: false),
        'ngày ?, tháng 7',
      );
    });

    test('số ngoài phạm vi', () {
      expect(
        describeMemorialInput(day: '45', month: '7', isLeap: false),
        'ngày 45, tháng 7',
      );
    });
  });
}