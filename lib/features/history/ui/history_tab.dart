import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:familytree/features/history/ui/history_list.dart';

/// Nội dung thẻ "Lịch sử" trong màn duyệt: các nút công cụ quản trị ở trên,
/// danh sách lịch sử toàn dòng họ ở dưới.
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => context.push('/admin/deleted'),
                  child: const Text(
                    'Người đã xóa',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => context.push('/admin/photo-cleanup'),
                  child: const Text(
                    'Dọn file ảnh thừa',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Expanded(child: HistoryList()),
      ],
    );
  }
}