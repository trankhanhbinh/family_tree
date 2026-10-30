import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/person/domain/memorial_from_death.dart';

const int _now = 2026;

MemorialFromDeath _compute(String d, String m, String y) {
  return computeMemorialFromDeath(
    deathDay: d,
    deathMonth: m,
    deathYear: y,
    nowYear: _now,
  );
}

void main() {
  group('computeMemorialFromDeath', () {
    test('mất 18/08/2024 -> giỗ 15 tháng 7', () {
      final r = _compute('18', '8', '2024');
      expect(r.ok, isTrue);
      expect(r.day, 15);
      expect(r.month, 7);
      expect(r.isLeap, isFalse);
    });

    test('mất 23/03/2023 (tháng 2 nhuận) -> giỗ 2 tháng 2, cờ nhuận bật', () {
      final r = _compute('23', '3', '2023');
      expect(r.ok, isTrue);
      expect(r.day, 2);
      expect(r.month, 2);
      expect(r.isLeap, isTrue);
    });

    test('mất 09/02/2024 -> giỗ 30 tháng 12', () {
      final r = _compute('9', '2', '2024');
      expect(r.ok, isTrue);
      expect(r.day, 30);
      expect(r.month, 12);
      expect(r.isLeap, isFalse);
    });

    test('mất 10/02/2024 (Tết) -> giỗ 1 tháng 1', () {
      final r = _compute('10', '2', '2024');
      expect(r.ok, isTrue);
      expect(r.day, 1);
      expect(r.month, 1);
    });

    test('bỏ khoảng trắng thừa trong ô nhập', () {
      final r = _compute(' 18 ', ' 8 ', ' 2024 ');
      expect(r.ok, isTrue);
      expect(r.day, 15);
      expect(r.month, 7);
    });

    test('ô ngày mất trống -> báo chưa nhập', () {
      final r = _compute('', '', '');
      expect(r.ok, isFalse);
      expect(r.error, contains('chưa nhập ngày mất'));
    });

    test('chỉ có năm mất -> báo chưa đủ', () {
      final r = _compute('', '', '2024');
      expect(r.ok, isFalse);
      expect(r.error, contains('Mới có năm mất'));
    });

    test('thiếu ngày hoặc tháng -> báo ngày mất chưa hợp lệ', () {
      final r = _compute('', '8', '2024');
      expect(r.ok, isFalse);
      expect(r.error, startsWith('Ngày mất chưa hợp lệ'));
    });

    test('ngày không có thật (31/02) -> báo lỗi', () {
      final r = _compute('31', '2', '2024');
      expect(r.ok, isFalse);
      expect(r.error, contains('không có thật'));
    });

    test('năm 1500 nằm ngoài phạm vi 1800-2199', () {
      final r = _compute('18', '8', '1500');
      expect(r.ok, isFalse);
      expect(r.error, contains('1800'));
    });

    test('năm mất lớn hơn năm hiện tại -> báo lỗi', () {
      final r = _compute('18', '8', '2027');
      expect(r.ok, isFalse);
      expect(r.error, contains('chưa hợp lệ'));
    });
  });

  test('hasMemorialInput: chỉ cần ngày hoặc tháng khác trống', () {
    expect(hasMemorialInput('', ''), isFalse);
    expect(hasMemorialInput(' ', ' '), isFalse);
    expect(hasMemorialInput('', '7'), isTrue);
    expect(hasMemorialInput('15', ''), isTrue);
  });

  test('isSameMemorial: khớp cả ngày, tháng và cờ nhuận', () {
    final computed = _compute('18', '8', '2024');
    expect(
      isSameMemorial(
        currentDay: '15',
        currentMonth: '7',
        currentIsLeap: false,
        computed: computed,
      ),
      isTrue,
    );
    expect(
      isSameMemorial(
        currentDay: '15',
        currentMonth: '7',
        currentIsLeap: true,
        computed: computed,
      ),
      isFalse,
    );
    expect(
      isSameMemorial(
        currentDay: '16',
        currentMonth: '7',
        currentIsLeap: false,
        computed: computed,
      ),
      isFalse,
    );
    expect(
      isSameMemorial(
        currentDay: 'abc',
        currentMonth: '7',
        currentIsLeap: false,
        computed: computed,
      ),
      isFalse,
    );
    expect(
      isSameMemorial(
        currentDay: '15',
        currentMonth: '7',
        currentIsLeap: false,
        computed: _compute('', '', ''),
      ),
      isFalse,
    );
  });
}