import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/backup/domain/backup_builder.dart';

BackupData _data({Map<String, dynamic>? clanInfo}) {
  return BackupData(
    clanInfo: clanInfo ?? {'id': 1, 'name': 'Họ Nguyễn'},
    branches: [
      {'id': 'b1', 'name': 'Chi Nhất'},
    ],
    people: [
      {'id': 'p1', 'full_name': 'A', 'deleted_at': null},
      {'id': 'p2', 'full_name': 'B', 'deleted_at': '2026-10-27T20:43:39+00:00'},
      {'id': 'p3', 'full_name': 'C', 'deleted_at': null},
    ],
    parentChild: [
      {'id': 'pc1', 'parent_id': 'p1', 'child_id': 'p3'},
      {'id': 'pc2', 'parent_id': 'p1', 'child_id': 'p2'},
      {'id': 'pc3', 'parent_id': 'p2', 'child_id': 'p3'},
    ],
    marriages: [
      {'id': 'm1', 'person1_id': 'p1', 'person2_id': 'p3'},
      {'id': 'm2', 'person1_id': 'p1', 'person2_id': 'p2'},
    ],
    personPhotos: [
      {'id': 'ph1', 'person_id': 'p1', 'storage_path': 'p1/ph1.jpg'},
      {'id': 'ph2', 'person_id': 'p2', 'storage_path': 'p2/ph2.jpg'},
    ],
  );
}

void main() {
  test('counts: đếm đúng số dòng từng loại', () {
    final counts = _data().counts;
    expect(counts.people, 3);
    expect(counts.branches, 1);
    expect(counts.parentChild, 3);
    expect(counts.marriages, 2);
    expect(counts.photos, 2);
  });

  test('withoutDeleted: bỏ người đã xóa mềm và các dòng nhắc tới họ', () {
    final data = _data().withoutDeleted();
    expect(data.people.map((r) => r['id']).toList(), ['p1', 'p3']);
    expect(data.parentChild.map((r) => r['id']).toList(), ['pc1']);
    expect(data.marriages.map((r) => r['id']).toList(), ['m1']);
    expect(data.personPhotos.map((r) => r['id']).toList(), ['ph1']);
    expect(data.branches, hasLength(1));
    expect(data.clanInfo, isNotNull);
  });

  test('withoutDeleted: không ai bị xóa thì giữ nguyên tất cả', () {
    final all = BackupData(
      clanInfo: null,
      branches: const [],
      people: [
        {'id': 'p1', 'deleted_at': null},
        {'id': 'p2', 'deleted_at': null},
      ],
      parentChild: [
        {'id': 'pc1', 'parent_id': 'p1', 'child_id': 'p2'},
      ],
      marriages: const [],
      personPhotos: const [],
    );
    final kept = all.withoutDeleted();
    expect(kept.people, hasLength(2));
    expect(kept.parentChild, hasLength(1));
  });

  test('buildBackupMap: cấu trúc, giờ UTC, số lượng', () {
    final map = buildBackupMap(
      _data().withoutDeleted(),
      DateTime.utc(2026, 10, 28, 6, 48),
    );
    expect(map.keys.toList(), [
      'format',
      'version',
      'exported_at',
      'counts',
      'data',
    ]);
    expect(map['format'], 'familytree-backup');
    expect(map['version'], 1);
    expect(map['exported_at'], '2026-10-28T06:48:00.000Z');
    expect(map['counts'], {
      'branches': 1,
      'people': 2,
      'parent_child': 1,
      'marriages': 1,
      'person_photos': 1,
    });
    final data = map['data'] as Map<String, dynamic>;
    expect(data.keys.toList(), [
      'clan_info',
      'branches',
      'people',
      'parent_child',
      'marriages',
      'person_photos',
    ]);
  });

  test('buildBackupMap: thiếu clan_info thì ghi null', () {
    final data = BackupData(
      clanInfo: null,
      branches: const [],
      people: const [],
      parentChild: const [],
      marriages: const [],
      personPhotos: const [],
    );
    final map = buildBackupMap(data, DateTime.utc(2026));
    expect((map['data'] as Map<String, dynamic>)['clan_info'], isNull);
  });

  test('encodeBackup: thụt lề 2 ký tự và đọc lại được y nguyên', () {
    final map = buildBackupMap(_data().withoutDeleted(), DateTime.utc(2026));
    final json = encodeBackup(map);
    expect(json.startsWith('{\n  "format": "familytree-backup"'), isTrue);
    expect(jsonDecode(json), map);
  });

  test('file sao lưu chỉ có storage_path, không thêm đường dẫn URL nào', () {
    final json = encodeBackup(
      buildBackupMap(_data().withoutDeleted(), DateTime.utc(2026)),
    );
    expect(json.contains('"storage_path": "p1/ph1.jpg"'), isTrue);
    expect(json.contains('http'), isFalse);
    expect(json.contains('supabase'), isFalse);
  });

  test('backupFileName: giapha-sao-luu-YYYYMMDD-HHmm.json', () {
    expect(
      backupFileName(DateTime(2026, 10, 28, 9, 5)),
      'giapha-sao-luu-20261028-0905.json',
    );
  });

  test('describeBackupCounts: dòng tóm tắt', () {
    expect(
      describeBackupCounts(
        const BackupCounts(
          people: 16,
          branches: 4,
          parentChild: 14,
          marriages: 3,
          photos: 0,
        ),
      ),
      'Đã xuất 16 người, 4 chi/nhánh, 14 quan hệ cha mẹ - con, '
      '3 hôn nhân, 0 ảnh.',
    );
  });
}