import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/clan/domain/clan_info.dart';
import 'package:familytree/features/clan/domain/clan_info_form.dart';

const ClanInfo _original = ClanInfo(
  name: 'Họ Nguyễn',
  origin: 'Thanh Hóa',
  description: 'Giới thiệu cũ',
);

Map<String, dynamic> _payload({
  ClanInfo original = _original,
  String name = 'Họ Nguyễn',
  String origin = 'Thanh Hóa',
  String description = 'Giới thiệu cũ',
}) {
  return buildClanInfoUpdatePayload(
    original: original,
    name: name,
    origin: origin,
    description: description,
  );
}

void main() {
  group('validateClanName', () {
    test('rỗng thì báo lỗi', () {
      expect(validateClanName(''), 'Hãy nhập tên dòng họ.');
    });

    test('chỉ có khoảng trắng thì báo lỗi', () {
      expect(validateClanName('    '), 'Hãy nhập tên dòng họ.');
    });

    test('tên hợp lệ (có khoảng trắng hai đầu) thì không lỗi', () {
      expect(validateClanName('  Họ Trần  '), isNull);
    });

    test('đúng 100 ký tự thì hợp lệ', () {
      expect(validateClanName('a' * 100), isNull);
    });

    test('101 ký tự thì báo lỗi', () {
      expect(validateClanName('a' * 101), 'Tên dòng họ tối đa 100 ký tự.');
    });
  });

  group('normalizeOptionalText', () {
    test('null thì trả null', () {
      expect(normalizeOptionalText(null), isNull);
    });

    test('toàn khoảng trắng thì trả null', () {
      expect(normalizeOptionalText('   '), isNull);
    });

    test('bỏ khoảng trắng hai đầu', () {
      expect(normalizeOptionalText('  abc  '), 'abc');
    });
  });

  group('buildClanInfoUpdatePayload', () {
    test('không đổi gì thì rỗng', () {
      expect(_payload(), isEmpty);
    });

    test('khác nhau chỉ ở khoảng trắng thì coi như không đổi', () {
      expect(
        _payload(
          name: '  Họ Nguyễn ',
          origin: ' Thanh Hóa',
          description: 'Giới thiệu cũ  ',
        ),
        isEmpty,
      );
    });

    test('chỉ đổi tên thì chỉ có khóa name (đã bỏ khoảng trắng)', () {
      final payload = _payload(name: '  Họ Lê ');
      expect(payload, {'name': 'Họ Lê'});
    });

    test('xóa trống nguồn gốc thì origin = null', () {
      final payload = _payload(origin: '   ');
      expect(payload.length, 1);
      expect(payload.containsKey('origin'), isTrue);
      expect(payload['origin'], isNull);
    });

    test('ban đầu null và ô vẫn trống thì không đổi', () {
      const original = ClanInfo(name: 'A');
      final payload = _payload(
        original: original,
        name: 'A',
        origin: '   ',
        description: '',
      );
      expect(payload, isEmpty);
    });

    test('đổi giới thiệu thì chỉ có khóa description (đã bỏ khoảng trắng)', () {
      final payload = _payload(description: ' Mới ');
      expect(payload, {'description': 'Mới'});
    });

    test('đổi cả ba thì có đủ ba khóa', () {
      final payload = _payload(
        name: 'Họ Phạm',
        origin: 'Nam Định',
        description: 'Mô tả mới',
      );
      expect(payload, {
        'name': 'Họ Phạm',
        'origin': 'Nam Định',
        'description': 'Mô tả mới',
      });
    });
  });

  group('describeClanChanges', () {
    test('đổi tên: một dòng "Tên dòng họ: cũ → mới"', () {
      final lines = describeClanChanges(
        original: _original,
        payload: {'name': 'Họ Lê'},
      );
      expect(lines, ['Tên dòng họ: Họ Nguyễn → Họ Lê']);
    });

    test('giá trị cũ trống hiện "(trống)", giá trị mới null cũng vậy', () {
      const original = ClanInfo(name: 'A');
      final added = describeClanChanges(
        original: original,
        payload: {'origin': 'Nam Định'},
      );
      expect(added, ['Nguồn gốc: (trống) → Nam Định']);

      final removed = describeClanChanges(
        original: _original,
        payload: {'origin': null},
      );
      expect(removed, ['Nguồn gốc: Thanh Hóa → (trống)']);
    });

    test('văn bản dài hơn 60 ký tự bị cắt và thêm dấu …', () {
      final original = ClanInfo(name: 'A', description: 'a' * 80);
      final lines = describeClanChanges(
        original: original,
        payload: {'description': 'ngắn'},
      );
      expect(lines, ['Giới thiệu: ${'a' * 60}… → ngắn']);
    });

    test('thứ tự dòng cố định: tên, nguồn gốc, giới thiệu', () {
      final lines = describeClanChanges(
        original: _original,
        payload: {
          'description': 'D',
          'origin': 'O',
          'name': 'N',
        },
      );
      expect(lines.length, 3);
      expect(lines[0], startsWith('Tên dòng họ:'));
      expect(lines[1], startsWith('Nguồn gốc:'));
      expect(lines[2], startsWith('Giới thiệu:'));
    });
  });

  group('ClanInfo.fromJson', () {
    test('đọc đủ ba cột', () {
      final info = ClanInfo.fromJson({
        'name': 'Họ Nguyễn',
        'origin': 'Thanh Hóa',
        'description': 'Mô tả',
      });
      expect(info.name, 'Họ Nguyễn');
      expect(info.origin, 'Thanh Hóa');
      expect(info.description, 'Mô tả');
    });

    test('origin và description null thì giữ null', () {
      final info = ClanInfo.fromJson({
        'name': 'Họ Nguyễn',
        'origin': null,
        'description': null,
      });
      expect(info.origin, isNull);
      expect(info.description, isNull);
    });
  });
}