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

class _PasswordResetScreenState extends State<PasswordResetScreen>
    with SingleTickerProviderStateMixin {
  static final _emailPattern = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");

  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _otpCode = <String>['', '', '', '', '', ''];
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _passwordController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  bool _submitting = false;
  String? _error;
  String? _success;

  int _step = 0;

  late AnimationController _animController;
  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _checkScale = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _checkOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    for (final c in _otpControllers) {
      c.dispose();
    }
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });

    try {
      await _authService.requestPasswordReset(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _step = 1;
        _success = AppLocalizations.of(context).t('password_reset.otp_sent');
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

  Future<void> _verifyOtp() async {
    final code = _otpCode.join();
    if (code.length < 6) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _authService.verifyResetOtp(token: code);
      if (!mounted) return;
      _animController.forward();
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      setState(() {
        _step = 2;
        _animController.reset();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        for (int i = 0; i < 6; i++) {
          _otpCode[i] = '';
          _otpControllers[i].clear();
        }
        if (_otpFocusNodes.isNotEmpty) {
          _otpFocusNodes[0].requestFocus();
        }
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;
    final code = _otpCode.join();

    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });

    try {
      await _authService.resetPassword(
        token: code,
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
    if (value.isNotEmpty && index == 5) {
      _verifyOtp();
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
              const SizedBox(height: 32),
              const Center(
                child: AppLogo(
                  size: 112,
                  color: Color(0xFF2CCB6A),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'EcoSort',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A8A52),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _buildStepIndicator(),
              const SizedBox(height: 24),
              if (_step == 0) _buildEmailStep(),
              if (_step == 1) _buildOtpStep(),
              if (_step == 2) _buildPasswordStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final t = AppLocalizations.of(context).t;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepDot(0, t('password_reset.step.email')),
        _stepLine(0),
        _stepDot(1, t('password_reset.step.code')),
        _stepLine(1),
        _stepDot(2, t('password_reset.step.password')),
      ],
    );
  }

  Widget _stepDot(int index, String label) {
    final isActive = _step >= index;
    final isCurrent = _step == index;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isCurrent ? 36 : 30,
          height: isCurrent ? 36 : 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? const Color(0xFF34CC73) : const Color(0xFFD7E1D2),
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFF475048),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? const Color(0xFF0A8A52) : const Color(0xFF99A89A),
          ),
        ),
      ],
    );
  }

  Widget _stepLine(int index) {
    final active = _step > index;
    return Container(
      width: 48,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: active ? const Color(0xFF34CC73) : const Color(0xFFD7E1D2),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        _buildErrorBanner(),
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
                    AppLocalizations.of(context).t('password_reset.send_code'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    final t = AppLocalizations.of(context).t;
    return Column(
      children: [
        Text(
          t('password_reset.otp_sent'),
          style: const TextStyle(
              fontSize: 16, height: 1.5, color: Color(0xFF475048)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            if (_animController.isAnimating || _animController.value > 0) {
              return Transform.scale(
                scale: 0.5 + _checkScale.value * 0.5,
                child: Opacity(
                  opacity: _checkOpacity.value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF34CC73).withValues(
                          alpha: 0.1 + _checkOpacity.value * 0.9),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: const Color(0xFF34CC73),
                      size: 60 + _checkScale.value * 20,
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        if (!_animController.isAnimating && _animController.value == 0) ...[
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                      borderSide:
                          const BorderSide(color: Color(0xFFD7E1D2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFF0A8A52), width: 2),
                    ),
                  ),
                  onChanged: (value) => _onOtpChanged(value, index),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          _buildErrorBanner(),
          SizedBox(
            height: 64,
            child: ElevatedButton(
              onPressed: _submitting ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34CC73),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: _submitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      t('password_reset.verify_code'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _submitting ? null : _requestCode,
            child: Text(
              t('password_reset.resend_code'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A8A52),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordStep() {
    final t = AppLocalizations.of(context).t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              const Icon(Icons.check_circle,
                  color: Color(0xFF34CC73), size: 64),
              const SizedBox(height: 12),
              Text(
                t('password_reset.code_verified'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF17211C),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          t('password_reset.set_new_password'),
          style: const TextStyle(
              fontSize: 16, height: 1.5, color: Color(0xFF475048)),
        ),
        const SizedBox(height: 24),
        Form(
          key: _resetFormKey,
          child: TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: t('password_reset.new_password_label'),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFD7E1D2)),
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 6) {
                return t('password_reset.validation.password_min');
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 24),
        _buildErrorBanner(),
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
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    t('password_reset.reset_button'),
                    style: const TextStyle(
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
                Navigator.of(context).pop({'email': _emailController.text.trim()});
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF34CC73)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(
                t('password_reset.back_to_login'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF34CC73),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorBanner() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1ED),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          _error!,
          style: const TextStyle(
              color: Color(0xFFB24E31), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
