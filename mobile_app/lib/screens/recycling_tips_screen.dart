import 'package:flutter/material.dart';

import '../l10n.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/app_logo.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class RecyclingTipsScreen extends StatelessWidget {
  const RecyclingTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF5F9F0);
    const darkGreen = Color(0xFF0A8A52);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: darkGreen,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context).t('recycling.title'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: darkGreen,
                            ),
                          ),
                        ),
                        const AppLogo(size: 32),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppLocalizations.of(context).t('recycling.tips_title'),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF17211C),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _HeroTipCard(),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _MiniTipCard(
                            icon: Icons.call_split_rounded,
                            title: AppLocalizations.of(context)
                                .t('recycling.tip_no_nesting.title'),
                            body: AppLocalizations.of(context)
                                .t('recycling.tip_no_nesting.body'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MiniTipCard(
                            icon: Icons.auto_awesome_rounded,
                            title: AppLocalizations.of(context)
                                .t('recycling.tip_empty.title'),
                            body: AppLocalizations.of(context)
                                .t('recycling.tip_empty.body'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const _ScanSuccessCard(),
                    const SizedBox(height: 28),
                    Text(
                      AppLocalizations.of(context)
                          .t('recycling.quick_guide_title'),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF17211C),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SortingGuideCard(
                      title: AppLocalizations.of(context)
                          .t('recycling.sorting.recyclable.title'),
                      description: AppLocalizations.of(context)
                          .t('recycling.sorting.recyclable.description'),
                      badge: AppLocalizations.of(context)
                          .t('recycling.sorting.recyclable.badge'),
                      leadingIcon: Icons.recycling_rounded,
                      accent: const Color(0xFF0E8A57),
                    ),
                    const SizedBox(height: 14),
                    _SortingGuideCard(
                      title: AppLocalizations.of(context)
                          .t('recycling.sorting.check.title'),
                      description: AppLocalizations.of(context)
                          .t('recycling.sorting.check.description'),
                      badge: AppLocalizations.of(context)
                          .t('recycling.sorting.check.badge'),
                      leadingIcon: Icons.help_outline_rounded,
                      accent: const Color(0xFFF09A2D),
                    ),
                    const SizedBox(height: 14),
                    _SortingGuideCard(
                      title: AppLocalizations.of(context)
                          .t('recycling.sorting.non_recyclable.title'),
                      description: AppLocalizations.of(context)
                          .t('recycling.sorting.non_recyclable.description'),
                      badge: AppLocalizations.of(context)
                          .t('recycling.sorting.non_recyclable.badge'),
                      leadingIcon: Icons.delete_outline_rounded,
                      accent: const Color(0xFF707C74),
                    ),
                    const SizedBox(height: 22),
                    const _ClosingBanner(),
                  ],
                ),
              ),
            ),
            AppBottomNavBar(
              selectedIndex: 3,
              onChanged: (index) {
                if (index == 0) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                } else if (index == 1) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const ScanScreen()),
                  );
                } else if (index == 2) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                } else if (index == 3) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroTipCard extends StatelessWidget {
  const _HeroTipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFF67F69A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.opacity_outlined,
              size: 32,
              color: Color(0xFF0A8A52),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).t('recycling.hero.title'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF17211C),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context).t('recycling.hero.body'),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: Color(0xFF39473E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTipCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _MiniTipCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 260),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 34, color: const Color(0xFF0A8A52)),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF17211C),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              color: Color(0xFF39473E),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanSuccessCard extends StatelessWidget {
  const _ScanSuccessCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
      decoration: BoxDecoration(
        color: const Color(0xFF08793E),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).t('recycling.scan_success.title'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context).t('recycling.scan_success.body'),
            style: const TextStyle(
              fontSize: 16,
              height: 1.45,
              color: Color(0xFFF0FFF4),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _ScanHint(
                  icon: Icons.wb_sunny_outlined,
                  label: AppLocalizations.of(context)
                      .t('recycling.scan_hint.light'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ScanHint(
                  icon: Icons.filter_center_focus_outlined,
                  label: AppLocalizations.of(context)
                      .t('recycling.scan_hint.centered'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ScanHint(
                  icon: Icons.grid_on_rounded,
                  label: AppLocalizations.of(context)
                      .t('recycling.scan_hint.neutral_background'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanHint extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ScanHint({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _SortingGuideCard extends StatelessWidget {
  final String title;
  final String description;
  final String badge;
  final IconData leadingIcon;
  final Color accent;

  const _SortingGuideCard({
    required this.title,
    required this.description,
    required this.badge,
    required this.leadingIcon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8ED),
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(color: accent, width: 4),
        ),
      ),
      child: Row(
        children: [
          Icon(leadingIcon, size: 40, color: accent),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: Color(0xFF2F3A32),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFD7E9D6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0E5E3D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosingBanner extends StatelessWidget {
  const _ClosingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 202,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF6AA44B), Color(0xFF285B2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: SizedBox(
                width: 210,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 16,
                      child: Container(
                        width: 118,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDFE5DE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 22,
                      top: 16,
                      child: Container(
                        width: 106,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC8D0C6),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x44000000),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Positioned(
                      right: 6,
                      top: 18,
                      child: Icon(
                        Icons.arrow_right_alt_rounded,
                        color: Color(0xBFFFFFFF),
                        size: 42,
                      ),
                    ),
                    Positioned(
                      left: 58,
                      bottom: 6,
                      child: Row(
                        children: List.generate(
                          3,
                          (index) => Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: index == 1 ? 1 : 0.45,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Text(
            AppLocalizations.of(context).t('recycling.closing_banner'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
