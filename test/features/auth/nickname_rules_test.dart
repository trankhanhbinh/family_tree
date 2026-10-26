import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/auth/domain/nickname_rules.dart';

void main() {
  test('normalize: bỏ khoảng trắng đầu/cuối và gộp khoảng trắng giữa', () {
    expect(normalizeNickname('  Nguyễn   Văn  Bình '), 'Nguyễn Văn Bình');
  });

  test('validate: rỗng', () {
    expect(validateNickname(''), isNotNull);
  });

  test('validate: chỉ có khoảng trắng', () {
    expect(validateNickname('     '), isNotNull);
  });

  test('validate: quá ngắn (1 ký tự)', () {
    expect(validateNickname('A'), isNotNull);
  });

  test('validate: quá dài (31 ký tự)', () {
    expect(validateNickname('a' * 31), isNotNull);
  });

  test('validate: hợp lệ', () {
    expect(validateNickname('Bình'), isNull);
    expect(validateNickname('Nguyễn Văn Bình'), isNull);
  });
}