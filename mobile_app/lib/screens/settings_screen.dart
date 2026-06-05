import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/notification_preferences_service.dart';
import '../services/user_service.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/app_logo.dart';
import 'auth_screen.dart';
import 'help_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'language_screen.dart';
import 'notifications_screen.dart';
import 'privacy_screen.dart';
import 'recycling_tips_screen.dart';
import 'scan_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _notificationPreferencesService = NotificationPreferencesService();
  final _userService = UserService();
  final _authService = AuthService();
  final _imagePicker = ImagePicker();

  bool _notificationsEnabled = false;
  bool _profileLoading = true;
  bool _profileSaving = false;
  bool _redirectingToAuth = false;
  UserModel? _currentUser;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
    _loadProfile();
  }

  Future<void> _loadNotificationPreferences() async {
    final preferences = await _notificationPreferencesService.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _notificationsEnabled = preferences.hasOptionalNotificationsEnabled;
    });
  }

  Future<void> _loadProfile() async {
    setState(() {
      _profileLoading = true;
      _profileError = null;
    });

    try {
      final user = await _userService.fetchCurrentUser();
      if (!mounted) {
        return;
      }
      setState(() {
        _currentUser = user;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.statusCode == 401) {
        _redirectToAuth();
        return;
      }
      setState(() {
        _profileError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profileError = 'Impossible de charger le profil.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _profileLoading = false;
        });
      }
    }
  }

  void _redirectToAuth() {
    if (_redirectingToAuth || !mounted) {
      return;
    }
    _redirectingToAuth = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const AuthScreen(
            redirectTo: SettingsScreen(),
            initialMode: AuthMode.login,
          ),
        ),
      );
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const AuthScreen(
          redirectTo: HomeScreen(),
          initialMode: AuthMode.login,
        ),
      ),
      (route) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Déconnexion effectuée.')),
    );
  }

  Future<void> _editProfile() async {
    final user = _currentUser;
    if (user == null || _profileSaving) {
      return;
    }

    final newName = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _EditProfileScreen(initialName: user.fullName),
      ),
    );

    if (!mounted) {
      return;
    }

    final trimmedName = newName?.trim() ?? '';
    if (trimmedName.isEmpty || trimmedName == user.fullName) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _profileSaving = true;
    });

    try {
      final updatedUser = await _userService.updateProfile(
        fullName: trimmedName,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _currentUser = updatedUser;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Profil mis à jour.')),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible de modifier le profil.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _profileSaving = false;
        });
      }
    }
  }

  Future<void> _changeProfilePhoto() async {
    if (_currentUser == null || _profileSaving) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE7DD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Photo de profil',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17211C),
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera_outlined,
                    color: Color(0xFF0A8A52),
                  ),
                  title: const Text('Prendre une photo'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFF0A8A52),
                  ),
                  title: const Text('Choisir depuis la galerie'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final pickedImage = await _imagePicker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1200,
    );
    if (pickedImage == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _profileSaving = true;
    });

    try {
      final bytes = await pickedImage.readAsBytes();
      final updatedUser = await _userService.uploadProfilePhoto(
        bytes: bytes,
        filename: pickedImage.name.isEmpty ? 'profile.jpg' : pickedImage.name,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _currentUser = updatedUser;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Photo de profil mise à jour.')),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible d’ajouter la photo.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _profileSaving = false;
        });
      }
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
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadProfile();
                  await _loadNotificationPreferences();
                },
                color: darkGreen,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(32, 18, 32, 18),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF7FBF3),
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFFE3EBDD),
                            ),
                          ),
                        ),
                        child: const Row(
                          children: [
                            AppBrand(),
                            Spacer(),
                            Icon(
                              Icons.notifications_none_rounded,
                              size: 32,
                              color: Color(0xFF17211C),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ProfileCard(
                              loading: _profileLoading,
                              saving: _profileSaving,
                              user: _currentUser,
                              error: _profileError,
                              onEditProfile: _editProfile,
                              onChangePhoto: _changeProfilePhoto,
                            ),
                            const SizedBox(height: 34),
                            const Text(
                              'PRÉFÉRENCES',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Color(0xFF6A756F),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const _SettingsRow(
                              icon: Icons.tips_and_updates_outlined,
                              iconBg: Color(0xFFDDF9E8),
                              iconColor: darkGreen,
                              title: 'Conseils de tri',
                              destination: RecyclingTipsScreen(),
                            ),
                            const SizedBox(height: 20),
                            const _SettingsRow(
                              icon: Icons.language_rounded,
                              iconBg: Color(0xFFFDE0D6),
                              iconColor: Color(0xFFB35E32),
                              title: 'Langue',
                              subtitle: 'Français',
                              destination: LanguageScreen(),
                            ),
                            const SizedBox(height: 20),
                            _SwitchSettingsRow(
                              value: _notificationsEnabled,
                              destination: const NotificationsScreen(),
                              onChanged: (value) async {
                                setState(() {
                                  _notificationsEnabled = value;
                                });
                                if (value) {
                                  if (!mounted) {
                                    return;
                                  }
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const NotificationsScreen(),
                                    ),
                                  );
                                } else {
                                  await _notificationPreferencesService
                                      .disableOptionalNotifications();
                                }
                              },
                            ),
                            const SizedBox(height: 34),
                            const Text(
                              'SÉCURITÉ ET AIDE',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Color(0xFF6A756F),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const _SettingsRow(
                              icon: Icons.lock_outline_rounded,
                              iconBg: Color(0xFFE4EBDD),
                              iconColor: Color(0xFF1D201E),
                              title: 'Confidentialité',
                              destination: PrivacyScreen(),
                            ),
                            const SizedBox(height: 20),
                            const _SettingsRow(
                              icon: Icons.help_outline_rounded,
                              iconBg: Color(0xFF67F69A),
                              iconColor: Color(0xFF094E32),
                              title: 'Aide',
                              destination: HelpScreen(),
                            ),
                            const SizedBox(height: 36),
                            GestureDetector(
                              onTap: _logout,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 26),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDD3D1),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.logout_rounded,
                                      color: Color(0xFFAA121E),
                                      size: 34,
                                    ),
                                    SizedBox(width: 16),
                                    Text(
                                      'Déconnexion',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFAA121E),
                                      ),
                                    ),
                                  ],
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
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileScreen extends StatefulWidget {
  const _EditProfileScreen({
    required this.initialName,
  });

  final String initialName;

  @override
  State<_EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF5F9F0);
    const darkGreen = Color(0xFF0A8A52);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        foregroundColor: darkGreen,
        title: const Text(
          'Modifier le profil',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: darkGreen,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nom et prénom',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF17211C),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  hintText: 'Ex: Jean Dupont',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: Color(0xFFDDE8DD)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: Color(0xFFDDE8DD)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(
                      color: darkGreen,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF33CB72),
                    foregroundColor: const Color(0xFF112D1D),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Enregistrer',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.loading,
    required this.saving,
    required this.user,
    required this.error,
    required this.onEditProfile,
    required this.onChangePhoto,
  });

  final bool loading;
  final bool saving;
  final UserModel? user;
  final String? error;
  final VoidCallback onEditProfile;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: loading || user == null ? null : onChangePhoto,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 154,
                  height: 154,
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF23C769),
                  ),
                  child: ClipOval(
                    child: _ProfileAvatar(user: user),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: 6,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A8A52),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      user == null
                          ? Icons.person_rounded
                          : Icons.photo_camera_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          if (loading) ...[
            const CircularProgressIndicator(strokeWidth: 2.4),
            const SizedBox(height: 18),
            const Text(
              'Chargement du profil...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF49574E),
              ),
            ),
          ] else if (user != null) ...[
            Text(
              user!.fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF17211C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user!.email,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                color: Color(0xFF49574E),
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: saving ? null : onEditProfile,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0A8A52),
                side: const BorderSide(color: Color(0xFFBEE7CB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_outlined, size: 20),
              label: Text(saving ? 'Mise à jour...' : 'Modifier le profil'),
            ),
          ] else ...[
            const Text(
              'Profil indisponible',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF17211C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? 'Impossible de charger les informations du profil.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                height: 1.45,
                color: Color(0xFF49574E),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.user,
  });

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final profileImageUrl = user?.profileImageUrl ?? '';
    if (profileImageUrl.isNotEmpty) {
      return Image.network(
        profileImageUrl,
        width: 142,
        height: 142,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _FallbackProfileAvatar(),
      );
    }
    return const _FallbackProfileAvatar();
  }
}

class _FallbackProfileAvatar extends StatelessWidget {
  const _FallbackProfileAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF7BAA44),
            Color(0xFF2E7A3A),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 88,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.destination,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? destination;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: destination == null
          ? null
          : () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => destination!),
              );
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(26, 26, 24, 26),
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
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF17211C),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF39473E),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 34,
              color: Color(0xFFC3D1C4),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchSettingsRow extends StatelessWidget {
  const _SwitchSettingsRow({
    required this.value,
    required this.onChanged,
    this.destination,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? destination;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: destination == null
          ? null
          : () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => destination!),
              );
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(26, 26, 24, 26),
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
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF71F59D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF0A8A52),
                size: 34,
              ),
            ),
            const SizedBox(width: 24),
            const Expanded(
              child: Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF17211C),
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF08793E),
              inactiveTrackColor: const Color(0xFFE0E8E0),
              inactiveThumbColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
