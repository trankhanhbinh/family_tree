/// Một file ảnh thừa trong Storage (không còn dòng ảnh hay đề xuất nào dùng).
class OrphanFile {
  const OrphanFile({
    required this.name,
    required this.size,
    required this.createdAt,
  });

  factory OrphanFile.fromJson(Map<String, dynamic> json) {
    return OrphanFile(
      name: json['file_name'] as String,
      size: (json['file_size'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['file_created_at'] as String),
    );
  }

  final String name;

  /// Dung lượng (byte).
  final int size;
  final DateTime createdAt;
}

int orphanBytes(List<OrphanFile> files) {
  return files.fold<int>(0, (sum, file) => sum + file.size);
}

/// Kết quả quét hai bucket.
class OrphanScan {
  const OrphanScan({required this.publicFiles, required this.pendingFiles});

  final List<OrphanFile> publicFiles;
  final List<OrphanFile> pendingFiles;

  int get totalCount => publicFiles.length + pendingFiles.length;

  int get totalBytes => orphanBytes(publicFiles) + orphanBytes(pendingFiles);

  bool get isEmpty => totalCount == 0;
}

/// Kết quả một lần dọn.
class CleanupResult {
  const CleanupResult({required this.deleted, required this.failed});

  final int deleted;
  final int failed;
}

String _oneDecimal(double value) {
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

/// Dung lượng dạng chữ: 900 B, 1,5 KB, 5,5 MB, 1,0 GB.
String formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${_oneDecimal(kb)} KB';
  }
  final mb = kb / 1024;
  if (mb < 1024) {
    return '${_oneDecimal(mb)} MB';
  }
  return '${_oneDecimal(mb / 1024)} GB';
}

/// Chia danh sách thành các lô tối đa [size] phần tử.
List<List<T>> chunkList<T>(List<T> items, int size) {
  if (size <= 0) {
    throw ArgumentError.value(size, 'size', 'phải lớn hơn 0');
  }
  final chunks = <List<T>>[];
  for (var start = 0; start < items.length; start += size) {
    final end = start + size < items.length ? start + size : items.length;
    chunks.add(items.sublist(start, end));
  }
  return chunks;
}

/// Dòng tóm tắt một nhóm file thừa.
String describeOrphanGroup(List<OrphanFile> files) {
  if (files.isEmpty) {
    return 'Không có file thừa';
  }
  return '${files.length} file thừa (${formatFileSize(orphanBytes(files))})';
}

/// Nội dung hộp thoại báo kết quả sau khi dọn.
String describeCleanupResult(CleanupResult result) {
  if (result.deleted == 0 && result.failed == 0) {
    return 'Không có file nào để xóa.';
  }
  if (result.failed == 0) {
    return 'Đã xóa ${result.deleted} file thừa.';
  }
  if (result.deleted == 0) {
    return 'Không xóa được file nào (${result.failed} file). '
        'Vui lòng kiểm tra mạng rồi thử lại.';
  }
  return 'Đã xóa ${result.deleted} file. '
      'Còn ${result.failed} file chưa xóa được, bạn có thể quét lại '
      'và thử thêm lần nữa.';
}