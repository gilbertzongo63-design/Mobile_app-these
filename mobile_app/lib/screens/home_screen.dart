import 'package:flutter/material.dart';
import '../l10n.dart';

import '../models/user_model.dart';
import '../services/category_service.dart';
import '../services/prediction_service.dart';
import '../services/user_service.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/app_logo.dart';
import '../app_routes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _categoryService = CategoryService();
  final _predictionService = PredictionService();

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBootstrapData();
    _syncPendingPredictions();
  }

  Future<void> _loadBootstrapData() async {
    await _categoryService.fetchCategories();
  }

  Future<void> _syncPendingPredictions() async {
    try {
      await _predictionService.syncPendingPredictions();
    } catch (_) {
      // Keep the app responsive even when sync cannot complete.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7ED),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBootstrapData,
          color: const Color(0xFF0E8A57),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
            children: [
              _buildTopBar(),
              const SizedBox(height: 22),
              _buildHeroBanner(),
              const SizedBox(height: 28),
              Text(
                AppLocalizations.of(context).t('home.welcome'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF17211C),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                AppLocalizations.of(context).t('home.subtitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  color: Color(0xFF5A655E),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.eco_rounded,
                      iconColor: const Color(0xFF14945D),
                      value: '12kg',
                      label: AppLocalizations.of(context).t('home.stat_month'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.stars_rounded,
                      iconColor: const Color(0xFFB3622C),
                      value: '850',
                      label: AppLocalizations.of(context).t('home.stat_points'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _PrimaryActionButton(
                icon: Icons.document_scanner_outlined,
                label: AppLocalizations.of(context).t('home.start_scan'),
                onPressed: () {
                  Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.scan);
                },
              ),
              const SizedBox(height: 14),
              _SecondaryActionButton(
                icon: Icons.history_toggle_off_rounded,
                label: AppLocalizations.of(context).t('home.view_history'),
                onPressed: () {
                  Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.history);
                },
              ),
              const SizedBox(height: 28),
              Text(
                AppLocalizations.of(context).t('home.daily_tips'),
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4E5752),
                ),
              ),
              const SizedBox(height: 14),
              const _TipCard(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: _selectedIndex,
        onChanged: _handleNavigation,
      ),
    );
  }

  void _handleNavigation(int index) {
    if (index == _selectedIndex) {
      return;
    }

    if (index == 1) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.scan);
      return;
    }

    if (index == 2) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.history);
      return;
    }

    if (index == 3) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.settings);
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildTopBar() {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: UserService.currentUser,
      builder: (context, user, child) {
        return Row(
          children: [
            const AppBrand(),
            const Spacer(),
            GestureDetector(
              onTap: () {
                Navigator.of(context)
                    .pushReplacementNamed(AppRoutes.settings);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFDFF4E8),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF19A85E),
                    width: 2,
                  ),
                  image: user?.profileImageUrl.isNotEmpty == true
                      ? DecorationImage(
                          image: NetworkImage(user!.profileImageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: user?.profileImageUrl.isNotEmpty == true
                    ? null
                    : const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF0A8A52),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Container(
            height: 280,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF173926),
                  Color(0xFF2F6A33),
                  Color(0xFF79B93D),
                ],
              ),
            ),
          ),
          const Positioned(
            left: -10,
            top: -12,
            child: _LeafShape(
              width: 220,
              height: 190,
              color: Color(0xFF2B5E2A),
              rotation: -0.35,
            ),
          ),
          const Positioned(
            right: -18,
            top: -6,
            child: _LeafShape(
              width: 210,
              height: 220,
              color: Color(0xFFB6E44F),
              rotation: 0.18,
            ),
          ),
          const Positioned(
            left: 72,
            bottom: 28,
            child: _LeafShape(
              width: 250,
              height: 160,
              color: Color(0x663E7F3D),
              rotation: 0.08,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.40),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).t('home.hero.title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context).t('home.hero.subtitle'),
                  style: const TextStyle(
                    color: Color(0xFFE7F4E9),
                    fontSize: 12,
                    height: 1.4,
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

class _LeafShape extends StatelessWidget {
  const _LeafShape({
    required this.width,
    required this.height,
    required this.color,
    required this.rotation,
  });

  final double width;
  final double height;
  final Color color;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(width * 0.55),
            topRight: Radius.circular(width * 0.2),
            bottomLeft: Radius.circular(width * 0.2),
            bottomRight: Radius.circular(width * 0.55),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _LeafVeinPainter(),
        ),
      ),
    );
  }
}

class _LeafVeinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final veinPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final centerPath = Path()
      ..moveTo(size.width * 0.15, size.height * 0.9)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.45,
        size.width * 0.82,
        size.height * 0.08,
      );
    canvas.drawPath(centerPath, veinPaint);

    for (final factor in [0.28, 0.42, 0.58, 0.72]) {
      final branch = Path()
        ..moveTo(size.width * factor, size.height * (0.74 - factor * 0.25))
        ..quadraticBezierTo(
          size.width * (factor + 0.08),
          size.height * (0.55 - factor * 0.15),
          size.width * (factor + 0.16),
          size.height * (0.28 - factor * 0.08),
        );
      canvas.drawPath(branch, veinPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16331F).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF19231E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF5D6660),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF33CB72),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        icon: const Icon(Icons.document_scanner_outlined, size: 24),
        label: Text(label),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF2AC66C),
          side: const BorderSide(color: Color(0xFF2AC66C), width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        icon: const Icon(Icons.history_toggle_off_rounded, size: 24),
        label: Text(label),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFD5F8D6),
            Color(0xFFE7F8D8),
          ],
        ),
        border: Border.all(color: const Color(0xFFCDEED0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TipIcon(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).t('home.tip.did_you_know'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF147A4E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context).t('home.tip.fact'),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: Color(0xFF2F4537),
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

class _TipIcon extends StatelessWidget {
  const _TipIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF64F28A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.lightbulb_outline_rounded,
        color: Color(0xFF0E7C4F),
      ),
    );
  }
}
