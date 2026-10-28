import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/errors/app_error_messages.dart';
import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/core/ui/form_widgets.dart';
import 'package:familytree/core/utils/uuid.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/auth/ui/contributor_gate.dart';
import 'package:familytree/features/person/domain/person_photo.dart';
import 'package:familytree/features/photos/data/pending_photo_service.dart';
import 'package:familytree/features/photos/data/photo_service.dart';
import 'package:familytree/features/photos/domain/photo_plans.dart';
import 'package:familytree/features/photos/domain/photo_rules.dart';
import 'package:familytree/features/photos/ui/photo_picker.dart';
import 'package:familytree/features/proposals/ui/sender_card.dart';
import 'package:familytree/features/proposals/ui/submit_bar.dart';
import 'package:familytree/features/proposals/ui/submit_changes.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';

/// Thêm ảnh cho một người.
/// - Admin: tải file lên person-photos rồi tạo dòng ảnh (lưu ngay).
/// - Người đóng góp: tải file lên pending-photos rồi gửi đề xuất, chờ duyệt.
/// Luôn tải file lên TRƯỚC; bước sau lỗi thì xóa file vừa tải.
class AddPhotoScreen extends ConsumerStatefulWidget {
  const AddPhotoScreen({super.key, required this.personId});

  final String personId;

  @override
  ConsumerState<AddPhotoScreen> createState() => _AddPhotoScreenState();
}

class _AddPhotoScreenState extends ConsumerState<AddPhotoScreen> {
  final TextEditingController _caption = TextEditingController();
  final TextEditingController _note = TextEditingController();
  late final Listenable _all = Listenable.merge([_caption, _note]);

  // Id ảnh: sinh MỘT lần cho màn hình này (thử lại sau lỗi vẫn cùng id).
  late final String _photoId = generateUuidV4();

  ({Uint8List bytes, String extension})? _photo;
  String? _captionError;
  bool _submitting = false;

  @override
  void dispose() {
    _caption.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _photo != null ||
      _caption.text.trim().isNotEmpty ||
      _note.text.trim().isNotEmpty;

  Future<void> _pick() async {
    if (_submitting) {
      return;
    }
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) {
      return;
    }
    try {
      final picked = await pickPhoto(source);
      if (picked == null || !mounted) {
        return;
      }
      final extension = picked.extension;
      final problem = validatePhoto(
        sizeBytes: picked.bytes.length,
        extension: extension,
      );
      if (problem != null || extension == null) {
        await showMessageDialog(
          context,
          title: 'Chưa chọn được ảnh này',
          message: problem ?? kPhotoTypeMessage,
          icon: Icons.error_outline,
          isError: true,
        );
        return;
      }
      setState(() => _photo = (bytes: picked.bytes, extension: extension));
    } catch (error) {
      if (mounted) {
        await showErrorDialog(context, error);
      }
    }
  }

  Future<void> _save() async {
    if (_submitting) {
      return;
    }
    final isAdmin = ref.read(isAdminProvider);
    final photo = _photo;
    if (photo == null) {
      await showMessageDialog(
        context,
        title: isAdmin ? 'Chưa lưu được' : 'Chưa gửi được',
        message: 'Vui lòng chọn ảnh trước.',
        icon: Icons.error_outline,
        isError: true,
      );
      return;
    }
    final captionError = validateCaption(_caption.text);
    if (captionError != null) {
      setState(() => _captionError = captionError);
      return;
    }

    final tree = ref.read(treeDataProvider).value;
    final existing = photosOfPerson(
      tree?.photos ?? const <PersonPhoto>[],
      widget.personId,
    );
    final personName = tree?.people
            .where((p) => p.id == widget.personId)
            .firstOrNull
            ?.fullName ??
        'người này';
    final photoService = ref.read(photoServiceProvider);
    final pendingService = ref.read(pendingPhotoServiceProvider);
    final contentType = photoContentType(photo.extension);
    final publicPath = buildPhotoStoragePath(
      personId: widget.personId,
      photoId: _photoId,
      extension: photo.extension,
    );
    final note = _note.text.trim();

    if (!isAdmin) {
      final proceed = await confirmSubmit(
        context,
        isAdmin: false,
        summary: 'Gửi đề xuất thêm ảnh cho $personName?',
        slots: 1,
      );
      if (!proceed || !mounted) {
        return;
      }
    }

    setState(() => _submitting = true);
    String? uploadedPath;
    var uploadedToPending = false;
    var done = false;

    Future<void> cleanUp() async {
      final path = uploadedPath;
      if (path == null) {
        return;
      }
      if (uploadedToPending) {
        await pendingService.removeQuietly(path);
      } else {
        await photoService.removeQuietly(path);
      }
    }

    try {
      if (isAdmin) {
        await photoService.upload(
          storagePath: publicPath,
          bytes: photo.bytes,
          contentType: contentType,
        );
        uploadedPath = publicPath;
        if (!mounted) {
          return;
        }
        if (!ref.read(isAdminProvider)) {
          throw const UserFacingException(
            'Phiên quản trị đã hết. Hãy đăng nhập lại rồi thử lại.',
          );
        }
      } else {
        final contributor = await ensureContributor(context, ref);
        if (contributor == null || !mounted) {
          return;
        }
        final limitProblem = validatePendingLimit(
          await pendingService.countOwn(contributor.userId),
        );
        if (limitProblem != null) {
          throw UserFacingException(limitProblem);
        }
        final pendingPath = buildPendingPhotoPath(
          requesterId: contributor.userId,
          photoId: _photoId,
          extension: photo.extension,
        );
        await pendingService.upload(
          path: pendingPath,
          bytes: photo.bytes,
          contentType: contentType,
        );
        uploadedPath = pendingPath;
        uploadedToPending = true;
        if (!mounted) {
          return;
        }
      }

      final outcome = await submitChanges(
        context,
        ref,
        drafts: planAddPhoto(
          photoId: _photoId,
          personId: widget.personId,
          storagePath: publicPath,
          caption: _caption.text,
          sortOrder: nextSortOrder(existing),
          makeAvatar: isAdmin && existing.isEmpty,
        ),
        note: (isAdmin || note.isEmpty) ? null : note,
      );
      if (outcome == SubmitOutcome.cancelled) {
        await cleanUp();
        return;
      }
      done = true;
    } catch (error) {
      await cleanUp();
      if (mounted) {
        await showErrorDialog(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }

    if (done && mounted) {
      await showMessageDialog(
        context,
        title: isAdmin ? 'Đã lưu ảnh' : 'Đã gửi đề xuất ảnh',
        message: isAdmin
            ? 'Ảnh đã được thêm vào hồ sơ.'
            : 'Quản trị viên sẽ xem và duyệt.\n'
                'Ảnh sẽ hiện trong hồ sơ sau khi được duyệt.',
        icon: Icons.check_circle_outline,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final tree = ref.watch(treeDataProvider).value;
    final personName = tree?.people
            .where((p) => p.id == widget.personId)
            .firstOrNull
            ?.fullName ??
        'người này';
    final photo = _photo;

    return ListenableBuilder(
      listenable: _all,
      builder: (context, _) {
        return PopScope(
          canPop: !_dirty,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }
            final leave = await confirmLeaveWithoutSending(context);
            if (leave && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(isAdmin ? 'Thêm ảnh' : 'Đề xuất thêm ảnh'),
            ),
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            isAdmin
                                ? 'Thêm ảnh cho $personName. '
                                    'Ảnh được lưu ngay vào hồ sơ.'
                                : 'Bạn đang đề xuất thêm ảnh cho $personName. '
                                    'Ảnh chỉ hiện trong hồ sơ sau khi '
                                    'quản trị viên duyệt.',
                            style: const TextStyle(fontSize: 16, height: 1.4),
                          ),
                        ),
                        FormCard(
                          title: 'Chọn ảnh',
                          children: [
                            if (photo == null)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Chưa chọn ảnh. Ảnh JPEG, PNG hoặc WebP, '
                                  'tối đa 3 MB (app tự thu nhỏ khi chọn).',
                                  style: TextStyle(fontSize: 16, height: 1.4),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    photo.bytes,
                                    height: 240,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            SizedBox(
                              height: 56,
                              child: FilledButton.icon(
                                onPressed: _submitting ? null : _pick,
                                icon: const Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 28,
                                ),
                                label: Text(
                                  photo == null ? 'Chọn ảnh' : 'Chọn ảnh khác',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        FormCard(
                          title: 'Mô tả ảnh',
                          children: [
                            AppTextField(
                              controller: _caption,
                              label: 'Mô tả (không bắt buộc)',
                              errorText: _captionError,
                              maxLength: kPhotoCaptionMaxLength,
                              minLines: 2,
                              maxLines: 3,
                              onChanged: () {
                                if (_captionError != null) {
                                  setState(() => _captionError = null);
                                }
                              },
                            ),
                          ],
                        ),
                        if (!isAdmin) SenderCard(noteController: _note),
                      ],
                    ),
                  ),
                ),
                SubmitBar(
                  submitting: _submitting,
                  onPressed: _save,
                  label: isAdmin ? 'Lưu ảnh' : 'Gửi đề xuất ảnh',
                  submittingLabel: 'Đang tải lên...',
                  icon: isAdmin ? Icons.save : Icons.send,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}