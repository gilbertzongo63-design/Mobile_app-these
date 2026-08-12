import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../services/google_auth_redirect.dart';
import '../services/push_service.dart';
import '../l10n.dart';
import '../services/token_store.dart';
import '../services/user_service.dart';
import '../widgets/app_logo.dart';
import '../app_routes.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final _tokenStore = TokenStore();
  final _userService = UserService();
  final _pushService = PushService();

  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _resolveEntry();
  }

  Future<void> _resolveEntry() async {
    print('[GATE_DEBUG] _resolveEntry starting...');
    final googleIdToken = extractGoogleIdTokenFromUrl();
    print('[GATE_DEBUG] googleIdToken extracted: ${googleIdToken != null}');

    if (googleIdToken != null) {
      _goToAuth(googleIdToken: googleIdToken);
      return;
    }

    await UserService.restoreCurrentUser();
    try {
      final token = await _tokenStore.readToken();
      _RecoveredImage? recovered;
      if (!kIsWeb) {
        final picker = ImagePicker();
        try {
          final lostData = await picker.retrieveLostData();
          recovered = await _recoverLostImage(lostData);
        } catch (_) {
          recovered = null;
        }
      }

      if (!mounted) {
        return;
      }

      if (token == null || token.isEmpty) {
        _goToAuth();
        return;
      }

      await _userService.fetchCurrentUser();
      try {
        await _pushService.registerTokenWithServer();
      } catch (_) {
        // Ignore push registration failures for app startup.
      }
      if (!mounted) {
        return;
      }

      if (recovered != null) {
        _goToScan(recovered.path, recovered.name);
        return;
      }

      _goToHome();
    } on ApiException {
      await _tokenStore.clearToken();
      if (!mounted) {
        return;
      }
      _goToAuth();
    } catch (_) {
      await _tokenStore.clearToken();
      if (!mounted) {
        return;
      }
      _goToAuth();
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  Future<_RecoveredImage?> _recoverLostImage(LostDataResponse response) async {
    if (response.isEmpty) {
      return null;
    }

    final file = response.file;
    if (file == null) {
      return null;
    }

    final name = file.name.isNotEmpty ? file.name : 'capture.jpg';
    return _RecoveredImage(path: file.path, name: name);
  }

  void _goToAuth({String? googleIdToken}) {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.auth,
      arguments: {'googleIdToken': googleIdToken},
    );
  }

  void _goToHome() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  void _goToScan(String path, String name) {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.scan,
      arguments: <String, dynamic>{
        'imagePath': path,
        'imageName': name,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F0),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 86, color: Color(0xFF2CCB6A)),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context).t('app.name'),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A8A52),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _checking
                  ? AppLocalizations.of(context).t('auth.checking_session')
                  : AppLocalizations.of(context).t('auth.redirecting'),
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF516057),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveredImage {
  const _RecoveredImage({
    required this.path,
    required this.name,
  });

  final String path;
  final String name;
}
