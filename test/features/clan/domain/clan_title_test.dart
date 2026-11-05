import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/clan/domain/clan_title.dart';

void main() {
  group('clanTitleOf', () {
    test('tên chỉ có họ', () {
      expect(clanTitleOf('Nguyễn'), 'Gia phả họ Nguyễn');
    });

    test('bỏ chữ "Họ" ở đầu, không phân biệt hoa thường', () {
      expect(clanTitleOf('Họ Nguyễn'), 'Gia phả họ Nguyễn');
      expect(clanTitleOf('HỌ Nguyễn'), 'Gia phả họ Nguyễn');
    });

    test('bỏ khoảng trắng thừa', () {
      expect(clanTitleOf('  Nguyễn  '), 'Gia phả họ Nguyễn');
    });

    test('giữ nguyên tên nhiều chữ', () {
      expect(clanTitleOf('Nguyễn Đăng'), 'Gia phả họ Nguyễn Đăng');
    });

    test('rỗng hoặc null thì dùng nhãn chung', () {
      expect(clanTitleOf(null), 'Gia phả dòng họ');
      expect(clanTitleOf('   '), 'Gia phả dòng họ');
    });
  });
}
