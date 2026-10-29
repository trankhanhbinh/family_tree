import 'dart:convert';

const String kBackupFormat = 'familytree-backup';
const int kBackupVersion = 1;

/// Số dòng tải mỗi trang (Supabase chỉ trả tối đa 1000 dòng mỗi truy vấn).
const int kBackupPageSize = 1000;

/// Số lượng dòng của từng loại trong file sao lưu.
class BackupCounts {
  const BackupCounts({
    required this.people,
    required this.branches,
    required this.parentChild,
    required this.marriages,
    required this.photos,
  });

  final int people;
  final int branches;
  final int parentChild;
  final int marriages;
  final int photos;
}

/// Dữ liệu thô (nguyên các dòng của bảng) để đưa vào file sao lưu.
class BackupData {
  const BackupData({
    required this.clanInfo,
    required this.branches,
    required this.people,
    required this.parentChild,
    required this.marriages,
    required this.personPhotos,
  });

  final Map<String, dynamic>? clanInfo;
  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> people;
  final List<Map<String, dynamic>> parentChild;
  final List<Map<String, dynamic>> marriages;
  final List<Map<String, dynamic>> personPhotos;

  BackupCounts get counts {
    return BackupCounts(
      people: people.length,
      branches: branches.length,
      parentChild: parentChild.length,
      marriages: marriages.length,
      photos: personPhotos.length,
    );
  }

  /// Bỏ người đã xóa mềm (deleted_at có giá trị) và mọi quan hệ, hôn nhân, ảnh
  /// nhắc tới người đã bị bỏ, để file giống nhau với mọi người xuất và
  /// không có dòng nào trỏ tới người không còn trong file.
  BackupData withoutDeleted() {
    final live = people.where((row) => row['deleted_at'] == null).toList();
    final ids = {for (final row in live) row['id']};
    bool has(Object? id) => ids.contains(id);

    return BackupData(
      clanInfo: clanInfo,
      branches: branches,
      people: live,
      parentChild: parentChild
          .where((row) => has(row['parent_id']) && has(row['child_id']))
          .toList(),
      marriages: marriages
          .where((row) => has(row['person1_id']) && has(row['person2_id']))
          .toList(),
      personPhotos:
          personPhotos.where((row) => has(row['person_id'])).toList(),
    );
  }
}

/// Dựng nội dung file sao lưu. Chỉ có dữ liệu, KHÔNG có đường dẫn URL nào
/// (ảnh chỉ có storage_path).
Map<String, dynamic> buildBackupMap(BackupData data, DateTime exportedAt) {
  final counts = data.counts;
  return {
    'format': kBackupFormat,
    'version': kBackupVersion,
    'exported_at': exportedAt.toUtc().toIso8601String(),
    'counts': {
      'branches': counts.branches,
      'people': counts.people,
      'parent_child': counts.parentChild,
      'marriages': counts.marriages,
      'person_photos': counts.photos,
    },
    'data': {
      'clan_info': data.clanInfo,
      'branches': data.branches,
      'people': data.people,
      'parent_child': data.parentChild,
      'marriages': data.marriages,
      'person_photos': data.personPhotos,
    },
  };
}

/// JSON thụt lề 2 ký tự cho dễ đọc.
String encodeBackup(Map<String, dynamic> backup) {
  return const JsonEncoder.withIndent('  ').convert(backup);
}

String _two(int value) => value.toString().padLeft(2, '0');

/// giapha-sao-luu-YYYYMMDD-HHmm.json (giờ của máy).
String backupFileName(DateTime when) {
  final local = when.toLocal();
  return 'giapha-sao-luu-${local.year}${_two(local.month)}${_two(local.day)}'
      '-${_two(local.hour)}${_two(local.minute)}.json';
}

/// Dòng tóm tắt hiện trên màn hình sau khi xuất.
String describeBackupCounts(BackupCounts counts) {
  return 'Đã xuất ${counts.people} người, ${counts.branches} chi/nhánh, '
      '${counts.parentChild} quan hệ cha mẹ - con, '
      '${counts.marriages} hôn nhân, ${counts.photos} ảnh.';
}