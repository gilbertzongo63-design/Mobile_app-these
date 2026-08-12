import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'models/prediction_result.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/help_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/language_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/password_reset_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/recycling_tips_screen.dart';
import 'screens/result_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/verify_email_screen.dart';

class AppRoutes {
  static const authGate = '/';
  static const auth = '/auth';
  static const home = '/home';
  static const scan = '/scan';
  static const result = '/result';
  static const history = '/history';
  static const settings = '/settings';
  static const language = '/settings/language';
  static const notifications = '/settings/notifications';
  static const privacy = '/settings/privacy';
  static const help = '/settings/help';
  static const recyclingTips = '/settings/recycling-tips';
  static const passwordReset = '/auth/password-reset';
  static const verifyEmail = '/auth/verify-email';

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case authGate:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const AuthGateScreen(),
        );
      case auth:
        final args = routeSettings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => AuthScreen(
            redirectToRoute: args?['redirectTo'] as String? ?? home,
            initialMode: args?['mode'] == 'login'
                ? AuthMode.login
                : AuthMode.register,
            googleIdToken: args?['googleIdToken'] as String?,
          ),
        );
      case home:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const HomeScreen(),
        );
      case scan:
        final args = routeSettings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => ScanScreen(
            initialImageBytes: args?['imageBytes'] as Uint8List?,
            initialImagePath: args?['imagePath'] as String?,
            initialImageName: args?['imageName'] as String?,
          ),
        );
      case result:
        final args = routeSettings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => ResultScreen(
            prediction: args?['prediction'] as PredictionResult?,
            imageBytes: args?['imageBytes'] as Uint8List?,
          ),
        );
      case history:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const HistoryScreen(),
        );
      case settings:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const SettingsScreen(),
        );
      case language:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const LanguageScreen(),
        );
      case notifications:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const NotificationsScreen(),
        );
      case privacy:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const PrivacyScreen(),
        );
      case help:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const HelpScreen(),
        );
      case recyclingTips:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const RecyclingTipsScreen(),
        );
      case passwordReset:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const PasswordResetScreen(),
        );
      case verifyEmail:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const VerifyEmailScreen(),
        );
      default:
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const AuthGateScreen(),
        );
    }
  }
}
