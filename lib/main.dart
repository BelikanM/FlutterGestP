import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'pages/registration_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/employees_page.dart';

import 'session_service.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser MediaKit uniquement sur Windows (pas supporté sur Android/Web)
  if (!kIsWeb && Platform.isWindows) {
    MediaKit.ensureInitialized();
  }
  
  // Initialiser les notifications
  await NotificationService.initialize();
  
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  bool _isCheckingSession = true;
  bool _hasValidSession = false;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    try {
      // Vérification plus stricte des sessions
      final isSessionValid = await SessionService.isSessionValid();
      
      if (!isSessionValid) {
        // Si la session n'est pas valide, nettoyer les données
        await SessionService.clearAllUserData();
        if (mounted) {
          setState(() {
            _hasValidSession = false;
            _isCheckingSession = false;
          });
        }
        return;
      }
      
      final hasSession = await SessionService.tryAutoLogin();
      if (mounted) {
        setState(() {
          _hasValidSession = hasSession;
          _isCheckingSession = false;
        });
      }
    } catch (e) {
      // En cas d'erreur, nettoyer complètement les données
      await SessionService.clearAllUserData();
      if (mounted) {
        setState(() {
          _hasValidSession = false;
          _isCheckingSession = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mon App Flutter',
      theme: ThemeData(primarySwatch: Colors.blue),
      navigatorKey: NavigationService.navigatorKey,
      home: _isCheckingSession
          ? const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Vérification de la session...'),
                  ],
                ),
              ),
            )
          : _hasValidSession
              ? DashboardPage()
              : const RegistrationPage(),
      routes: {
        '/registration': (context) => const RegistrationPage(),
        '/dashboard': (context) => DashboardPage(),
        '/employees': (context) => const EmployeesPage(),
      },
    );
  }
}

// NavigationService pour gérer la navigation globale
class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}