import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'services/bible_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化服務
  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService.withPrefs(prefs);
  final bibleService = BibleService();
  
  // 載入使用者設定
  final themeMode = await storageService.loadThemeMode();
  final fontSize = await storageService.loadFontSize();
  
  runApp(MyApp(
    bibleService: bibleService,
    storageService: storageService,
    initialThemeMode: themeMode,
    initialFontSize: fontSize,
  ));
}

class MyApp extends StatefulWidget {
  final BibleService bibleService;
  final StorageService storageService;
  final ThemeMode initialThemeMode;
  final double initialFontSize;

  const MyApp({
    super.key,
    required this.bibleService,
    required this.storageService,
    required this.initialThemeMode,
    required this.initialFontSize,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ValueNotifier<ThemeMode> _themeNotifier;
  late final ValueNotifier<double> _fontSizeNotifier;
  bool _isInitialized = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _themeNotifier = ValueNotifier<ThemeMode>(widget.initialThemeMode);
    _fontSizeNotifier = ValueNotifier<double>(widget.initialFontSize);
    _initializeApp(); // 初始化應用程式
  }

  Future<void> _initializeApp() async {
    try {
      // 初始化 BibleService
      await widget.bibleService.initialize();
      
      // 初始化 StorageService
      await widget.storageService.initialize();
      
      // 載入主題模式
      final themeMode = await widget.storageService.loadThemeMode();
      _themeNotifier.value = themeMode;
      
      // 載入字體大小
      final fontSize = await widget.storageService.loadFontSize();
      _fontSizeNotifier.value = fontSize;
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '初始化失敗: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _themeNotifier.dispose();
    _fontSizeNotifier.dispose();
    super.dispose();
  }



  // 已在第 57 行定義了 initState 方法

  @override
  Widget build(BuildContext context) {
    // 根據初始化狀態決定顯示哪個畫面
    Widget homeWidget;
    if (_errorMessage.isNotEmpty) {
      // 如果有錯誤，顯示錯誤訊息
      homeWidget = Scaffold(
        body: Center(
          child: Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      // 直接顯示 HomeScreen，不使用 SplashScreen
      homeWidget = HomeScreen(
        bibleService: widget.bibleService,
        storageService: widget.storageService,
        themeNotifier: _themeNotifier,
        fontSizeNotifier: _fontSizeNotifier,
      );
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'BeliBle',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: homeWidget,
        );
      },
    );
  }
}
