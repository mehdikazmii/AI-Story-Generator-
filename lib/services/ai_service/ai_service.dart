import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logger/logger.dart';
import 'package:story_generator/models/failure.dart';
import 'package:story_generator/models/item_data.dart';
import 'package:story_generator/services/ai_service/i_ai_service.dart';
import 'package:story_generator/ui/shared/constants/env_data.dart';

import '../../models/story_params.dart';

class AIService extends IAIService {
  final _log = Logger();
  GenerativeModel? _imageModel;
  GenerativeModel? _textModel;
  bool _isInitialized = false;

  AIService() {
    _initializeModels();
  }

  void _initializeModels() {
    if (_isInitialized) return;

    try {
      _imageModel = GenerativeModel(
        model: 'gemini-1.5-flash-latest',
        apiKey: EnvData.apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 1,
          topP: 1,
          maxOutputTokens: 2048,
        ),
      );

      _textModel = GenerativeModel(
        model: 'gemini-1.5-pro-latest',
        apiKey: EnvData.apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.9,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 4096,
        ),
      );

      _isInitialized = true;
      _log.d('AI models initialized successfully');
    } catch (e, s) {
      _log.e('Error initializing AI models', error: e, stackTrace: s);
      throw Failure(
        message: 'Failed to initialize AI service. Please check your API key.',
        data: e,
      );
    }
  }

  static const listPrompt = '''
Please analyze this image and identify the main visible objects.
Provide a simple list of objects with brief descriptions.
Format your response as a JSON array of objects, each with "name" and "description" fields.
Example format: [{"name": "cat", "description": "orange tabby cat sitting"}]
Focus only on clearly visible objects and keep descriptions concise.
''';

  @override
  Future<List<String>> getItemsFromImage(File image) async {
    if (!_isInitialized || _imageModel == null) {
      throw Failure(message: 'AI service not properly initialized');
    }

    try {
      _log.d('Reading image file');
      final imageBytes = await compute(_readFileBytes, image.path);

      if (imageBytes.isEmpty) {
        throw Failure(message: 'Selected image is empty or corrupted.');
      }

      _log.d('Creating content for image analysis');
      final content = [
        Content.multi([
          TextPart(listPrompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      _log.d('Sending request to Gemini API');
      final res = await _imageModel!
          .generateContent(content)
          .timeout(const Duration(seconds: 30));

      _log.d('Raw response from API: ${res.text}');

      if (res.text == null || res.text!.isEmpty) {
        throw Failure(message: 'Failed to analyze image. Please try again.');
      }

      return await compute(_processImageResponse, res.text!);
    } on TimeoutException {
      _log.e('Request timed out');
      throw Failure(
          message:
              'Request timed out. Please check your internet connection and try again.');
    } catch (e, s) {
      _log.e('Error in getItemsFromImage', error: e, stackTrace: s);
      if (e is Failure) rethrow;
      throw Failure(
        message: 'Something went wrong identifying items. Please try again.',
        data: e,
      );
    }
  }

  static Future<Uint8List> _readFileBytes(String path) async {
    try {
      return await File(path).readAsBytes();
    } catch (e) {
      throw Failure(message: 'Error reading image file. Please try again.');
    }
  }

  static Future<List<String>> _processImageResponse(String responseText) async {
    String jsonStr = responseText;
    if (!jsonStr.trim().startsWith('[')) {
      final startIdx = jsonStr.indexOf('[');
      final endIdx = jsonStr.lastIndexOf(']');
      if (startIdx != -1 && endIdx != -1) {
        jsonStr = jsonStr.substring(startIdx, endIdx + 1);
      }
    }

    try {
      final parsedRes = jsonDecode(jsonStr);
      if (parsedRes is! List) {
        throw const FormatException('Invalid response format');
      }

      final data = parsedRes.map((e) => ItemData.fromMap(e)).toList();
      if (data.isEmpty) {
        throw Failure(message: 'No objects were detected in the image.');
      }
      return data.map((e) => e.value).toList();
    } on FormatException catch (e) {
      throw Failure(
        message: 'Error processing AI response. Please try again.',
        data: e,
      );
    }
  }

  @override
  Future<String> fetchStoryDetail(StoryParams storyParams) async {
    if (!_isInitialized || _textModel == null) {
      throw Failure(message: 'AI service not properly initialized');
    }

    try {
      _log.d('Creating story prompt');
      final prompt = _createStoryPrompt(storyParams);
      final content = [Content.text(prompt)];

      _log.d('Sending request to Gemini API');
      final response = await _textModel!
          .generateContent(content)
          .timeout(const Duration(seconds: 60));

      _log.d('Received response: ${response.text}');

      if (response.text == null || response.text!.isEmpty) {
        throw Failure(message: 'No story was generated. Please try again.');
      }

      return response.text!;
    } on TimeoutException {
      _log.e('Request timed out');
      throw Failure(
          message:
              'Request timed out. Please check your internet connection and try again.');
    } catch (e, s) {
      _log.e('Error in fetchStoryDetail', error: e, stackTrace: s);
      if (e is Failure) rethrow;
      throw Failure(
        message:
            'Something went wrong generating your story. Please try again.',
        data: e,
      );
    }
  }

  String _createStoryPrompt(StoryParams storyParams) {
    return '''
Create a ${storyParams.genre} story based on these items: ${storyParams.items.join(', ')}.
The story should be ${storyParams.parsedLength} in length.
Language: ${storyParams.language}
Cultural context: The story should reflect the culture and traditions where ${storyParams.language} is commonly spoken.

Please ensure the story:
1. Is engaging and appropriate for the genre
2. Incorporates all the listed items naturally
3. Maintains consistent tone and style
4. Is culturally appropriate for the specified language
5. Has a clear beginning, middle, and end
6. Generates only one complete story

Important: Generate only one complete story. Do not generate multiple versions or variations.
''';
  }

  @override
  Stream<String> streamStoryDetail(StoryParams storyParams) async* {
    throw UnimplementedError('Story streaming is not currently supported');
  }
}
