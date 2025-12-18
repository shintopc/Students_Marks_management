import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/config_provider.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/main_screen.dart';
import 'data/local/database_helper.dart';
import 'data/logic/grading_engine.dart';
import 'data/local/database_reset_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for Windows
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Initialize Window Manager
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(450, 600),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Ensure DB is ready
  // CHECK FOR VERSION-BASED RESET
  // Must run before DatabaseHelper accesses the DB
  await DatabaseResetService.checkAndResetDatabase();

  // Ensure DB is ready
  await DatabaseHelper.instance.database;

  // Initialize Grading Engine (Load Rules)
  await GradingEngine().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => ConfigProvider()..loadSchoolProfile(),
        ),
      ],
      child: MaterialApp(
        title: 'Student Marks Management System',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E3192), // Professional Blue
            brightness: Brightness.light,
            surface: Colors.white,
            error: const Color(0xFFD32F2F),
          ),
          scaffoldBackgroundColor: const Color(
            0xFFF8F9FA,
          ), // Professional Off-White
          fontFamily: 'Segoe UI', // Windows Standard
          // Input Theme
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2E3192), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD32F2F)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),

          // Button Theme
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              backgroundColor: const Color(0xFF2E3192),
              foregroundColor: Colors.white,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: const BorderSide(color: Color(0xFF2E3192)),
            ),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.select((AuthProvider p) => p.isLoggedIn);

    if (isLoggedIn) {
      return const MainScreen();
    } else {
      return const LoginScreen();
    }
  }
}
