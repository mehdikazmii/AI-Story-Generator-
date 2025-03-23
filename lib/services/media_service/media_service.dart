import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';

import '../../models/failure.dart';
import 'i_media_service.dart';

class MediaService extends IMediaService {
  final _log = Logger();
  final ImagePicker _picker = ImagePicker();

  @override
  Future<File?> pickImage({required bool fromGallery}) async {
    try {
      _log.d(
          'Attempting to pick image from ${fromGallery ? 'gallery' : 'camera'}');

      final source = fromGallery ? ImageSource.gallery : ImageSource.camera;
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (pickedFile == null) {
        _log.d('No image was selected');
        return null;
      }

      _log.d('Image picked successfully: ${pickedFile.path}');
      final file = File(pickedFile.path);

      if (!await file.exists()) {
        throw Failure(message: 'Selected image file does not exist');
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Failure(message: 'Selected image file is empty');
      }

      return file;
    } on Failure {
      rethrow;
    } catch (e, stack) {
      _log.e('Error picking image', error: e, stackTrace: stack);
      throw Failure(message: 'Failed to pick image. Please try again.');
    }
  }

  @override
  Future<File?> pickVideo({required bool fromGallery}) async {
    try {
      _log.d(
          'Starting video pick process from: ${fromGallery ? 'gallery' : 'camera'}');

      final XFile? video = await _picker.pickVideo(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
      );

      if (video == null) {
        _log.d('No video was selected');
        return null;
      }

      _log.d('Video picked successfully at path: ${video.path}');

      final file = File(video.path);
      if (!await file.exists()) {
        _log.e('Selected video file does not exist at path: ${video.path}');
        throw Failure(message: 'Selected video file not found');
      }

      return file;
    } on Failure {
      rethrow;
    } catch (e, s) {
      _log.e('Error picking video', error: e, stackTrace: s);
      throw Failure(message: 'Error selecting video', data: e);
    }
  }
}
