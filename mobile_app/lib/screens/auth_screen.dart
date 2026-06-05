import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/app_logo.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late AuthMode _mode;
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;

  bool get _registerMode => _mode == AuthMode.register;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_registerMode) {
        await _authService.register(
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
          const SnackBar(
            content: Text(
              'Compte créé avec succès. Connectez-vous maintenant.',
            ),
          ),
        );
        return;
      }

      final response = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      _goToNextScreen(response.user);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error =
            "Connexion impossible au serveur. Sur téléphone, utilisez l'IP locale du PC pour l'API.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _goToNextScreen(UserModel user) {
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

  void _showGooglePlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connexion Google bientôt disponible.'),
      ),
    );
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
                      const _AuthFieldLabel('Nom et prénom'),
                      const SizedBox(height: 14),
                      _AuthTextField(
                        controller: _nameController,
                        hintText: 'Ex: Jean Dupont',
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
                    const _AuthFieldLabel('Adresse email'),
                    const SizedBox(height: 14),
                    _AuthTextField(
                      controller: _emailController,
                      hintText: 'jean.dupont@email.com',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez entrer votre adresse email.';
                        }
                        if (!value.contains('@')) {
                          return 'Adresse email invalide.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    const _AuthFieldLabel('Mot de passe'),
                    const SizedBox(height: 14),
                    _AuthTextField(
                      controller: _passwordController,
                      hintText: '••••••••',
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
                          return 'Le mot de passe doit contenir au moins 6 caractères.';
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
                            : Text(_registerMode ? "S'inscrire" : 'Se connecter'),
                      ),
                    ),
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
                      child: OutlinedButton.icon(
                        onPressed: _showGooglePlaceholder,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF161C19),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFD3DED0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        icon: const Text(
                          'G',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEA4335),
                          ),
                        ),
                        label: const Text('Continuer avec Google'),
                      ),
                    ),
                    const SizedBox(height: 34),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _registerMode
                                ? "J'ai déjà un compte ? "
                                : "Vous n'avez pas de compte ? ",
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
                              _registerMode ? 'Se connecter' : "S'inscrire",
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
