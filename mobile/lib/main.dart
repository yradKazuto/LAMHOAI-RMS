import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';     
import 'firebase_options.dart';
import 'core/providers/auth_provider.dart';  
import 'core/routing/app_router.dart';  

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LamhoaiApp());
}

class LamhoaiApp extends StatelessWidget {
  const LamhoaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) => MaterialApp.router(
          title: 'LAMHOAI-RMS',
          routerConfig: AppRouter.create(auth),
        ),
      ),
    );
  }
}