import 'package:flutter/material.dart';

import '../services/notification_preferences_service.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationPreferencesService = NotificationPreferencesService();
  bool _reminders = true;
  bool _tips = true;
  bool _activity = false;
  bool _criticalAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await _notificationPreferencesService.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _reminders = preferences.reminders;
      _tips = preferences.tips;
      _activity = preferences.activity;
      _criticalAlerts = preferences.criticalAlerts;
    });
  }

  Future<void> _savePreferences() {
    return _notificationPreferencesService.save(
      NotificationPreferences(
        reminders: _reminders,
        tips: _tips,
        activity: _activity,
        criticalAlerts: _criticalAlerts,
      ),
    );
  }

  void _goToTab(int index) {
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
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF5FCF1);
    const darkGreen = Color(0xFF007A3D);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(25, 14, 25, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          onPressed: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: darkGreen,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: darkGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    const _NotificationsHero(),
                    const SizedBox(height: 20),
                    _NotificationCard(
                      title: 'Rappels',
                      description: 'Recevez des rappels pour sortir vos poubelles.',
                      value: _reminders,
                      onChanged: (value) {
                        setState(() {
                          _reminders = value;
                        });
                        _savePreferences();
                      },
                    ),
                    const SizedBox(height: 14),
                    _NotificationCard(
                      title: 'Conseils de tri',
                      description:
                          'Recevez de nouvelles astuces pour mieux trier.',
                      value: _tips,
                      onChanged: (value) {
                        setState(() {
                          _tips = value;
                        });
                        _savePreferences();
                      },
                    ),
                    const SizedBox(height: 14),
                    _NotificationCard(
                      title: 'Activité',
                      description: 'Alertes sur vos statistiques et badges.',
                      value: _activity,
                      onChanged: (value) {
                        setState(() {
                          _activity = value;
                        });
                        _savePreferences();
                      },
                    ),
                    const SizedBox(height: 14),
                    _NotificationCard(
                      title: 'Alertes importantes',
                      description: 'Mises à jour critiques sur le service.',
                      value: _criticalAlerts,
                      locked: true,
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 20),
                    const _CriticalNote(),
                  ],
                ),
              ),
            ),
            AppBottomNavBar(
              selectedIndex: 3,
              onChanged: _goToTab,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsHero extends StatelessWidget {
  const _NotificationsHero();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: double.infinity,
        height: 136,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFC8F3DC), Color(0xFFAEE5C9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Stack(
          children: [
            Positioned.fill(child: _HeroPattern()),
            Positioned(
              left: 18,
              right: 18,
              bottom: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SortingBin(
                    label: 'Recyclable',
                    bodyColor: Color(0xFFE6C925),
                    lidColor: Color(0xFFF1D23D),
                    icon: Icons.recycling_rounded,
                  ),
                  _SortingBin(
                    label: 'À vérifier',
                    bodyColor: Color(0xFFE7843C),
                    lidColor: Color(0xFFFF9749),
                    questionMark: true,
                  ),
                  _SortingBin(
                    label: 'Résiduel',
                    bodyColor: Color(0xFF5D7169),
                    lidColor: Color(0xFF697E76),
                    icon: Icons.not_interested_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPattern extends StatelessWidget {
  const _HeroPattern();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ...List.generate(4, (index) {
          return Positioned(
            left: -20,
            top: 18.0 + (index * 24),
            child: Transform.rotate(
              angle: -0.5,
              child: Container(
                width: 52,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF69A57E).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          );
        }),
        Positioned(
          right: -18,
          top: 12,
          child: Container(
            width: 28,
            height: 112,
            decoration: BoxDecoration(
              color: const Color(0xFF5C8F6B).withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 5,
            color: Colors.white.withValues(alpha: 0.20),
          ),
        ),
      ],
    );
  }
}

class _SortingBin extends StatelessWidget {
  final String label;
  final Color bodyColor;
  final Color lidColor;
  final IconData? icon;
  final bool questionMark;

  const _SortingBin({
    required this.label,
    required this.bodyColor,
    required this.lidColor,
    this.icon,
    this.questionMark = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 114,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 70,
            height: 88,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 18,
                  child: Container(
                    width: 56,
                    height: 68,
                    decoration: BoxDecoration(
                      color: bodyColor,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(7),
                        bottomRight: Radius.circular(7),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 6,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: questionMark
                          ? const Text(
                              '?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : Icon(
                              icon,
                              color: Colors.white,
                              size: 31,
                            ),
                    ),
                  ),
                ),
                Positioned(
                  top: 13,
                  child: Container(
                    width: 66,
                    height: 11,
                    decoration: BoxDecoration(
                      color: lidColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Positioned(
                  top: 5,
                  child: Container(
                    width: 28,
                    height: 11,
                    decoration: BoxDecoration(
                      border: Border.all(color: lidColor, width: 4),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(5),
                        topRight: Radius.circular(5),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  bottom: 0,
                  child: Container(
                    width: 62,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF577464).withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF102217),
              fontSize: 11,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final bool locked;
  final ValueChanged<bool> onChanged;

  const _NotificationCard({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF07120B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    color: Color(0xFF1C3125),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _NotificationToggle(
            value: value,
            enabled: !locked,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _NotificationToggle extends StatelessWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _NotificationToggle({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final trackColor =
        value ? const Color(0xFF72EF9B) : const Color(0xFFDCE8DA);
    final knobColor = value ? const Color(0xFF007C43) : Colors.white;
    final alignment = value ? Alignment.centerRight : Alignment.centerLeft;

    return Semantics(
      button: true,
      toggled: value,
      child: GestureDetector(
        onTap: enabled ? () => onChanged(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 20,
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: alignment,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: knobColor,
                shape: BoxShape.circle,
                border: value
                    ? null
                    : Border.all(color: const Color(0xFFB8CAB8), width: 1.5),
              ),
              child: value
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _CriticalNote extends StatelessWidget {
  const _CriticalNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F8E6),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFBDECCB)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF007A3D),
              size: 18,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Note: Les alertes de service critiques ne peuvent pas être désactivées pour garantir la continuité de votre collecte.',
              style: TextStyle(
                fontSize: 13,
                height: 1.25,
                fontStyle: FontStyle.italic,
                color: Color(0xFF21382A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
