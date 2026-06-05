import 'package:flutter/material.dart';

import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/app_logo.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _cameraEnabled = true;
  bool _locationEnabled = false;
  bool _biometricEnabled = true;
  bool _autoLockEnabled = false;

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
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF7FBF3),
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFFE3EBDD),
                          ),
                        ),
                      ),
                      child: Row(
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
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Confidentialité',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: darkGreen,
                              ),
                            ),
                          ),
                          const AppLogo(size: 30),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(34, 34, 34, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('DONNÉES PERSONNELLES'),
                          const SizedBox(height: 18),
                          Container(
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
                            child: const Column(
                              children: [
                                _ActionRow(
                                  icon: Icons.manage_search_rounded,
                                  label: 'Consulter mes données',
                                ),
                                Divider(height: 1, color: Color(0xFFE1E9E0)),
                                _ActionRow(
                                  icon: Icons.download_rounded,
                                  label: 'Exporter mes données',
                                ),
                                Divider(height: 1, color: Color(0xFFE1E9E0)),
                                _ActionRow(
                                  icon: Icons.delete_outline_rounded,
                                  label: 'Supprimer mon compte',
                                  destructive: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          const _SectionTitle('PERMISSIONS'),
                          const SizedBox(height: 18),
                          _ToggleCard(
                            children: [
                              _ToggleRow(
                                icon: Icons.photo_camera_outlined,
                                title: 'Appareil photo',
                                subtitle: 'Requis pour le scan de déchets',
                                value: _cameraEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _cameraEnabled = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 18),
                              _ToggleRow(
                                icon: Icons.location_on_outlined,
                                title: 'Localisation',
                                subtitle: 'Trouver les points de collecte',
                                value: _locationEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _locationEnabled = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          const _SectionTitle('SÉCURITÉ'),
                          const SizedBox(height: 18),
                          _ToggleCard(
                            children: [
                              _ToggleRow(
                                icon: Icons.fingerprint_rounded,
                                title: 'Authentification biométrique',
                                subtitle: "Sécuriser l'accès à l'app",
                                value: _biometricEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _biometricEnabled = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 18),
                              _ToggleRow(
                                icon: Icons.lock_outline_rounded,
                                title: 'Verrouillage automatique',
                                subtitle: "Après 5 minutes d'inactivité",
                                value: _autoLockEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _autoLockEnabled = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 56),
                          const Center(
                            child: Text(
                              'Lire notre politique de confidentialité\ncomplète',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                height: 1.55,
                                fontWeight: FontWeight.w600,
                                color: darkGreen,
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          const Center(
                            child: Text(
                              'Version 2.4.0 — EcoSort France',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF364239),
                              ),
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

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
        color: Color(0xFF4B564F),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;

  const _ActionRow({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? const Color(0xFFD21313) : const Color(0xFF415147);
    final arrowColor =
        destructive ? const Color(0xFFE28D8D) : const Color(0xFFC5D1C6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(width: 22),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 34,
            color: arrowColor,
          ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final List<Widget> children;

  const _ToggleCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
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
      child: Column(children: children),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 34, color: const Color(0xFF415147)),
        const SizedBox(width: 22),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF17211C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF415147),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: const Color(0xFF08793E),
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFFDCE7DA),
        ),
      ],
    );
  }
}
