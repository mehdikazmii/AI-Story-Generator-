import 'dart:io';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:logger/logger.dart';
import 'package:story_generator/models/failure.dart';
import 'package:story_generator/models/story_params.dart';

import '../../services/ai_service/ai_service.dart';
import '../../services/ai_service/i_ai_service.dart';
import '../shared/_shared.dart';

class StoryView extends StatefulWidget {
  final File image;
  final StoryParams storyParams;

  const StoryView({
    Key? key,
    required this.image,
    required this.storyParams,
  }) : super(key: key);

  @override
  State<StoryView> createState() => _StoryViewState();
}

class _StoryViewState extends State<StoryView> {
  final IAIService _aiService = AIService();
  final _logger = Logger();
  final _scrollController = ScrollController();
  bool isBusy = false;
  IFailure? failure;
  String story = '';
  bool isAnimationComplete = false;

  @override
  void initState() {
    super.initState();
    _fetchStory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchStory() async {
    if (isBusy) {
      _logger.d('Story generation already in progress');
      return;
    }

    try {
      setState(() {
        isBusy = true;
        failure = null;
        isAnimationComplete = false;
      });

      _logger.d('Fetching story with params: ${widget.storyParams}');
      story = await _aiService.fetchStoryDetail(widget.storyParams);
      _logger.d('Story generated successfully');
    } on IFailure catch (e) {
      _logger.e('Failure generating story', error: e);
      failure = e;
    } catch (e, stack) {
      _logger.e('Error generating story', error: e, stackTrace: stack);
      failure =
          Failure(message: 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() => isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Here's your ${widget.storyParams.genre.toLowerCase()} story",
          style: AppTextStyles.semiBold16,
        ),
        centerTitle: true,
        actions: [
          if (!isBusy && story.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchStory,
              tooltip: 'Generate new story',
            ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.file(
                widget.image,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: REdgeInsets.all(16),
              child: Builder(
                builder: (context) {
                  if (isBusy) {
                    return SizedBox(
                      height: 200.h,
                      child: const Center(
                        child: AppLoader(color: AppColors.bidPry400),
                      ),
                    );
                  }

                  if (failure != null || story.isEmpty) {
                    return SizedBox(
                      height: 200.h,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: REdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                failure?.message ??
                                    'Failed to generate story. Please try again.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.regular14,
                              ),
                            ),
                            Spacing.vertRegular(),
                            AppButton(
                              label: 'Try Again',
                              isCollapsed: true,
                              onPressed: _fetchStory,
                            )
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isAnimationComplete)
                        DefaultTextStyle(
                          style: AppTextStyles.regular16.copyWith(
                            color: AppColors.black,
                            height: 1.5,
                          ),
                          child: AnimatedTextKit(
                            totalRepeatCount: 1,
                            displayFullTextOnTap: true,
                            stopPauseOnTap: true,
                            onFinished: () {
                              setState(() => isAnimationComplete = true);
                            },
                            animatedTexts: [
                              TyperAnimatedText(
                                story,
                                speed: const Duration(milliseconds: 30),
                                textAlign: TextAlign.justify,
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          story,
                          style: AppTextStyles.regular16.copyWith(
                            color: AppColors.black,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
