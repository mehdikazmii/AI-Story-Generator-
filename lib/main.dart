import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:logger/logger.dart';

import 'ui/shared/_shared.dart';
import 'ui/views/image_selector_view.dart';

final logger = Logger();

Future<void> main() async {
  // Make zone errors fatal in debug mode
  BindingBase.debugZoneErrorsAreFatal = true;

  // Create a zone specification for error handling
  final zoneSpec = ZoneSpecification(
    handleUncaughtError: (self, parent, zone, error, stackTrace) {
      logger.e('Uncaught error in zone', error: error, stackTrace: stackTrace);
    },
    print: (self, parent, zone, line) {
      // Intercept print statements for logging
      logger.d(line);
    },
  );

  // Run the app in a new zone with error handling
  runZonedGuarded(() async {
    // Initialize Flutter bindings inside the zone
    WidgetsFlutterBinding.ensureInitialized();

    // Set up error handling for Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      logger.e('Flutter Error',
          error: details.exception, stackTrace: details.stack);
      FlutterError.presentError(details);
    };

    // Set up platform error handling
    PlatformDispatcher.instance.onError = (error, stack) {
      logger.e('Platform Error', error: error, stackTrace: stack);
      return true;
    };

    // Run the app
    runApp(const MyApp());
  }, (error, stackTrace) {
    logger.e('Zoned Error', error: error, stackTrace: stackTrace);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppConstants.appName,
          theme: AppTheme.theme,
          home: const ImageSelectorView(),
        );
      },
    );
  }
}
