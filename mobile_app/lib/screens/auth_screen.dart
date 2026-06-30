import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/google_sign_in_button.dart';

import '../models/auth_response.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/google_web_client_id.dart';
import '../services/push_service.dart';
import '../services/user_service.dart';
import '../l10n.dart';
import '../widgets/app_logo.dart';
import 'password_reset_screen.dart';
import 'verify_email_screen.dart';

enum AuthMode { register, login }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.redirectTo,
    this.initialMode = AuthMode.register,
  });

  final Widget redirectTo;
  final AuthMode initialMode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _authService = AuthService();
  final _pushService = PushService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaCodeController = TextEditingController();
  late final GoogleSignIn _googleSignIn;
  String _webGoogleClientId = '';
  StreamSubscription<GoogleSignInAccount?>? _googleSignInSubscription;
  bool _googleSignInProcessing = false;

  String? _mfaToken;
  String? _mfaMethod;
  String? _pendingGoogleIdToken;
  String? _pendingGoogleDisplayName;

  late AuthMode _mode;
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;

  bool get _registerMode => _mode == AuthMode.register;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _webGoogleClientId = kIsWeb ? getGoogleWebClientId() : '';
    _googleSignIn = GoogleSignIn(
      scopes: ['email'],
      clientId: _webGoogleClientId.isNotEmpty ? _webGoogleClientId : null,
    );
    _googleSignInSubscription = _googleSignIn.onCurrentUserChanged.listen(
      (GoogleSignInAccount? account) {
        if (account != null) {
          _handleGoogleSignInAccount(account);
        }
      },
    );
  }

  @override
  void dispose() {
    _googleSignInSubscription?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mfaCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignInAccount(
      GoogleSignInAccount googleUser) async {
    if (_googleSignInProcessing) {
      return;
    }
    _googleSignInProcessing = true;
    setState(() {
      _submitting = true;
      _error = null;
      _pendingGoogleIdToken = null;
      _pendingGoogleDisplayName = null;
    });

    try {
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const ApiException(
          message: 'Impossible de récupérer le jeton Google.',
          statusCode: 400,
        );
      }

      final result = await _authService.googleLogin(
        idToken: idToken,
        displayName: googleUser.displayName,
      );

      if (!mounted) {
        return;
      }

      if (result.mfaRequired) {
        _pendingGoogleIdToken = idToken;
        _pendingGoogleDisplayName = googleUser.displayName;
        await _handleMfaChallenge(result, isGoogle: true);
        return;
      }

      await _goToNextScreen(result.authResponse!.user);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _getAuthErrorMessage(error);
      });
    } finally {
      _googleSignInProcessing = false;
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _pendingGoogleIdToken = null;
      _pendingGoogleDisplayName = null;
    });

    try {
      if (_registerMode) {
        final response = await _authService.register(
          email: _emailController.text.trim(),
          fullName: _nameController.text.trim(),
          password: _passwordController.text,
        );

        if (!mounted) {
          return;
        }

        final messenger = ScaffoldMessenger.of(context);
        await _authService.logout();
        setState(() {
          _mode = AuthMode.login;
          _error = null;
        });

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              response.verificationToken != null &&
                      response.verificationToken!.isNotEmpty
                  ? 'Compte créé. Votre token de vérification est : ${response.verificationToken}'
                  : 'Compte créé avec succès. Connectez-vous maintenant.',
            ),
          ),
        );
        return;
      }

      final result = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      if (result.mfaRequired) {
        await _handleMfaChallenge(result, isGoogle: false);
        return;
      }

      await _goToNextScreen(result.authResponse!.user);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _getAuthErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _goToNextScreen(UserModel user) async {
    await UserService.setCurrentUser(user);

    try {
      await _pushService.registerTokenWithServer();
    } catch (_) {
      // Push registration should not block navigation.
    }

    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => widget.redirectTo),
      (route) => false,
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text('Bienvenue ${user.fullName}.'),
      ),
    );
  }

  String _getAuthErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('origin is not allowed') ||
        message.contains('given origin is not allowed') ||
        message.contains('origin is not authorized') ||
        message.contains('google sign-in') ||
        message.contains('google.accounts.id')) {
      return AppLocalizations.of(context).t('auth.google_origin_error');
    }
    if (message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('network is unreachable') ||
        message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('network')) {
      return AppLocalizations.of(context).t('auth.network_error');
    }
    return AppLocalizations.of(context).t('auth.connection_error');
  }

  Future<void> _handleMfaChallenge(AuthResult result,
      {required bool isGoogle}) async {
    _mfaToken = result.mfaToken;
    _mfaMethod = result.mfaMethod;
    _mfaCodeController.clear();

    final enteredCode = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).t('mfa.title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(result.mfaCode != null
                  ? AppLocalizations.of(context)
                      .t('mfa.code_received')
                      .replaceAll('{code}', result.mfaCode!)
                  : AppLocalizations.of(context)
                      .t('mfa.enter_code_via')
                      .replaceAll('{method}', _mfaMethod ?? 'email')),
              const SizedBox(height: 16),
              TextField(
                controller: _mfaCodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Code MFA',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context).t('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final value = _mfaCodeController.text.trim();
                if (value.isNotEmpty) {
                  Navigator.of(context).pop(value);
                }
              },
              child: Text(AppLocalizations.of(context).t('common.ok')),
            ),
          ],
        );
      },
    );

    if (enteredCode == null || enteredCode.isEmpty) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      AuthResult challengeResult;
      if (isGoogle) {
        challengeResult = await _authService.googleLogin(
          idToken: _pendingGoogleIdToken!,
          displayName: _pendingGoogleDisplayName,
          mfaToken: _mfaToken,
          mfaCode: enteredCode,
        );
      } else {
        challengeResult = await _authService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          mfaToken: _mfaToken,
          mfaCode: enteredCode,
        );
      }

      if (!mounted) {
        return;
      }

      if (challengeResult.mfaRequired) {
        setState(() {
          _error = 'Le code MFA est invalide ou a expiré.';
        });
        return;
      }

      await _goToNextScreen(challengeResult.authResponse!.user);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _getAuthErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _submitting = true;
      _error = null;
      _pendingGoogleIdToken = null;
      _pendingGoogleDisplayName = null;
    });

    if (kIsWeb && _webGoogleClientId.isEmpty) {
      setState(() {
        _submitting = false;
        _error =
            'Google web client ID est manquant. Vérifiez mobile_app/web/index.html et .env.';
      });
      return;
    }

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const ApiException(
          message: 'Impossible de récupérer le jeton Google.',
          statusCode: 400,
        );
      }

      final result = await _authService.googleLogin(
        idToken: idToken,
        displayName: googleUser.displayName,
      );

      if (!mounted) {
        return;
      }

      if (result.mfaRequired) {
        _pendingGoogleIdToken = idToken;
        _pendingGoogleDisplayName = googleUser.displayName;
        await _handleMfaChallenge(result, isGoogle: true);
        return;
      }

      await _goToNextScreen(result.authResponse!.user);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _getAuthErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 18, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF0A8A52),
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'EcoSort',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A8A52),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              const Center(
                child: AppLogo(
                  size: 112,
                  color: Color(0xFF2CCB6A),
                ),
              ),
              const SizedBox(height: 38),
              Center(
                child: Text(
                  _registerMode ? 'Créer un compte' : 'Se connecter',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF131B17),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  _registerMode
                      ? "Rejoignez l'aventure écologique et\ntransformez votre gestion des déchets en\naction positive."
                      : "Retrouvez votre historique, vos analyses\net votre profil en quelques secondes.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: Color(0xFF49574E),
                  ),
                ),
              ),
              const SizedBox(height: 38),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_registerMode) ...[
                      _AuthFieldLabel(AppLocalizations.of(context)
                          .t('auth.full_name_label')),
                      const SizedBox(height: 14),
                      _AuthTextField(
                        controller: _nameController,
                        hintText: AppLocalizations.of(context)
                            .t('auth.full_name_hint'),
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (value) {
                          if (value == null || value.trim().length < 2) {
                            return 'Veuillez entrer votre nom complet.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                    ],
                    _AuthFieldLabel(
                        AppLocalizations.of(context).t('auth.email_label')),
                    const SizedBox(height: 14),
                    _AuthTextField(
                      controller: _emailController,
                      hintText:
                          AppLocalizations.of(context).t('auth.email_hint'),
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppLocalizations.of(context)
                              .t('auth.validation.enter_email');
                        }
                        if (!value.contains('@')) {
                          return AppLocalizations.of(context)
                              .t('auth.validation.invalid_email');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    _AuthFieldLabel(
                        AppLocalizations.of(context).t('auth.password_label')),
                    const SizedBox(height: 14),
                    _AuthTextField(
                      controller: _passwordController,
                      hintText:
                          AppLocalizations.of(context).t('auth.password_hint'),
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      suffix: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: const Color(0xFF78867D),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return AppLocalizations.of(context)
                              .t('auth.validation.password_min');
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1ED),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFB24E31),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 68,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34CC73),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _registerMode ? "S'inscrire" : 'Se connecter'),
                      ),
                    ),
                    if (!_registerMode) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PasswordResetScreen(),
                              ),
                            );
                          },
                          child: const Text('Mot de passe oublié ?'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const VerifyEmailScreen(),
                              ),
                            );
                          },
                          child: const Text('Vérifier mon email'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 34),
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Color(0xFFBFCABF))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: Text(
                            'ou',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF2C312D),
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Color(0xFFBFCABF))),
                      ],
                    ),
                    const SizedBox(height: 34),
                    SizedBox(
                      width: double.infinity,
                      height: 74,
                      child: buildGoogleSignInButton(
                        _submitting ? () {} : _signInWithGoogle,
                      ),
                    ),
                    const SizedBox(height: 34),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _registerMode
                                ? AppLocalizations.of(context)
                                    .t('auth.already_have_account')
                                : AppLocalizations.of(context)
                                    .t('auth.no_account'),
                            style: const TextStyle(
                              fontSize: 17,
                              color: Color(0xFF303732),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _mode = _registerMode
                                    ? AuthMode.login
                                    : AuthMode.register;
                                _error = null;
                              });
                            },
                            child: Text(
                              _registerMode
                                  ? AppLocalizations.of(context).t('auth.login')
                                  : AppLocalizations.of(context)
                                      .t('auth.register'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0A8A52),
                              ),
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
    );
  }
}

class _AuthFieldLabel extends StatelessWidget {
  const _AuthFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: Color(0xFF2C342E),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(
        fontSize: 17,
        color: Color(0xFF263029),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 17,
          color: Color(0xFF79877E),
        ),
        prefixIcon: Icon(
          prefixIcon,
          color: const Color(0xFF78867D),
          size: 30,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 22,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD7E1D2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD7E1D2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF0A8A52), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFC45B4F), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFC45B4F), width: 1.5),
        ),
      ),
    );
  }
}
