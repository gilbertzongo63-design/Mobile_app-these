import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../l10n.dart';
import '../widgets/app_logo.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  static final _emailPattern = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");

  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  final _formKey = GlobalKey<FormState>();

  bool _submitting = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    if (!_emailFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });

    try {
      final token = await _authService.requestPasswordReset(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _success =
            AppLocalizations.of(context).t('password_reset.token_generated');
        _tokenController.text = token;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });

    try {
      await _authService.resetPassword(
        token: _tokenController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _success = AppLocalizations.of(context).t('password_reset.success');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
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
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('password_reset.title')),
        backgroundColor: const Color(0xFF0A8A52),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppLogo(size: 96, color: Color(0xFF2CCB6A)),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context).t('password_reset.instructions'),
                style: const TextStyle(
                    fontSize: 16, height: 1.5, color: Color(0xFF475048)),
              ),
              const SizedBox(height: 24),
              Form(
                key: _emailFormKey,
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)
                        .t('password_reset.email_label'),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFFD7E1D2)),
                    ),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) {
                      return AppLocalizations.of(context)
                          .t('password_reset.validation.enter_email');
                    }
                    if (!_emailPattern.hasMatch(email)) {
                      return AppLocalizations.of(context)
                          .t('password_reset.validation.invalid_email');
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 64,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _requestReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34CC73),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _submitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Demander un token',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 28),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _tokenController,
                      decoration: InputDecoration(
                        labelText: 'Token de réinitialisation',
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: _tokenController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: _copyTokenToClipboard,
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide:
                              const BorderSide(color: Color(0xFFD7E1D2)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez entrer le token de réinitialisation.';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide:
                              const BorderSide(color: Color(0xFFD7E1D2)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Le mot de passe doit contenir au moins 6 caractères.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1ED),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: Color(0xFFB24E31),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (_success != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9F8EA),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          _success!,
                          style: const TextStyle(
                              color: Color(0xFF2D6A3F),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    SizedBox(
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34CC73),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        child: _submitting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Réinitialiser le mot de passe',
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                    if (_success != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF34CC73)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                          ),
                          child: const Text(
                            'Retour à la connexion',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF34CC73),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyTokenToClipboard() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              AppLocalizations.of(context).t('password_reset.token_copied'))),
    );
  }
}
