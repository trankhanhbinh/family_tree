import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/memorial/domain/upcoming_memorials.dart';
import 'package:familytree/features/person/domain/person.dart';

/// Hôm nay giả định = 01/08/2024 (27 tháng 6 âm lịch).
final DateTime _today = DateTime(2024, 8, 1);

Person _p(
  String id,
  String name, {
  bool alive = false,
  int? day,
  int? month,
  bool deleted = false,
}) {
  return Person(
    id: id,
    fullName: name,
    gender: Gender.male,
    isAlive: alive,
    memorialLunarDay: day,
    memorialLunarMonth: month,
    memorialIsLeap: false,
    deletedAt: deleted ? DateTime(2024, 7, 1) : null,
  );
}

UpcomingMemorials _build(
  List<Person> people, {
  DateTime? today,
  int withinDays = kMemorialLookaheadDays,
}) {
  return buildUpcomingMemorials(
    people: people,
    today: today ?? _today,
    withinDays: withinDays,
  );
}

void main() {
  test('liệt kê đúng và sắp xếp theo ngày giỗ gần nhất', () {
    final r = _build([
      _p('c', 'Ba', day: 15, month: 7),
      _p('a', 'Một', day: 27, month: 6),
      _p('b', 'Hai', day: 28, month: 6),
    ]);
    expect(r.items.map((e) => e.person.id).toList(), ['a', 'b', 'c']);
    expect(r.items.map((e) => e.daysLeft).toList(), [0, 1, 17]);
    expect(r.items.map((e) => e.date).toList(), [
      DateTime(2024, 8, 1),
      DateTime(2024, 8, 2),
      DateTime(2024, 8, 18),
    ]);
    expect(r.missingCount, 0);
  });

  test('đúng ngày thứ 60 được liệt kê, ngày thứ 61 thì không', () {
    final r = _build([
      _p('d', 'Sáu mươi', day: 28, month: 8),
      _p('e', 'Sáu mốt', day: 29, month: 8),
    ]);
    expect(r.items.map((e) => e.person.id).toList(), ['d']);
    expect(r.items.first.daysLeft, 60);
    expect(r.items.first.date, DateTime(2024, 9, 30));
  });

  test('giỗ vừa qua hôm qua thì không xuất hiện (phải đợi sang năm)', () {
    final r = _build([_p('x', 'Hôm qua', day: 26, month: 6)]);
    expect(r.items, isEmpty);
    expect(r.missingCount, 0);
  });

  test('hôm nay có giờ trong ngày vẫn tính là còn 0 ngày', () {
    final r = _build(
      [_p('a', 'Một', day: 27, month: 6)],
      today: DateTime(2024, 8, 1, 23, 59),
    );
    expect(r.items.length, 1);
    expect(r.items.first.daysLeft, 0);
  });

  test('bỏ người còn sống và người đã xóa mềm', () {
    final r = _build([
      _p('s', 'Còn sống', alive: true, day: 27, month: 6),
      _p('z', 'Đã xóa', day: 27, month: 6, deleted: true),
    ]);
    expect(r.items, isEmpty);
    expect(r.missingCount, 0);
  });

  test('người đã mất thiếu ngày hoặc tháng giỗ được đếm là thiếu', () {
    final r = _build([
      _p('1', 'Chỉ ngày', day: 15),
      _p('2', 'Chỉ tháng', month: 7),
      _p('3', 'Không có'),
      _p('4', 'Đủ', day: 15, month: 7),
    ]);
    expect(r.missingCount, 3);
    expect(r.items.map((e) => e.person.id).toList(), ['4']);
  });

  test('cùng ngày giỗ thì xếp theo họ tên rồi theo id', () {
    final r = _build([
      _p('p3', 'Trần Văn B', day: 28, month: 6),
      _p('p2', 'Lê Văn A', day: 28, month: 6),
      _p('p1', 'Lê Văn A', day: 28, month: 6),
    ]);
    expect(r.items.map((e) => e.person.id).toList(), ['p1', 'p2', 'p3']);
  });

  test('dữ liệu giỗ không hợp lệ bị bỏ qua, không tính là thiếu', () {
    final r = _build([
      _p('a', 'Ngày 31', day: 31, month: 7),
      _p('b', 'Ngày 0', day: 0, month: 7),
      _p('c', 'Tháng 13', day: 15, month: 13),
    ]);
    expect(r.items, isEmpty);
    expect(r.missingCount, 0);
  });

  test('danh sách rỗng', () {
    final r = _build([]);
    expect(r.items, isEmpty);
    expect(r.missingCount, 0);
  });

  test('withinDays tùy chỉnh: chỉ lấy giỗ trong 10 ngày tới', () {
    final r = _build(
      [
        _p('a', 'Một', day: 27, month: 6),
        _p('b', 'Hai', day: 28, month: 6),
        _p('c', 'Ba', day: 15, month: 7),
      ],
      withinDays: 10,
    );
    expect(r.items.map((e) => e.person.id).toList(), ['a', 'b']);
  });
}