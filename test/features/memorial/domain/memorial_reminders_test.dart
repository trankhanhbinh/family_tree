import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/memorial/domain/memorial_reminders.dart';
import 'package:familytree/features/person/domain/memorial_labels.dart';
import 'package:familytree/features/person/domain/person.dart';

/// Giả định "bây giờ" (giờ Việt Nam) = 01/08/2024 10:00 (27 tháng 6 âm lịch).
/// Mốc đã biết: 28/6 = 02/08, 15/7 = 18/08, 28/8 = 30/09, 29/8 = 01/10 (2024).
final DateTime _now = DateTime(2024, 8, 1, 10, 0);

Person _p(
  String id,
  String name, {
  bool alive = false,
  int? day,
  int? month,
}) {
  return Person(
    id: id,
    fullName: name,
    gender: Gender.male,
    isAlive: alive,
    memorialLunarDay: day,
    memorialLunarMonth: month,
    memorialIsLeap: false,
    deletedAt: null,
  );
}

List<MemorialReminder> _plan(List<Person> people, {DateTime? now}) {
  return planMemorialReminders(people: people, nowVietnam: now ?? _now);
}

void main() {
  group('giờ nhắc', () {
    test('buổi tối muộn nhưng không quá 21:00', () {
      final minutes = kMemorialReminderHour * 60 + kMemorialReminderMinute;
      expect(minutes, greaterThanOrEqualTo(19 * 60));
      expect(minutes, lessThanOrEqualTo(21 * 60));
    });

    test('nhắc trước 3 ngày', () {
      expect(kMemorialReminderLeadDays, 3);
    });
  });

  group('planMemorialReminders', () {
    test('nhắc lúc 20:30, trước 3 ngày so với ngày giỗ', () {
      final r = _plan([_p('a', 'Một', day: 15, month: 7)]);
      expect(r.length, 1);
      expect(r.first.fireAtVietnam, DateTime(2024, 8, 15, 20, 30));
    });

    test('quy ra giờ UTC đúng (trừ 7 tiếng)', () {
      final r = _plan([_p('a', 'Một', day: 15, month: 7)]);
      expect(r.first.fireAtUtc, DateTime.utc(2024, 8, 15, 13, 30));
    });

    test('nhiều người cùng ngày giỗ chỉ có một lần nhắc', () {
      final r = _plan([
        _p('a', 'Một', day: 15, month: 7),
        _p('b', 'Hai', day: 15, month: 7),
      ]);
      expect(r.length, 1);
    });

    test('giỗ quá gần (đã qua giờ nhắc) thì bỏ', () {
      final r = _plan([
        _p('a', 'Hôm nay', day: 27, month: 6),
        _p('b', 'Ngày mai', day: 28, month: 6),
      ]);
      expect(r, isEmpty);
    });

    test('ranh giới: còn đủ thời gian trước 20:30 thì nhắc', () {
      final r = _plan(
        [_p('a', 'Một', day: 15, month: 7)],
        now: DateTime(2024, 8, 15, 20, 0),
      );
      expect(r.length, 1);
    });

    test('ranh giới: sát hoặc quá 20:30 thì bỏ', () {
      final people = [_p('a', 'Một', day: 15, month: 7)];
      expect(_plan(people, now: DateTime(2024, 8, 15, 20, 29)), isEmpty);
      expect(_plan(people, now: DateTime(2024, 8, 15, 20, 30)), isEmpty);
      expect(_plan(people, now: DateTime(2024, 8, 15, 21, 0)), isEmpty);
    });

    test('giỗ ở ngày thứ 60 và 61 đều được nhắc (cửa sổ dài thêm 3 ngày)', () {
      final r = _plan([
        _p('d', 'Sáu mươi', day: 28, month: 8),
        _p('e', 'Sáu mốt', day: 29, month: 8),
      ]);
      expect(r.map((e) => e.fireAtVietnam).toList(), [
        DateTime(2024, 9, 27, 20, 30),
        DateTime(2024, 9, 28, 20, 30),
      ]);
    });

    test('bỏ người còn sống và người thiếu ngày giỗ', () {
      final r = _plan([
        _p('s', 'Còn sống', alive: true, day: 15, month: 7),
        _p('t', 'Thiếu tháng', day: 15),
      ]);
      expect(r, isEmpty);
    });

    test('nội dung không chứa tên, có ngày âm và ngày dương', () {
      final r = _plan([_p('a', 'Trần Văn Thử', day: 15, month: 7)]);
      final reminder = r.first;
      final lunar = formatMemorialLunar(day: 15, month: 7, isLeap: false);
      expect(reminder.title, kMemorialReminderTitle);
      expect(reminder.title.contains('Trần Văn Thử'), isFalse);
      expect(reminder.body.contains('Trần Văn Thử'), isFalse);
      expect(reminder.body.contains(lunar), isTrue);
      expect(reminder.body.contains('18/08/2024'), isTrue);
    });

    test('bấm vào nhắc mở màn Ngày giỗ', () {
      final r = _plan([_p('a', 'Một', day: 15, month: 7)]);
      expect(r.first.payload, '/memorials');
    });

    test('không vượt quá số lịch tối đa và xếp theo thời điểm tăng dần', () {
      final people = <Person>[];
      for (var month = 1; month <= 12; month++) {
        for (var day = 1; day <= 29; day++) {
          people.add(_p('p$month-$day', 'Người $month-$day',
              day: day, month: month));
        }
      }
      final r = _plan(people);
      expect(r.length, lessThanOrEqualTo(kMaxMemorialReminders));
      for (var i = 1; i < r.length; i++) {
        expect(r[i].fireAtVietnam.isAfter(r[i - 1].fireAtVietnam), isTrue);
      }
    });
  });

  group('mã nhắc', () {
    test('mỗi ngày giỗ một mã khác nhau, nằm trong dải nhắc giỗ', () {
      final a = memorialReminderIdFor(DateTime(2024, 8, 18));
      final b = memorialReminderIdFor(DateTime(2024, 8, 19));
      expect(a, isNot(b));
      expect(isMemorialReminderId(a), isTrue);
      expect(isMemorialReminderId(b), isTrue);
    });

    test('mã ngoài dải (vd. mã thông báo đề xuất) không bị coi là nhắc giỗ', () {
      expect(isMemorialReminderId(1793600000), isFalse);
      expect(isMemorialReminderId(kMemorialReminderIdBase - 1), isFalse);
      expect(isMemorialReminderId(kMemorialReminderIdLimit), isFalse);
    });
  });

  group('vietnamWallClock', () {
    test('17:30 UTC là 00:30 ngày hôm sau ở Việt Nam', () {
      expect(
        vietnamWallClock(DateTime.utc(2024, 8, 1, 17, 30)),
        DateTime(2024, 8, 2, 0, 30),
      );
    });

    test('13:00 UTC là 20:00 cùng ngày ở Việt Nam', () {
      expect(
        vietnamWallClock(DateTime.utc(2024, 8, 1, 13, 0)),
        DateTime(2024, 8, 1, 20, 0),
      );
    });
  });
}