// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/routing/app_router.dart';
import 'firebase_options.dart'; // Uncomment after running flutterfire configure

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
   options: DefaultFirebaseOptions.currentPlatform, // Uncomment after flutterfire configure
  );
  runApp(const LamhoaiApp());
}

class LamhoaiApp extends StatelessWidget {
  const LamhoaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: Builder(
        builder: (context) {
          final authProvider = context.read<AuthProvider>();
          final router = createRouter(authProvider);

          return MaterialApp.router(
            title: 'LAMHOAI – RMS',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(),
            routerConfig: router,
          );
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    const Color navy = Color(0xFF0D2A5C);
    const Color accent = Color(0xFF2E6BE6);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: accent,
      ),
      scaffoldBackgroundColor: const Color(0xFFF0F4FB),
      fontFamily: 'Inter', // Add inter to pubspec or use default
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFF1A2B4A)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}