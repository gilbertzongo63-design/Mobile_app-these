import 'package:flutter/material.dart';

import 'screens/auth_gate_screen.dart';

class WasteSortingMobileApp extends StatelessWidget {
  const WasteSortingMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoRecycle',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D6B4D),
          secondary: const Color(0xFFDE8F2A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F1E8),
        useMaterial3: true,
      ),
      home: const AuthGateScreen(),
    );
  }
}
