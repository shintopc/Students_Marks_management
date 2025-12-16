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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for Windows
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Initialize Window Manager
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
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
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
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
