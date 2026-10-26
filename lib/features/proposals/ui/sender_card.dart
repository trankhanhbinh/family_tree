import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/form_widgets.dart';
import 'package:familytree/features/auth/data/nickname_store.dart';
import 'package:familytree/features/auth/ui/contributor_gate.dart';
import 'package:familytree/features/person/domain/person_edit_form.dart';

/// Card "Thông tin người gửi": tên đang dùng, nút đổi tên, ô ghi chú cho admin.
class SenderCard extends ConsumerWidget {
  const SenderCard({super.key, required this.noteController});

  final TextEditingController noteController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nickname = ref.watch(nicknameProvider).value;
    final hasName = nickname != null && nickname.isNotEmpty;
    return FormCard(
      title: 'Thông tin người gửi',
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                hasName
                    ? 'Gửi với tên: $nickname'
                    : 'Bạn sẽ được hỏi tên khi gửi.',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(100, 56),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () => editNickname(context, ref),
              child: const Text('Đổi tên'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppTextField(
          controller: noteController,
          label: 'Lý do / ghi chú cho quản trị viên (không bắt buộc)',
          maxLength: kRequestNoteMaxLength,
          minLines: 2,
          maxLines: 4,
        ),
      ],
    );
  }
}