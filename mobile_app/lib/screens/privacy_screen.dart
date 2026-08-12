import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import '../services/user_service.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../app_routes.dart';

const _privacyPolicyUrl = 'http://127.0.0.1:8000/privacy';

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
  final _userService = UserService();

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).t('privacy.delete_account_title')),
          content: Text(
            AppLocalizations.of(context).t('privacy.delete_account_confirm'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context).t('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(AppLocalizations.of(context).t('common.delete')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _userService.deleteAccount();
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.auth,
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

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
                                Navigator.of(context)
                                    .pushReplacementNamed(AppRoutes.settings),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: darkGreen,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context).t('privacy.title'),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: darkGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(34, 34, 34, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(AppLocalizations.of(context)
                              .t('privacy.section.personal_data')),
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
                            child: Column(
                              children: [
                                _ActionRow(
                                  icon: Icons.manage_search_rounded,
                                  label: AppLocalizations.of(context)
                                      .t('privacy.actions.view_data'),
                                  onTap: () {
                                    Navigator.of(context)
                                        .pushReplacementNamed(
                                            AppRoutes.history);
                                  },
                                ),
                                const Divider(
                                    height: 1, color: Color(0xFFE1E9E0)),
                                _ActionRow(
                                  icon: Icons.download_rounded,
                                  label: AppLocalizations.of(context)
                                      .t('privacy.actions.export_data'),
                                  onTap: () {
                                    Navigator.of(context)
                                        .pushReplacementNamed(
                                            AppRoutes.history);
                                  },
                                ),
                                const Divider(
                                    height: 1, color: Color(0xFFE1E9E0)),
                                _ActionRow(
                                  icon: Icons.delete_outline_rounded,
                                  label: AppLocalizations.of(context)
                                      .t('privacy.actions.delete_account'),
                                  destructive: true,
                                  onTap: _handleDeleteAccount,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          _SectionTitle(AppLocalizations.of(context)
                              .t('privacy.section.permissions')),
                          const SizedBox(height: 18),
                          _ToggleCard(
                            children: [
                              _ToggleRow(
                                icon: Icons.photo_camera_outlined,
                                title: AppLocalizations.of(context)
                                    .t('privacy.camera.title'),
                                subtitle: AppLocalizations.of(context)
                                    .t('privacy.camera.subtitle'),
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
                                title: AppLocalizations.of(context)
                                    .t('privacy.location.title'),
                                subtitle: AppLocalizations.of(context)
                                    .t('privacy.location.subtitle'),
                                value: _locationEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _locationEnabled = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          _SectionTitle(AppLocalizations.of(context)
                              .t('privacy.section.security')),
                          const SizedBox(height: 18),
                          _ToggleCard(
                            children: [
                              _ToggleRow(
                                icon: Icons.fingerprint_rounded,
                                title: AppLocalizations.of(context)
                                    .t('privacy.biometrics.title'),
                                subtitle: AppLocalizations.of(context)
                                    .t('privacy.biometrics.subtitle'),
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
                                title: AppLocalizations.of(context)
                                    .t('privacy.auto_lock.title'),
                                subtitle: AppLocalizations.of(context)
                                    .t('privacy.auto_lock.subtitle'),
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
                          Center(
                            child: GestureDetector(
                              onTap: () async {
                                final uri = Uri.parse(_privacyPolicyUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri,
                                      mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Text(
                                AppLocalizations.of(context)
                                    .t('privacy.read_policy'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  height: 1.55,
                                  fontWeight: FontWeight.w600,
                                  color: darkGreen,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          Center(
                            child: Text(
                              AppLocalizations.of(context).t('privacy.version'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
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
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    this.destructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? const Color(0xFFD21313) : const Color(0xFF415147);
    final arrowColor =
        destructive ? const Color(0xFFE28D8D) : const Color(0xFFC5D1C6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
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
        ),
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
