// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'core/providers/auth_provider.dart';
import 'core/routing/app_router.dart';
import 'core/services/fcm_service.dart';
import 'core/services/notification_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const LamhoaiApp());
}

class LamhoaiApp extends StatefulWidget {
  const LamhoaiApp({super.key});

  @override
  State<LamhoaiApp> createState() => _LamhoaiAppState();
}

class _LamhoaiAppState extends State<LamhoaiApp> {
  late final GoRouter     _router;
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _router       = AppRouter.create(_authProvider);

    // Initialize FCM after first frame — wrapped in try/catch + timeout
    // so a slow connection or permission denial never blocks the app
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await FCMService.instance.initialize(
          onMessageTap: (message) {
            NotificationHandler.handleMessage(message, _router);
          },
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('FCM init timed out — continuing without FCM');
          },
        );
      } catch (e) {
        debugPrint('FCM init error: $e — continuing without FCM');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _authProvider,
      child: MaterialApp.router(
        title:                      'LAMHOAI-RMS',
        debugShowCheckedModeBanner: false,
        routerConfig:               _router,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E52A0),
          ),
          useMaterial3: true,
        ),
      ),
    );
  }
}