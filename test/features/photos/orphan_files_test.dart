import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/photos/domain/orphan_files.dart';

OrphanFile _file(String name, int size) {
  return OrphanFile(name: name, size: size, createdAt: DateTime(2026, 10, 28));
}

void main() {
  test('OrphanFile.fromJson: đọc đủ trường, thiếu dung lượng thì là 0', () {
    final file = OrphanFile.fromJson({
      'file_name': 'test-orphan/aaaa.jpg',
      'file_size': 12345,
      'file_created_at': '2026-10-28T06:48:25.087756+00:00',
    });
    expect(file.name, 'test-orphan/aaaa.jpg');
    expect(file.size, 12345);
    expect(file.createdAt, DateTime.parse('2026-10-28T06:48:25.087756+00:00'));

    final noSize = OrphanFile.fromJson({
      'file_name': 'x/y.jpg',
      'file_size': null,
      'file_created_at': '2026-10-28T06:48:25+00:00',
    });
    expect(noSize.size, 0);
  });

  test('OrphanScan: tổng số file, tổng dung lượng, rỗng', () {
    final scan = OrphanScan(
      publicFiles: [_file('a/1.jpg', 1000), _file('a/2.jpg', 2000)],
      pendingFiles: [_file('u/3.jpg', 500)],
    );
    expect(scan.totalCount, 3);
    expect(scan.totalBytes, 3500);
    expect(scan.isEmpty, isFalse);

    const empty = OrphanScan(publicFiles: [], pendingFiles: []);
    expect(empty.isEmpty, isTrue);
    expect(empty.totalBytes, 0);
  });

  test('formatFileSize: B, KB, MB, GB với dấu phẩy thập phân', () {
    expect(formatFileSize(0), '0 B');
    expect(formatFileSize(1023), '1023 B');
    expect(formatFileSize(1024), '1,0 KB');
    expect(formatFileSize(1536), '1,5 KB');
    expect(formatFileSize(1048576), '1,0 MB');
    expect(formatFileSize(5767168), '5,5 MB');
    expect(formatFileSize(1073741824), '1,0 GB');
  });

  test('chunkList: 120 phần tử chia thành lô 50, 50, 20', () {
    final chunks = chunkList(List<int>.generate(120, (i) => i), 50);
    expect(chunks.map((c) => c.length).toList(), [50, 50, 20]);
    expect(chunks.first.first, 0);
    expect(chunks.last.last, 119);
  });

  test('chunkList: danh sách rỗng cho ra không lô nào', () {
    expect(chunkList(<int>[], 50), isEmpty);
  });

  test('chunkList: cỡ lô không hợp lệ thì báo lỗi', () {
    expect(() => chunkList([1], 0), throwsArgumentError);
  });

  test('describeOrphanGroup: rỗng và có file', () {
    expect(describeOrphanGroup(const []), 'Không có file thừa');
    expect(
      describeOrphanGroup([_file('a/1.jpg', 1024), _file('a/2.jpg', 512)]),
      '2 file thừa (1,5 KB)',
    );
  });

  test('describeCleanupResult: bốn trường hợp', () {
    expect(
      describeCleanupResult(const CleanupResult(deleted: 0, failed: 0)),
      'Không có file nào để xóa.',
    );
    expect(
      describeCleanupResult(const CleanupResult(deleted: 3, failed: 0)),
      'Đã xóa 3 file thừa.',
    );
    expect(
      describeCleanupResult(const CleanupResult(deleted: 0, failed: 2)),
      'Không xóa được file nào (2 file). Vui lòng kiểm tra mạng rồi thử lại.',
    );
    expect(
      describeCleanupResult(const CleanupResult(deleted: 3, failed: 2)),
      'Đã xóa 3 file. Còn 2 file chưa xóa được, bạn có thể quét lại '
      'và thử thêm lần nữa.',
    );
  });
}