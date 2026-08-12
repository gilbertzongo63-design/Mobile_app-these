import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_routes.dart';
import 'l10n.dart';

class WasteSortingMobileApp extends StatefulWidget {
  const WasteSortingMobileApp({super.key});

  static WasteSortingMobileAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<WasteSortingMobileAppState>();
  }

  @override
  State<WasteSortingMobileApp> createState() => WasteSortingMobileAppState();
}

class WasteSortingMobileAppState extends State<WasteSortingMobileApp> {
  static const _localeKey = 'preferred_language_code';
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_localeKey);
    if (languageCode != null && ['fr', 'en'].contains(languageCode)) {
      setState(() {
        _locale = Locale(languageCode);
      });
    }
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    if (!mounted) return;
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: ValueKey(_locale?.languageCode ?? 'default'),
      debugShowCheckedModeBanner: false,
      title: 'EcoRecycle',
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr'), Locale('en')],
      initialRoute: AppRoutes.authGate,
      onGenerateRoute: AppRoutes.generateRoute,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D6B4D),
          secondary: const Color(0xFFDE8F2A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F1E8),
        useMaterial3: true,
      ),
    );
  }
}
