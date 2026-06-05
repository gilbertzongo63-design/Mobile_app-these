import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/prediction_result.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    this.prediction,
    this.imageBytes,
  });

  final PredictionResult? prediction;
  final Uint8List? imageBytes;

  String get _recommendedClass =>
      prediction?.recommendedClass.isNotEmpty == true
          ? prediction!.recommendedClass
          : 'Other';

  String get _detectedTitle {
    switch (_recommendedClass.toLowerCase()) {
      case 'plastic':
        return 'Plastique';
      case 'glass':
        return 'Verre';
      case 'metal':
        return 'Métal';
      case 'papercardboard':
        return 'Papier / Carton';
      default:
        return 'Autre déchet';
    }
  }

  String get _instruction {
    if (_requiresReview) {
      return "L'image semble floue, incomplète ou ambiguë. Reprenez une photo plus nette, bien cadrée et mieux éclairée pour confirmer le tri.";
    }

    switch (_recommendedClass.toLowerCase()) {
      case 'plastic':
        return "À déposer dans le bac de tri adapté aux plastiques selon les consignes de votre commune. Videz l'objet avant de le jeter.";
      case 'glass':
        return "À déposer dans le conteneur à verre si l'objet est compatible. Retirez les éléments non verriers si nécessaire.";
      case 'metal':
        return "À déposer dans le bac recyclable ou la filière métal adaptée. Videz bien le contenant avant le tri.";
      case 'papercardboard':
        return "À déposer dans le bac papier/carton si le déchet est propre et majoritairement fibreux. Pliez le carton si nécessaire.";
      default:
        return "Cet objet ne correspond pas clairement aux catégories recyclables principales. Vérifiez les consignes locales avant de le jeter.";
    }
  }

  String get _statusLabel => prediction?.triageLabel ?? 'À vérifier';

  bool get _isRecyclable => prediction?.isRecyclable ?? false;
  bool get _isNonRecyclable => prediction?.isNonRecyclable ?? false;
  bool get _requiresReview => prediction?.requiresReview ?? false;

  String get _confidenceLabel {
    final confidence = ((prediction?.finalConfidence ?? 0) * 100).round();
    return '$confidence%';
  }

  String get _binBadge {
    if (_requiresReview) return 'BAC À VÉRIFIER';
    if (_isNonRecyclable) return 'BAC GRIS';
    return 'BAC JAUNE';
  }

  Color get _binAccentColor {
    if (_requiresReview) return const Color(0xFFF09A2D);
    if (_isNonRecyclable) return const Color(0xFF707C74);
    return const Color(0xFF0E8A57);
  }

  String get _decisionLabel {
    if (_requiresReview) {
      return 'Incertain';
    }
    if (_isNonRecyclable) {
      return 'Résiduel';
    }
    return 'Validé';
  }

  String get _decisionReason {
    final reason = prediction?.reason ?? 'vision_top1';
    switch (reason) {
      case 'low_confidence_vision':
        return 'Confiance modérée';
      case 'vision_top1':
        return 'Vision dominante';
      default:
        return reason.replaceAll('_', ' ');
    }
  }

  String get _visionClass {
    final predictedClass = prediction?.vision['predicted_class'] as String?;
    if (predictedClass != null && predictedClass.isNotEmpty) {
      return predictedClass;
    }
    final topPredictions = prediction?.vision['top_predictions'] as List?;
    if (topPredictions != null && topPredictions.isNotEmpty) {
      final first = topPredictions.first;
      if (first is Map) {
        return first['class_name'] as String? ?? '-';
      }
    }
    return '-';
  }

  String get _visionConfidence {
    final probability =
        (prediction?.vision['predicted_probability'] as num?)?.toDouble();
    if (probability != null) {
      return '${(probability * 100).round()}%';
    }
    final topPredictions = prediction?.vision['top_predictions'] as List?;
    if (topPredictions != null && topPredictions.isNotEmpty) {
      final first = topPredictions.first;
      if (first is Map) {
        final topProbability = (first['probability'] as num?)?.toDouble();
        if (topProbability != null) {
          return '${(topProbability * 100).round()}%';
        }
      }
    }
    return '-';
  }

  bool get _hasReliableOcr {
    final hasTextSignal = prediction?.ocr['has_text_signal'] == true;
    final confidence = (prediction?.ocr['confidence'] as num?)?.toDouble() ?? 0;
    final matched = prediction?.ocr['matched_keywords'];
    return hasTextSignal &&
        confidence >= 0.65 &&
        matched is Map &&
        matched.isNotEmpty;
  }

  String get _ocrRawText {
    if (!_hasReliableOcr) {
      return "Aucun texte fiable detecte sur l'objet.";
    }
    final text = prediction?.ocr['raw_text'] as String? ?? '';
    return text.trim().isEmpty
        ? "Aucun texte fiable detecte sur l'objet."
        : text.trim();
  }

  String get _ocrCleanText {
    if (!_hasReliableOcr) {
      return '-';
    }
    final text = prediction?.ocr['clean_text'] as String? ?? '';
    return text.trim().isEmpty ? '-' : text.trim();
  }

  String get _ocrClass {
    if (!_hasReliableOcr) {
      return 'OCR non fiable';
    }
    final predictedClass = prediction?.ocr['predicted_class'] as String?;
    return predictedClass == null || predictedClass.isEmpty
        ? 'Aucune classe OCR'
        : predictedClass;
  }

  String get _ocrConfidence {
    if (!_hasReliableOcr) {
      return '-';
    }
    final confidence = (prediction?.ocr['confidence'] as num?)?.toDouble();
    return confidence == null ? '-' : '${(confidence * 100).round()}%';
  }

  String get _ocrKeywords {
    if (!_hasReliableOcr) {
      return 'Aucun mot-cle fiable';
    }
    final matched = prediction?.ocr['matched_keywords'];
    if (matched is! Map || matched.isEmpty) {
      return 'Aucun mot-cle detecte';
    }

    final keywords = <String>[];
    for (final value in matched.values) {
      if (value is List) {
        keywords.addAll(value.map((item) => item.toString()));
      }
    }

    return keywords.isEmpty ? 'Aucun mot-cle detecte' : keywords.join(', ');
  }

  String get _ocrQuality {
    if (!_hasReliableOcr) {
      return 'Non fiable';
    }
    final confidence =
        (prediction?.ocr['average_word_confidence'] as num?)?.toDouble();
    if (confidence == null || confidence <= 0) {
      return '-';
    }
    return '${(confidence * 100).round()}%';
  }

  String get _ocrBestPass {
    if (!_hasReliableOcr) {
      return '-';
    }
    final variant = prediction?.ocr['preprocess_variant'] as String? ?? '';
    if (variant.trim().isEmpty) {
      return '-';
    }
    return variant.replaceAll('_', ' ');
  }

  String get _ocrDetectedWords {
    if (!_hasReliableOcr) {
      return 'Aucun mot fiable';
    }
    final detectedWords = prediction?.ocr['detected_words'];
    if (detectedWords is! List || detectedWords.isEmpty) {
      return 'Aucun mot lisible';
    }

    final words = <String>[];
    for (final item in detectedWords) {
      if (item is Map) {
        final text = item['text']?.toString().trim() ?? '';
        if (text.isNotEmpty) {
          words.add(text);
        }
      }
    }
    return words.isEmpty ? 'Aucun mot lisible' : words.take(12).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF5F9F0);
    const green = Color(0xFF33CF71);
    const darkGreen = Color(0xFF0A8A52);

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
                        const Expanded(
                          child: Center(
                            child: Text(
                              "Résultat de l'analyse",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: darkGreen,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9F0E4),
                            borderRadius: BorderRadius.circular(23),
                          ),
                          child: const Icon(
                            Icons.smartphone_rounded,
                            color: Color(0xFF253E30),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _ResultHeroCard(
                      imageBytes: imageBytes,
                      imageUrl: prediction?.imageUrl ?? '',
                      statusLabel: _statusLabel,
                      isRecyclable: _isRecyclable,
                      isNonRecyclable: _isNonRecyclable,
                      requiresReview: _requiresReview,
                    ),
                    const SizedBox(height: 28),
                    _DetectedObjectCard(
                      title: _detectedTitle,
                      instruction: _instruction,
                      isRecyclable: _isRecyclable,
                      isNonRecyclable: _isNonRecyclable,
                      requiresReview: _requiresReview,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _ImpactCard(
                            background: const [
                              Color(0xFFD9FBE1),
                              Color(0xFFEAFBE5),
                            ],
                            borderColor: const Color(0xFFB8EDC8),
                            icon: Icons.verified_outlined,
                            iconColor: darkGreen,
                            value: _confidenceLabel,
                            label: 'Confiance du modèle',
                            valueColor: const Color(0xFF158854),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _ImpactCard(
                            background: const [
                              Color(0xFFFCECDD),
                              Color(0xFFF8EFE7),
                            ],
                            borderColor: const Color(0xFFF0D6BF),
                            icon: Icons.category_outlined,
                            iconColor: const Color(0xFFB55C30),
                            value: _decisionLabel,
                            label: _decisionReason,
                            valueColor: const Color(0xFFB04D26),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _AnalysisDetailsCard(
                      visionClass: _visionClass,
                      visionConfidence: _visionConfidence,
                      ocrClass: _ocrClass,
                      ocrConfidence: _ocrConfidence,
                      ocrRawText: _ocrRawText,
                      ocrCleanText: _ocrCleanText,
                      ocrKeywords: _ocrKeywords,
                      ocrQuality: _ocrQuality,
                      ocrBestPass: _ocrBestPass,
                      ocrDetectedWords: _ocrDetectedWords,
                      decisionReason: _decisionReason,
                    ),
                    const SizedBox(height: 16),
                    _BinRecommendation(
                        badge: _binBadge, accent: _binAccentColor),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const ScanScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: const Color(0xFF16311E),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Nouvelle analyse'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF253327),
                          backgroundColor: const Color(0xFFF1F5EC),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text("Retour à l'accueil"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppBottomNavBar(
              selectedIndex: 1,
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

class _ResultHeroCard extends StatelessWidget {
  const _ResultHeroCard({
    required this.imageBytes,
    required this.imageUrl,
    required this.statusLabel,
    required this.isRecyclable,
    required this.isNonRecyclable,
    required this.requiresReview,
  });

  final Uint8List? imageBytes;
  final String imageUrl;
  final String statusLabel;
  final bool isRecyclable;
  final bool isNonRecyclable;
  final bool requiresReview;

  Color get _chipBackground {
    if (requiresReview) {
      return const Color(0xFFF7DDB5);
    }
    if (isNonRecyclable) {
      return const Color(0xFFF6B8B3);
    }
    return const Color(0xFF35CF72);
  }

  Color get _chipForeground {
    if (requiresReview) {
      return const Color(0xFF9A640D);
    }
    if (isNonRecyclable) {
      return const Color(0xFF8D2623);
    }
    return const Color(0xFF0D5B36);
  }

  IconData get _chipIcon {
    if (requiresReview) {
      return Icons.help_outline_rounded;
    }
    if (isNonRecyclable) {
      return Icons.block_rounded;
    }
    return Icons.check_circle;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFFE3E9E0), Color(0xFFFBF6EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (imageBytes != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Image.memory(
                  imageBytes!,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else if (imageUrl.isNotEmpty)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _MaterialIllustration(),
                ),
              ),
            )
          else
            const Positioned.fill(
              child: Center(child: _MaterialIllustration()),
            ),
          Positioned(
            right: 18,
            top: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: _chipBackground,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _chipIcon,
                    color: _chipForeground,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _chipForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectedObjectCard extends StatelessWidget {
  const _DetectedObjectCard({
    required this.title,
    required this.instruction,
    required this.isRecyclable,
    required this.isNonRecyclable,
    required this.requiresReview,
  });

  final String title;
  final String instruction;
  final bool isRecyclable;
  final bool isNonRecyclable;
  final bool requiresReview;

  Color get _iconBackground {
    if (requiresReview) {
      return const Color(0xFFF8EED7);
    }
    if (isNonRecyclable) {
      return const Color(0xFFF7E2E0);
    }
    return const Color(0xFFEAF5E8);
  }

  Color get _iconColor {
    if (requiresReview) {
      return const Color(0xFFAA740B);
    }
    if (isNonRecyclable) {
      return const Color(0xFFB93D35);
    }
    return const Color(0xFF148654);
  }

  IconData get _icon {
    if (requiresReview) {
      return Icons.search_off_rounded;
    }
    if (isNonRecyclable) {
      return Icons.delete_outline_rounded;
    }
    return Icons.recycling_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CLASSE DÉTECTÉE',
                      style: TextStyle(
                        letterSpacing: 1.1,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4A544D),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF171E18),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: _iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon,
                  color: _iconColor,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8ED),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF178755),
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Instruction de tri',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF148654),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  instruction,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.55,
                    color: Color(0xFF2D3931),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  const _ImpactCard({
    required this.background,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final List<Color> background;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        gradient: LinearGradient(
          colors: background,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 18),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF34503D),
            ),
          ),
        ],
      ),
    );
  }
}

class _BinRecommendation extends StatelessWidget {
  const _BinRecommendation({required this.badge, required this.accent});

  final String badge;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 16, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8ED),
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: 40, color: accent),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Où jeter',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2F3A32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisDetailsCard extends StatelessWidget {
  const _AnalysisDetailsCard({
    required this.visionClass,
    required this.visionConfidence,
    required this.ocrClass,
    required this.ocrConfidence,
    required this.ocrRawText,
    required this.ocrCleanText,
    required this.ocrKeywords,
    required this.ocrQuality,
    required this.ocrBestPass,
    required this.ocrDetectedWords,
    required this.decisionReason,
  });

  final String visionClass;
  final String visionConfidence;
  final String ocrClass;
  final String ocrConfidence;
  final String ocrRawText;
  final String ocrCleanText;
  final String ocrKeywords;
  final String ocrQuality;
  final String ocrBestPass;
  final String ocrDetectedWords;
  final String decisionReason;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: Color(0xFF0A8A52),
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                "Details de l'analyse",
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF17211C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _AnalysisMetric(
                  icon: Icons.visibility_outlined,
                  label: 'Vision',
                  value: visionClass,
                  detail: visionConfidence,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnalysisMetric(
                  icon: Icons.text_fields_rounded,
                  label: 'OCR',
                  value: ocrClass,
                  detail: ocrConfidence,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AnalysisTextBlock(
            title: "Texte lu par l'OCR",
            text: ocrRawText,
          ),
          const SizedBox(height: 12),
          _AnalysisTextBlock(
            title: 'Texte nettoye',
            text: ocrCleanText,
            compact: true,
          ),
          const SizedBox(height: 14),
          _AnalysisLine(label: 'Qualite OCR', value: ocrQuality),
          const SizedBox(height: 8),
          _AnalysisLine(label: 'Passe OCR', value: ocrBestPass),
          const SizedBox(height: 8),
          _AnalysisLine(label: 'Mots lus', value: ocrDetectedWords),
          const SizedBox(height: 8),
          _AnalysisLine(label: 'Mots-cles detectes', value: ocrKeywords),
          const SizedBox(height: 8),
          _AnalysisLine(label: 'Fusion', value: decisionReason),
        ],
      ),
    );
  }
}

class _AnalysisMetric extends StatelessWidget {
  const _AnalysisMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8ED),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF148654), size: 22),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A544D),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF17211C),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF516057),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisTextBlock extends StatelessWidget {
  const _AnalysisTextBlock({
    required this.title,
    required this.text,
    this.compact = false,
  });

  final String title;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.fromLTRB(14, compact ? 12 : 14, 14, compact ? 12 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBDD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF148654),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: compact ? 14 : 16,
              height: 1.35,
              color: const Color(0xFF26352C),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisLine extends StatelessWidget {
  const _AnalysisLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A544D),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: Color(0xFF17211C),
            ),
          ),
        ),
      ],
    );
  }
}

class _MaterialIllustration extends StatelessWidget {
  const _MaterialIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 142,
            height: 142,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.34),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0x8897B3BC),
                width: 2,
              ),
            ),
          ),
          const Icon(
            Icons.recycling_rounded,
            size: 86,
            color: Color(0xFF0A8A52),
          ),
        ],
      ),
    );
  }
}
