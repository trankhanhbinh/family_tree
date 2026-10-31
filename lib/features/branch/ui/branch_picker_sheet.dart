import 'package:flutter/material.dart';

import 'package:familytree/features/branch/domain/branch_rows.dart';

/// Kết quả chọn: branchId = null nghĩa là "Chi gốc". Đóng bảng không chọn thì
/// hàm trả về null (khác với BranchPick(null)).
class BranchPick {
  const BranchPick(this.branchId);

  final String? branchId;
}

/// Bảng đáy cao chọn một chi. Dòng đang là vị trí hiện tại bị làm mờ, không chạm được.
Future<BranchPick?> showBranchPickerSheet(
  BuildContext context, {
  required String title,
  required List<BranchRow> rows,
  String? currentId,
  bool rootIsCurrent = false,
  bool allowRoot = false,
  String rootLabel = 'Chi gốc (không thuộc chi nào)',
}) {
  return showModalBottomSheet<BranchPick>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.8;
      final extraIndent = allowRoot ? 1 : 0;

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (allowRoot)
                        _PickTile(
                          label: rootLabel,
                          depth: 0,
                          isCurrent: rootIsCurrent,
                          onTap: () =>
                              Navigator.of(sheetContext).pop(const BranchPick(null)),
                        ),
                      if (rows.isEmpty && !allowRoot)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Không có chi nào để chọn.',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      for (final row in rows)
                        _PickTile(
                          label: row.branch.name,
                          depth: row.depth + extraIndent,
                          isCurrent: row.branch.id == currentId,
                          onTap: () => Navigator.of(sheetContext)
                              .pop(BranchPick(row.branch.id)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 56,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text(
                      'Đóng',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.label,
    required this.depth,
    required this.isCurrent,
    required this.onTap,
  });

  final String label;
  final int depth;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final indentLevel = depth > 6 ? 6 : depth;

    return Padding(
      padding: EdgeInsets.only(left: indentLevel * 20.0, bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isCurrent ? null : onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isCurrent ? scheme.outline : null,
                      ),
                    ),
                  ),
                  if (isCurrent)
                    Text(
                      '(hiện tại)',
                      style: TextStyle(fontSize: 16, color: scheme.outline),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}