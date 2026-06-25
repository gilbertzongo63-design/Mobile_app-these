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
    icon: const Text(
      'G',
      style: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: Color(0xFFEA4335),
      ),
    ),
    label: const Text('Continuer avec Google'),
  );
}
