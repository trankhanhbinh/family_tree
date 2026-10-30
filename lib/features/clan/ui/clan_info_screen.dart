import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/form_widgets.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/clan/data/clan_info_repository.dart';
import 'package:familytree/features/clan/domain/clan_info.dart';
import 'package:familytree/features/clan/domain/clan_info_form.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';
import 'package:familytree/features/proposals/ui/submit_changes.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';

/// /admin/clan: admin sửa tên, nguồn gốc, giới thiệu dòng họ (lưu ngay).
class ClanInfoScreen extends ConsumerWidget {
  const ClanInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin dòng họ')),
      body: SafeArea(
        child: !isAdmin
            ? const _AdminOnlyView()
            : ref.watch(clanInfoProvider).when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _LoadErrorView(
                    onRetry: () => ref.invalidate(clanInfoProvider),
                  ),
                  data: (info) => _ClanInfoForm(info: info),
                ),
      ),
    );
  }
}

class _AdminOnlyView extends StatelessWidget {
  const _AdminOnlyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Chỉ quản trị viên mới sửa được thông tin dòng họ.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, height: 1.4),
        ),
      ),
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Không tải được thông tin dòng họ.\n'
              'Hãy kiểm tra mạng rồi thử lại.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: onRetry,
                child: const Text('Thử lại', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClanInfoForm extends ConsumerStatefulWidget {
  const _ClanInfoForm({required this.info});

  final ClanInfo info;

  @override
  ConsumerState<_ClanInfoForm> createState() => _ClanInfoFormState();
}

class _ClanInfoFormState extends ConsumerState<_ClanInfoForm> {
  late final TextEditingController _name;
  late final TextEditingController _origin;
  late final TextEditingController _description;
  String? _nameError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.info.name);
    _origin = TextEditingController(text: widget.info.origin ?? '');
    _description = TextEditingController(text: widget.info.description ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _origin.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final nameError = validateClanName(_name.text);
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    final payload = buildClanInfoUpdatePayload(
      original: widget.info,
      name: _name.text,
      origin: _origin.text,
      description: _description.text,
    );
    if (payload.isEmpty) {
      await showMessageDialog(
        context,
        title: 'Chưa có thay đổi nào',
        message: 'Bạn chưa sửa gì nên không cần lưu.',
      );
      return;
    }

    // Lấy sẵn container: dùng được cả khi màn hình đã đóng.
    final container = ProviderScope.containerOf(context, listen: false);
    final summary = describeClanChanges(
      original: widget.info,
      payload: payload,
    ).join('\n');

    final proceed = await confirmSubmit(
      context,
      isAdmin: true,
      summary: summary,
      slots: 0,
    );
    if (!proceed || !mounted) {
      return;
    }

    setState(() => _saving = true);
    SubmitOutcome? outcome;
    Object? error;
    try {
      outcome = await submitChanges(
        context,
        ref,
        drafts: [
          RequestDraft(
            entityType: kEntityClanInfo,
            action: kActionUpdate,
            payload: payload,
          ),
        ],
      );
    } catch (e) {
      error = e;
    }

    void refreshProviders() {
      container.invalidate(clanNameProvider);
      container.invalidate(clanInfoProvider);
    }

    if (!mounted) {
      if (error == null) {
        refreshProviders();
      }
      return;
    }
    setState(() => _saving = false);

    if (error != null) {
      await showErrorDialog(context, error);
      return;
    }
    if (outcome != SubmitOutcome.saved) {
      return;
    }

    await showSubmitDone(context, outcome!);
    if (mounted) {
      context.pop();
    }
    // Làm mới SAU khi đóng màn, để form không bị dựng lại giữa chừng.
    refreshProviders();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormCard(
            title: 'Thông tin chung',
            children: [
              AppTextField(
                controller: _name,
                label: 'Tên dòng họ',
                maxLength: kClanNameMaxLength,
                errorText: _nameError,
                capitalization: TextCapitalization.words,
                onChanged: () {
                  if (_nameError != null) {
                    setState(() => _nameError = null);
                  }
                },
              ),
              AppTextField(
                controller: _origin,
                label: 'Nguồn gốc (không bắt buộc)',
                maxLength: kClanOriginMaxLength,
                minLines: 2,
                maxLines: 5,
              ),
              AppTextField(
                controller: _description,
                label: 'Giới thiệu (không bắt buộc)',
                maxLength: kClanDescriptionMaxLength,
                minLines: 3,
                maxLines: 8,
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving ? 'Đang lưu...' : 'Lưu thay đổi',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}