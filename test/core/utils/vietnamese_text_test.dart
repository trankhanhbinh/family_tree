import 'package:familytree/core/utils/vietnamese_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bỏ dấu và hạ chữ thường', () {
    expect(normalizeVietnamese('Nguyễn Thị Hằng'), 'nguyen thi hang');
    expect(normalizeVietnamese('Nhất'), 'nhat');
  });

  test('đ và Đ thành d', () {
    expect(normalizeVietnamese('Đặng Thị Thu'), 'dang thi thu');
    expect(normalizeVietnamese('ĐẶNG'), 'dang');
  });

  test('chuỗi Unicode dạng tách dấu (NFD) cũng được xử lý', () {
    expect(normalizeVietnamese('To\u0302\u0309'), 'to');
  });
}