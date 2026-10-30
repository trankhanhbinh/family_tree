import 'package:flutter/material.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/core/ui/form_widgets.dart';
import 'package:familytree/features/person/domain/branch_path.dart';
import 'package:familytree/features/person/domain/memorial_from_death.dart';
import 'package:familytree/features/person/domain/memorial_labels.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_edit_form.dart';
import 'package:familytree/features/person/ui/person_form_controller.dart';
import 'package:familytree/features/tree/domain/branch.dart';

/// Kết quả chọn chi/nhánh (id = null nghĩa là "Không thuộc chi nào").
class BranchChoice {
  const BranchChoice(this.id);

  final String? id;
}

/// Danh sách chi/nhánh dạng bảng trượt từ dưới lên, mục to cao 56.
/// Trả về null nếu đóng mà không chọn.
Future<BranchChoice?> showBranchPicker(
  BuildContext context, {
  required List<Branch> branches,
  required String? currentId,
}) {
  final entries = <({String id, String path})>[
    for (final b in branches)
      (id: b.id, path: branchPathOf(b.id, branches) ?? b.name),
  ]..sort((a, b) => a.path.compareTo(b.path));

  return showModalBottomSheet<BranchChoice>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Chọn chi/nhánh',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              minTileHeight: 56,
              title: const Text(
                'Không thuộc chi nào',
                style: TextStyle(fontSize: 18),
              ),
              selected: currentId == null,
              trailing:
                  currentId == null ? const Icon(Icons.check, size: 28) : null,
              onTap: () =>
                  Navigator.of(sheetContext).pop(const BranchChoice(null)),
            ),
            for (final entry in entries)
              ListTile(
                minTileHeight: 56,
                title: Text(entry.path, style: const TextStyle(fontSize: 18)),
                selected: currentId == entry.id,
                trailing: currentId == entry.id
                    ? const Icon(Icons.check, size: 28)
                    : null,
                onTap: () =>
                    Navigator.of(sheetContext).pop(BranchChoice(entry.id)),
              ),
          ],
        ),
      );
    },
  );
}

/// Các card nhập thông tin một người: cơ bản, ngày sinh, tình trạng,
/// ngày giỗ (khi đã mất), ghi chú. Dùng chung cho Sửa và Thêm.
class PersonFormFields extends StatelessWidget {
  const PersonFormFields({
    super.key,
    required this.controller,
    required this.branches,
    this.showGeneration = false,
  });

  final PersonFormController controller;
  final List<Branch> branches;

  /// Ô "Số đời": chỉ quản trị viên thấy.
  final bool showGeneration;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _basicCard(context),
            _birthCard(),
            _statusCard(),
            if (!controller.isAlive) _memorialCard(),
            _notesCard(),
          ],
        );
      },
    );
  }

  Future<void> _pickBranch(BuildContext context) async {
    final picked = await showBranchPicker(
      context,
      branches: branches,
      currentId: controller.branchId,
    );
    if (picked != null) {
      controller.setBranch(picked.id);
    }
  }

  Widget _basicCard(BuildContext context) {
    final errors = controller.errors;
    final genderError = errors[PersonField.gender];
    final generationError = errors[PersonField.generation];
    final branchId = controller.branchId;
    final branchLabel = branchId == null
        ? 'Không thuộc chi nào'
        : (branchPathOf(branchId, branches) ?? 'Không rõ');

    return FormCard(
      title: 'Thông tin cơ bản',
      children: [
        KeyedSubtree(
          key: controller.keys[PersonField.fullName],
          child: AppTextField(
            controller: controller.fullName,
            label: 'Họ và tên *',
            errorText: errors[PersonField.fullName],
            maxLength: kPersonNameMaxLength,
            capitalization: TextCapitalization.words,
            onChanged: () => controller.clearError(PersonField.fullName),
          ),
        ),
        AppTextField(
          controller: controller.otherName,
          label: 'Tên khác (tên thường gọi, tên húy...)',
          capitalization: TextCapitalization.words,
        ),
        KeyedSubtree(
          key: controller.keys[PersonField.gender],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel(
                controller.requireGenderChoice ? 'Giới tính *' : 'Giới tính',
              ),
              BigSegmented<Gender>(
                options: const [
                  (Gender.male, 'Nam'),
                  (Gender.female, 'Nữ'),
                  (Gender.other, 'Khác'),
                ],
                selected: controller.gender,
                onChanged: controller.setGender,
              ),
              if (genderError != null) ErrorText(genderError),
              const SizedBox(height: 16),
            ],
          ),
        ),
        const FieldLabel('Chi/nhánh'),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
            onPressed: () => _pickBranch(context),
            child: Row(
              children: [
                Expanded(
                  child: Text(branchLabel, overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.arrow_drop_down, size: 32),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (showGeneration)
          KeyedSubtree(
            key: controller.keys[PersonField.generation],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppNumberField(
                  controller: controller.generation,
                  label: 'Số đời (chỉ quản trị viên thấy)',
                  maxDigits: 2,
                  hasError: generationError != null,
                  onChanged: () =>
                      controller.clearError(PersonField.generation),
                ),
                if (generationError != null) ErrorText(generationError),
                const SizedBox(height: 16),
              ],
            ),
          ),
        AppTextField(
          controller: controller.birthPlace,
          label: 'Nơi sinh',
          capitalization: TextCapitalization.words,
        ),
      ],
    );
  }

  Widget _birthCard() {
    return FormCard(
      title: 'Ngày sinh',
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Chỉ nhớ năm thì chỉ cần nhập năm, để trống ngày và tháng.',
            style: TextStyle(fontSize: 15),
          ),
        ),
        KeyedSubtree(
          key: controller.keys[PersonField.birth],
          child: DateFieldsRow(
            day: controller.birthDay,
            month: controller.birthMonth,
            year: controller.birthYear,
            error: controller.errors[PersonField.birth],
            onChanged: () => controller.clearError(PersonField.birth),
          ),
        ),
      ],
    );
  }

  Widget _statusCard() {
    return FormCard(
      title: 'Tình trạng',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Đã mất',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            controller.isAlive
                ? 'Hiện đang còn sống'
                : 'Nhập thêm thông tin bên dưới',
            style: const TextStyle(fontSize: 16),
          ),
          value: !controller.isAlive,
          onChanged: (isDead) => controller.setAlive(!isDead),
        ),
        if (!controller.isAlive) ...[
          const SizedBox(height: 8),
          const FieldLabel('Ngày mất'),
          KeyedSubtree(
            key: controller.keys[PersonField.death],
            child: DateFieldsRow(
              day: controller.deathDay,
              month: controller.deathMonth,
              year: controller.deathYear,
              error: controller.errors[PersonField.death],
              onChanged: () => controller.clearError(PersonField.death),
            ),
          ),
          AppTextField(
            controller: controller.burialPlace,
            label: 'Nơi an táng',
            capitalization: TextCapitalization.words,
          ),
        ],
      ],
    );
  }

  Future<void> _calculateMemorial(BuildContext context) async {
    final computed = computeMemorialFromDeath(
      deathDay: controller.deathDay.text,
      deathMonth: controller.deathMonth.text,
      deathYear: controller.deathYear.text,
      nowYear: DateTime.now().year,
    );
    final day = computed.day;
    final month = computed.month;
    if (!computed.ok || day == null || month == null) {
      await showMessageDialog(
        context,
        title: 'Chưa tính được ngày giỗ',
        message: computed.error ?? 'Không tính được ngày giỗ từ ngày mất.',
        icon: Icons.error_outline,
        isError: true,
      );
      return;
    }

    final newText = formatMemorialLunar(
      day: day,
      month: month,
      isLeap: computed.isLeap,
    );

    if (hasMemorialInput(
      controller.memorialDay.text,
      controller.memorialMonth.text,
    )) {
      final same = isSameMemorial(
        currentDay: controller.memorialDay.text,
        currentMonth: controller.memorialMonth.text,
        currentIsLeap: controller.memorialIsLeap,
        computed: computed,
      );
      if (same) {
        await showMessageDialog(
          context,
          title: 'Ngày giỗ đã đúng',
          message: 'Ngày giỗ đang nhập ($newText) đã khớp với ngày mất.',
        );
        return;
      }
      final oldText = describeMemorialInput(
        day: controller.memorialDay.text,
        month: controller.memorialMonth.text,
        isLeap: controller.memorialIsLeap,
      );
      if (!context.mounted) {
        return;
      }
      final keep = await showChoiceDialog(
        context,
        title: 'Thay ngày giỗ?',
        message: 'Ngày giỗ đang nhập: $oldText\n'
            'Ngày giỗ tính từ ngày mất: $newText\n\n'
            'Bạn muốn giữ ngày giỗ nào?',
        primaryLabel: 'Giữ nguyên',
        secondaryLabel: 'Dùng ngày tính được',
      );
      if (keep || !context.mounted) {
        return;
      }
    }

    controller.applyMemorial(
      day: day,
      month: month,
      isLeap: computed.isLeap,
    );
  }

  Widget _memorialCard() {
    final error = controller.errors[PersonField.memorial];
    return FormCard(
      title: 'Ngày giỗ (âm lịch)',
      children: [
        Builder(
          builder: (context) {
            return SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () => _calculateMemorial(context),
                icon: const Icon(Icons.calculate_outlined, size: 28),
                label: const Text(
                  'Tính ngày giỗ từ ngày mất',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 16),
          child: Text(
            'Giỗ tính theo ngày âm lịch của ngày mất. '
            'Bạn vẫn có thể sửa tay các ô bên dưới.',
            style: TextStyle(fontSize: 15),
          ),
        ),
        KeyedSubtree(
          key: controller.keys[PersonField.memorial],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppNumberField(
                      controller: controller.memorialDay,
                      label: 'Ngày (1 đến 30)',
                      maxDigits: 2,
                      hasError: error != null,
                      onChanged: () =>
                          controller.clearError(PersonField.memorial),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppNumberField(
                      controller: controller.memorialMonth,
                      label: 'Tháng (1 đến 12)',
                      maxDigits: 2,
                      hasError: error != null,
                      onChanged: () =>
                          controller.clearError(PersonField.memorial),
                    ),
                  ),
                ],
              ),
              if (error != null) ErrorText(error),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Tháng nhuận', style: TextStyle(fontSize: 18)),
                value: controller.memorialIsLeap,
                onChanged: (value) =>
                    controller.setMemorialIsLeap(value ?? false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notesCard() {
    return FormCard(
      title: 'Ghi chú',
      children: [
        AppTextField(
          controller: controller.notes,
          label: 'Ghi chú về người này',
          maxLength: kPersonNotesMaxLength,
          minLines: 3,
          maxLines: 8,
        ),
      ],
    );
  }
}