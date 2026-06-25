import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../l10n.dart';
import '../widgets/app_logo.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _authService = AuthService();
  final _tokenController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _submitting = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _verifyEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });

    try {
      await _authService.verifyEmail(token: _tokenController.text.trim());
      if (!mounted) return;
      setState(() {
        _success = AppLocalizations.of(context).t('verify_email.success');
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
        title: Text(AppLocalizations.of(context).t('verify_email.title')),
        backgroundColor: const Color(0xFF0A8A52),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppLogo(size: 96, color: Color(0xFF2CCB6A)),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context).t('verify_email.instructions'),
                style: const TextStyle(
                    fontSize: 16, height: 1.5, color: Color(0xFF475048)),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _tokenController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)
                            .t('verify_email.token_label'),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide:
                              const BorderSide(color: Color(0xFFD7E1D2)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppLocalizations.of(context)
                              .t('verify_email.validation.enter_token');
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
                        onPressed: _submitting ? null : _verifyEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34CC73),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        child: _submitting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Vérifier mon email',
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w700),
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
    );
  }
}
