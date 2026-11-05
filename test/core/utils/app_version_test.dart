import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/core/utils/app_version.dart';

void main() {
  group('formatAppVersion', () {
    test('ghép số phiên bản và số bản dựng', () {
      expect(
        formatAppVersion(version: '1.0.0', buildNumber: '1'),
        'Phiên bản 1.0.0 (1)',
      );
    });

    test('thiếu số bản dựng thì chỉ hiện số phiên bản', () {
      expect(
        formatAppVersion(version: '1.2.3', buildNumber: ''),
        'Phiên bản 1.2.3',
      );
    });

    test('thiếu số phiên bản thì báo không rõ', () {
      expect(
        formatAppVersion(version: '', buildNumber: '5'),
        'Phiên bản không rõ',
      );
    });

    test('bỏ khoảng trắng thừa', () {
      expect(
        formatAppVersion(version: ' 1.0.0 ', buildNumber: ' 2 '),
        'Phiên bản 1.0.0 (2)',
      );
    });
  });
}
