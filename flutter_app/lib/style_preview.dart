import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'screens/styles_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const _StylePreviewApp());
}

class _StylePreviewApp extends StatelessWidget {
  const _StylePreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: '.SF Pro Text',
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
      home: const _StylePreviewHome(),
    );
  }
}

class _StylePreviewHome extends StatefulWidget {
  const _StylePreviewHome();

  @override
  State<_StylePreviewHome> createState() => _StylePreviewHomeState();
}

class _StylePreviewHomeState extends State<_StylePreviewHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) StylesScreen.openImmersive(context);
    });
  }

  @override
  Widget build(BuildContext context) => const StylesScreen();
}
