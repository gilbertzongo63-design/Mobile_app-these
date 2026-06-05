import 'package:flutter/material.dart';

import '../widgets/app_bottom_nav_bar.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final Set<int> _expandedFaqIndexes = <int>{};

  void _toggleFaq(int index) {
    setState(() {
      if (_expandedFaqIndexes.contains(index)) {
        _expandedFaqIndexes.remove(index);
      } else {
        _expandedFaqIndexes.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF5F9F0);
    const darkGreen = Color(0xFF0A8A52);

    const faqs = [
      (
        "L'objet n'est pas reconnu ?",
        "Vérifiez la qualité de l’image, le cadrage et l’éclairage. Si nécessaire, recommencez l’analyse avec une photo plus nette.",
      ),
      (
        'Où trouver les points de collecte ?',
        "Les points de collecte sont accessibles dans la section dédiée de l’application, avec les informations utiles sur leur localisation et les déchets acceptés.",
      ),
      (
        "Puis-je utiliser l'application sans internet ?",
        "L’utilisation hors ligne peut être partielle. Certaines fonctions nécessitent une connexion pour l’analyse et la synchronisation des données.",
      ),
    ];

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: darkGreen,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Aide',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: darkGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: darkGreen,
                          size: 30,
                        ),
                        SizedBox(width: 14),
                        Text(
                          'Comment ça marche',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF17211C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _HeroDemoCard(),
                    const SizedBox(height: 22),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.6,
                          color: Color(0xFF27342C),
                        ),
                        children: [
                          TextSpan(
                            text:
                                'EcoSort simplifie votre recyclage. Prenez simplement une photo de votre déchet avec la fonction ',
                          ),
                          TextSpan(
                            text: 'Scan',
                            style: TextStyle(
                              color: darkGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text:
                                ', et notre IA vous dira instantanément dans quelle poubelle le jeter. Ensemble, optimisons le tri !',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        _StepItem(
                          icon: Icons.camera_alt_outlined,
                          label: 'Scannez',
                        ),
                        _StepItem(
                          icon: Icons.bolt_rounded,
                          label: 'Analysez',
                        ),
                        _StepItem(
                          icon: Icons.delete_outline_rounded,
                          label: 'Triez',
                        ),
                      ],
                    ),
                    const SizedBox(height: 42),
                    const Text(
                      'Questions Fréquentes',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF17211C),
                      ),
                    ),
                    const SizedBox(height: 22),
                    ...List.generate(
                      faqs.length,
                      (index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: index == faqs.length - 1 ? 0 : 12,
                        ),
                        child: _FaqTile(
                          title: faqs[index].$1,
                          answer: faqs[index].$2,
                          expanded: _expandedFaqIndexes.contains(index),
                          onTap: () => _toggleFaq(index),
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    const Text(
                      'Contactez-nous',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF17211C),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: const [
                        Expanded(
                          child: _ContactCard(
                            icon: Icons.mail_outline_rounded,
                            label: 'E-mail',
                            background: Color(0xFF71F59D),
                            foreground: Color(0xFF0B6E42),
                          ),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: _ContactCard(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'Chat Live',
                            background: Color(0xFF08793E),
                            foreground: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'Notre équipe est disponible du lundi au\nvendredi, de 9h à 18h pour répondre à toutes\nvos questions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: Color(0xFF344239),
                        ),
                      ),
                    ),
                  ],
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
                } else if (index == 3) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
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

class _HeroDemoCard extends StatelessWidget {
  const _HeroDemoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF9ABA71), Color(0xFF516A3B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -0.55,
                child: Container(
                  width: 98,
                  height: 170,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2026),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FBF4),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 56,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD9E2D4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 54,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFF65D483),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Center(
                              child: Text(
                                'PET',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 60,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7EEE4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 18,
                child: Transform.rotate(
                  angle: -0.18,
                  child: Container(
                    width: 72,
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF0D3BC), Color(0xFFBF8E6C)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(36),
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

class _StepItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StepItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: const BoxDecoration(
            color: Color(0xFF35CF72),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF0A542F), size: 34),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF17211C),
          ),
        ),
      ],
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String title;
  final String answer;
  final bool expanded;
  final VoidCallback onTap;

  const _FaqTile({
    required this.title,
    required this.answer,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF17211C),
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF0A8A52),
                    size: 28,
                  ),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 14),
              Text(
                answer,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF344239),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  const _ContactCard({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 106,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: foreground, size: 34),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
