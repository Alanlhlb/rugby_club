import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ImageUploadService {
  static final _picker = ImagePicker();
  static final _storage = FirebaseStorage.instance;

  /// Pick an image from gallery or camera, crop it, then upload to Firebase Storage.
  /// Returns the download URL on success, or null if cancelled.
  static Future<String?> pickCropAndUpload({
    required BuildContext context,
    required String storagePath,
    double maxWidth = 512,
    double maxHeight = 512,
    int imageQuality = 80,
    CropAspectRatio? cropAspectRatio,
    bool lockAspectRatio = false,
  }) async {
    // 1. Show source picker
    final source = await _showSourcePicker(context);
    if (source == null) return null;

    // 2. Pick image
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    if (picked == null) return null;

    // 3. Crop image
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: cropAspectRatio,
      compressQuality: imageQuality,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '裁剪圖片',
          toolbarColor: const Color(0xFF1B5E20),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF1B5E20),
          lockAspectRatio: lockAspectRatio,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: '裁剪圖片',
          doneButtonTitle: '完成',
          cancelButtonTitle: '取消',
          aspectRatioLockEnabled: lockAspectRatio,
        ),
      ],
    );
    if (cropped == null) return null;

    // 4. Upload to Firebase Storage
    try {
      final file = File(cropped.path);
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('Image upload failed: $e');
      return null;
    }
  }

  /// Show a bottom sheet to choose camera or gallery
  static Future<ImageSource?> _showSourcePicker(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  '選擇圖片來源',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('拍照'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('從相簿選擇'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
