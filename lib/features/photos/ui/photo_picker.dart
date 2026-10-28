import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:familytree/features/photos/domain/photo_rules.dart';

/// Ảnh vừa chọn: nội dung và loại (nhận diện từ nội dung, null = không hợp lệ).
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String? extension;
}

/// Chọn ảnh từ camera hoặc thư viện. Trả null nếu người dùng hủy.
/// Ảnh được thu nhỏ ngay khi chọn để vừa giới hạn 3 MB.
Future<PickedPhoto?> pickPhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: kMaxPhotoSide,
    maxHeight: kMaxPhotoSide,
    imageQuality: kPhotoQuality,
  );
  if (file == null) {
    return null;
  }
  final bytes = await file.readAsBytes();
  return PickedPhoto(bytes: bytes, extension: detectPhotoExtension(bytes));
}

/// Bảng hỏi lấy ảnh từ đâu, hai nút to cao 56.
Future<ImageSource?> showPhotoSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Lấy ảnh từ đâu?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera, size: 28),
                  label: const Text(
                    'Chụp ảnh',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 28),
                  label: const Text(
                    'Chọn từ thư viện',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Hủy', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}