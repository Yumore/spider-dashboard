import 'dart:typed_data';

import 'package:dashboard/app/platform/app_platform.dart';
import 'package:image_picker/image_picker.dart';

/// Retains flutter-im's local camera/gallery selection, without inventing
/// an image-message protocol that the source server never implemented.
class ChatImageSelection {
  ChatImageSelection({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<Uint8List?> select(ImageSource source) async {
    if (!AppPlatform.supportsImagePicker) {
      throw UnsupportedError('当前平台不支持选择图片');
    }
    final image = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (image == null) return null;
    if (await image.length() > 20 * 1024 * 1024) {
      throw const FormatException('图片超过 20 MB，无法预览');
    }
    return image.readAsBytes();
  }
}
