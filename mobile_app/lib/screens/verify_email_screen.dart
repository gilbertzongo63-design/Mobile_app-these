import 'package:flutter/material.dart';

import '../app_routes.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../l10n.dart';
import '../widgets/app_logo.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _otpCode = <String>['', '', '', '', '', ''];
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  bool _submitting = false;
  bool _codeSent = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args['email'] != null) {
        _emailController.text = args['email'] as String;
        setState(() {
          _codeSent = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    for (final c in _otpControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _authService.requestEmailVerification(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _verifyEmail() async {
    final code = _otpCode.join();
    if (code.length < 6) return;

    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });

    try {
      final response = await _authService.verifyEmail(
        email: _emailController.text.trim(),
        token: code,
      );
      if (!mounted) return;
      await UserService.setCurrentUser(response.user);
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _onOtpChanged(String value, int index) {
    if (value.length > 1) {
      value = value.substring(value.length - 1);
    }
    setState(() {
      _otpCode[index] = value;
    });
    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (index == 5 && value.isNotEmpty) {
      _otpFocusNodes[index].unfocus();
      _verifyEmail();
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppLogo(size: 96, color: Color(0xFF2CCB6A)),
              const SizedBox(height: 20),
              if (!_codeSent)
                Text(
                  AppLocalizations.of(context).t('verify_email.instructions'),
                  style: const TextStyle(
                      fontSize: 16, height: 1.5, color: Color(0xFF475048)),
                ),
              const SizedBox(height: 24),
              if (!_codeSent) ...[
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
                        borderSide:
                            const BorderSide(color: Color(0xFFD7E1D2)),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppLocalizations.of(context).t('verify_email.validation.enter_email');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _requestCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34CC73),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    child: _submitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            AppLocalizations.of(context).t('verify_email.send_code'),
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
              if (_codeSent) ...[
                Form(
                  key: _otpFormKey,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: 48,
                            height: 56,
                            child: TextField(
                              controller: _otpControllers[index],
                              focusNode: _otpFocusNodes[index],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF17211C),
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFD7E1D2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF0A8A52), width: 2),
                                ),
                              ),
                              onChanged: (value) =>
                                  _onOtpChanged(value, index),
                            ),
                          );
                        }),
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
                        height: 56,
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
                              : Text(
                                  AppLocalizations.of(context).t('verify_email.verify_button'),
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _submitting ? null : _requestCode,
                        child: Text(
                          AppLocalizations.of(context).t('verify_email.resend_code'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A8A52),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
