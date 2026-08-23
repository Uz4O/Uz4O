import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/uzbox_api.dart';
import 'app_theme.dart';
import 'main_shell.dart';
import 'startup_flow.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  runApp(const UzBoxApp());
}

class UzBoxApp extends StatelessWidget {
  const UzBoxApp({super.key, this.skipStartup = false, this.authApi});

  final bool skipStartup;
  final UzBoxAuthClient? authApi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UzBox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: '.SF Pro Text',
        scaffoldBackgroundColor: const Color(0xFFF8FAFA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: AppTheme.primary,
          displayColor: AppTheme.primary,
        ),
      ),
      home: skipStartup ? const MainShell() : StartupFlow(api: authApi),
    );
  }
}
