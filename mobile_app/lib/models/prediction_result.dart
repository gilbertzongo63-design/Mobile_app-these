class PredictionResult {
  const PredictionResult({
    required this.predictionId,
    required this.imageFilename,
    required this.createdAt,
    required this.storedImagePath,
    required this.imageUrl,
    required this.modelProfile,
    required this.reviewStatus,
    required this.vision,
    required this.ocr,
    required this.decision,
  });

  final int predictionId;
  final String imageFilename;
  final String createdAt;
  final String storedImagePath;
  final String imageUrl;
  final String modelProfile;
  final String reviewStatus;
  final Map<String, dynamic> vision;
  final Map<String, dynamic> ocr;
  final Map<String, dynamic> decision;

  String get recommendedClass => decision['recommended_class'] as String? ?? '';
  String get modelTop1Class => decision['model_top1_class'] as String? ?? '';
  double get finalConfidence =>
      (decision['final_confidence'] as num?)?.toDouble() ?? 0.0;
  String get status => decision['status'] as String? ?? 'unknown';
  String get reason => decision['reason'] as String? ?? '';

  bool get requiresReview =>
      status == 'review' || reviewStatus == 'review' || finalConfidence < 0.55;

  bool get isNonRecyclable =>
      !requiresReview && recommendedClass.toLowerCase() == 'other';

  bool get isRecyclable =>
      !requiresReview && recommendedClass.toLowerCase() != 'other';

  String get triageLabel {
    if (requiresReview) {
      return 'À vérifier';
    }
    if (isNonRecyclable) {
      return 'Non recyclable';
    }
    return 'Recyclable';
  }

  String get classLabel {
    switch (recommendedClass.toLowerCase()) {
      case 'plastic':
        return 'Plastique';
      case 'glass':
        return 'Verre';
      case 'metal':
        return 'Métal';
      case 'papercardboard':
        return 'Papier / Carton';
      case 'other':
        return 'Autre déchet';
      default:
        return recommendedClass.isEmpty ? 'Objet inconnu' : recommendedClass;
    }
  }

  String get decisionLabel {
    if (requiresReview) {
      return 'À valider';
    }
    if (isNonRecyclable) {
      return 'Résiduel';
    }
    return 'Validé';
  }

  String get reasonLabel {
    switch (reason) {
      case 'vision_top1':
        return 'Décision basée sur la vision';
      case 'strong_class_specific_vision_top1':
        return 'Vision très fiable';
      case 'vision_strong_confirmed_by_ocr':
        return 'Vision confirmée par OCR';
      case 'vision_confirmed_by_ocr':
        return 'Vision et OCR cohérents';
      case 'low_confidence_vision':
        return 'Confiance visuelle faible';
      case 'low_confidence_vision_supported_by_ocr':
        return 'OCR utilisé en appui';
      case 'vision_other_replaced_by_ocr':
        return 'OCR prioritaire';
      case 'low_confidence_other_fallback':
        return 'Alternative proposée';
      case 'preferred_class_other_fallback':
        return 'Alternative à vérifier';
      case 'other_bias_recycled_fallback':
        return 'Recyclable probable';
      case 'manual_validation':
        return 'Validation manuelle';
      case 'user_correction':
        return 'Correction utilisateur';
      default:
        return reason.isEmpty
            ? 'Décision automatique'
            : reason.replaceAll('_', ' ');
    }
  }

  String get sortInstruction {
    if (requiresReview) {
      return "L'image semble ambiguë. Reprenez une photo nette, bien cadrée et mieux éclairée, ou attendez une validation.";
    }

    switch (recommendedClass.toLowerCase()) {
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

  String get binLabel {
    if (requiresReview) return 'BAC À VÉRIFIER';
    if (isNonRecyclable) return 'BAC GRIS';
    return 'BAC JAUNE';
  }

  String get formattedConfidence => '${(finalConfidence * 100).round()}%';

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      predictionId: (json['prediction_id'] ?? json['analysis_id'] ?? json['id'])
              as int? ??
          0,
      imageFilename: json['image_filename'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      storedImagePath: json['stored_image_path'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      modelProfile: json['model_profile'] as String? ?? '',
      reviewStatus: json['review_status'] as String? ?? '',
      vision: Map<String, dynamic>.from(json['vision'] as Map? ?? const {}),
      ocr: Map<String, dynamic>.from(json['ocr'] as Map? ?? const {}),
      decision: Map<String, dynamic>.from(json['decision'] as Map? ?? const {}),
    );
  }
}
