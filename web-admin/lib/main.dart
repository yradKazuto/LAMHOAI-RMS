// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // No more dotenv / env_config.txt — nothing this app needs at runtime
  // is a real secret anymore (Cloudinary uploads are unsigned, and push
  // notifications go through the send-notification serverless function,
  // which is the only place ONESIGNAL_REST_API_KEY still lives).

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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
            theme: AppTheme.lightTheme,
            routerConfig: router,
          );
        },
      ),
    );
  }
}