// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:logger/logger.dart';
import 'package:story_generator/models/failure.dart';
import 'package:story_generator/models/story_params.dart';
import 'package:story_generator/services/ai_service/ai_service.dart';
import 'package:story_generator/services/ai_service/i_ai_service.dart';
import 'package:story_generator/services/media_service/media_service.dart';
import 'package:story_generator/ui/views/story_view.dart';

import '../shared/_shared.dart';
import '../shared/components/general/upload_image_card.dart';

class ImageSelectorView extends StatefulWidget {
  const ImageSelectorView({super.key});

  @override
  State<ImageSelectorView> createState() => _ImageSelectorViewState();
}

class _ImageSelectorViewState extends State<ImageSelectorView> {
  final IAIService _aiService = AIService();
  final _mediaService = MediaService();
  final _logger = Logger();
  File? image;
  String genre = AppConstants.genres.first;
  String length = AppConstants.storyLength.first;
  bool isBusy = false;
  String language = AppConstants.languages.first;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickImage() async {
    if (isBusy) {
      _logger.d('Image picking already in progress');
      return;
    }

    try {
      setState(() => isBusy = true);
      _logger.d('Starting image selection process');

      final currentZone = Zone.current;

      final fromGallery =
          await currentZone.run(() => ImageSourceDialog.show(context));
      if (fromGallery == null) {
        _logger.d('User cancelled image selection');
        return;
      }

      _logger.d(
          'Attempting to pick image from ${fromGallery ? 'gallery' : 'camera'}');

      // Run the image picker in the current zone
      final selectedImage = await currentZone
          .run(() => _mediaService.pickImage(fromGallery: fromGallery));

      if (!mounted) {
        _logger.d('Widget no longer mounted after image selection');
        return;
      }

      if (selectedImage != null) {
        _logger.d('Image selected successfully: ${selectedImage.path}');
        setState(() {
          image = selectedImage;
        });
      } else {
        _logger.d('No image was selected');
      }
    } on Failure catch (e, stack) {
      _logger.e('Failure during image selection', error: e, stackTrace: stack);
      if (mounted) {
        _showError(e.message);
      }
    } catch (e, stack) {
      _logger.e('Unexpected error during image selection',
          error: e, stackTrace: stack);
      if (mounted) {
        _showError('An unexpected error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => isBusy = false);
        _logger.d('Setting busy state to false');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.appName, style: AppTextStyles.semiBold18),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ScrollableColumn(
              padding: REdgeInsets.all(24),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload an image',
                  style: AppTextStyles.medium14.copyWith(
                    color: AppColors.black,
                  ),
                ),
                Spacing.vertSmall(),
                UploadImageCard(
                  onTap: isBusy ? null : _pickImage,
                ),
                if (image != null) ...[
                  Spacing.vertRegular(),
                  Container(
                    width: double.maxFinite,
                    height: 200.h,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.bidPry600, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        image!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          _logger.e('Error loading image',
                              error: error, stackTrace: stackTrace);
                          return const Center(
                            child: Icon(Icons.error_outline, color: Colors.red),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                Spacing.vertRegular(),
                AppDropdownField(
                  label: 'Genre',
                  hint: 'Select genre',
                  items: AppConstants.genres,
                  value: genre,
                  onChanged: (val) => genre = val!,
                ),
                Spacing.vertRegular(),
                AppDropdownField(
                  label: 'Story Length',
                  hint: 'Select length',
                  items: AppConstants.storyLength,
                  value: length,
                  onChanged: (val) => length = val!,
                ),
                Spacing.vertRegular(),
                AppDropdownField(
                  label: 'Language',
                  hint: 'Select language',
                  items: AppConstants.languages,
                  value: language,
                  onChanged: (val) => language = val!,
                ),
                const Spacer(),
                Spacing.vertRegular(),
                AppButton(
                  label: 'Generate Story',
                  isBusy: isBusy,
                  onPressed: () async {
                    try {
                      setState(() => isBusy = true);
                      if (image == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please select an image')),
                        );
                        return;
                      }
                      final items = await _aiService.getItemsFromImage(image!);
                      if (items.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No items found in this image, please select another image.',
                            ),
                          ),
                        );
                        return;
                      }

                      final params = StoryParams(
                        items: items,
                        genre: genre,
                        length: length,
                        language: language,
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              StoryView(image: image!, storyParams: params),
                        ),
                      );
                    } on IFailure catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message)),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    } finally {
                      setState(() => isBusy = false);
                    }
                  },
                ),
              ],
            ),
            if (isBusy)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
