import 'package:flutter/material.dart';

Widget buildGoogleSignInButton(void Function() onPressed) {
  return OutlinedButton.icon(
    onPressed: onPressed,
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
    icon: Image.asset(
      'assets/images/google_g_logo.png',
      width: 28,
      height: 28,
    ),
    label: const Text('Continuer avec Google'),
  );
}
