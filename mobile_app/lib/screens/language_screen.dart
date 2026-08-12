import 'package:flutter/material.dart';

import '../app.dart';
import '../l10n.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../app_routes.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguageCode = 'fr';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locale = Localizations.localeOf(context);
      if (mounted && ['fr', 'en'].contains(locale.languageCode)) {
        setState(() {
          _selectedLanguageCode = locale.languageCode;
        });
      }
    });
  }

  Future<void> _saveLanguage() async {
    final locale = Locale(_selectedLanguageCode);
    await WasteSortingMobileApp.of(context)?.setLocale(locale);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.settings,
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF5F9F0);
    const darkGreen = Color(0xFF0A8A52);

    final translations = AppLocalizations.of(context);
    final options = [
      {'flag': _Flags.fr, 'code': 'fr'},
      {'flag': _Flags.gb, 'code': 'en'},
    ];

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF7FBF3),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE3EBDD)),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () =>
                                Navigator.of(context)
                                    .pushReplacementNamed(AppRoutes.settings),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: darkGreen,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              translations.t('language.title'),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: darkGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Opacity(
                            opacity: 0,
                            child: Icon(
                              Icons.arrow_back_rounded,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(36, 34, 36, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            translations.t('language.description'),
                            style: const TextStyle(
                              fontSize: 18,
                              height: 1.45,
                              color: Color(0xFF344239),
                            ),
                          ),
                          const SizedBox(height: 28),
                          ...options.map(
                            (option) {
                              final code = option['code'] as String;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: _LanguageOption(
                                  flag: option['flag'] as String,
                                  label: translations.t('language.label.$code'),
                                  selected: _selectedLanguageCode == code,
                                  onTap: () {
                                    setState(() {
                                      _selectedLanguageCode = code;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 82,
                            child: ElevatedButton(
                              onPressed: _saveLanguage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: darkGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              child:
                                  Text(translations.t('language.save_button')),
                            ),
                          ),
                          const SizedBox(height: 34),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(26, 22, 24, 24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF71F59D),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Icon(
                                    Icons.translate_rounded,
                                    color: Color(0xFF0B6E42),
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        translations.t('language.help_title'),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0B6E42),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        translations.t('language.help_body'),
                                        style: const TextStyle(
                                          fontSize: 17,
                                          height: 1.45,
                                          color: Color(0xFF0B6E42),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppBottomNavBar(
              selectedIndex: 3,
              onChanged: (index) {
                if (index == 0) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.home,
                    (route) => false,
                  );
                } else if (index == 1) {
                  Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.scan);
                } else if (index == 2) {
                  Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.history);
                } else if (index == 3) {
                  Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.settings);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String flag;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.flag,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0F7EC) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF17211C),
                ),
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF08793E)
                      : const Color(0xFF718172),
                  width: 2,
                ),
                color: selected ? const Color(0xFF08793E) : Colors.white,
              ),
              child: selected
                  ? const Center(
                      child: Icon(
                        Icons.circle,
                        size: 14,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

abstract final class _Flags {
  static const fr = '\u{1F1EB}\u{1F1F7}';
  static const gb = '\u{1F1EC}\u{1F1E7}';
}
