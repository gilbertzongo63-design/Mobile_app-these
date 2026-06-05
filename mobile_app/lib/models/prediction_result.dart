class PredictionResult {
  const PredictionResult({
    required this.predictionId,
    required this.imageFilename,
    required this.createdAt,
    required this.storedImagePath,
    required this.imageUrl,
    required this.modelProfile,
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
  final Map<String, dynamic> vision;
  final Map<String, dynamic> ocr;
  final Map<String, dynamic> decision;

  String get recommendedClass => decision['recommended_class'] as String? ?? '';
  String get modelTop1Class => decision['model_top1_class'] as String? ?? '';
  double get finalConfidence =>
      (decision['final_confidence'] as num?)?.toDouble() ?? 0.0;
  String get status => decision['status'] as String? ?? 'unknown';
  String get reason => decision['reason'] as String? ?? '';

  bool get requiresReview => status == 'review' || finalConfidence < 0.55;

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

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      predictionId: (json['prediction_id'] ?? json['analysis_id']) as int? ?? 0,
      imageFilename: json['image_filename'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      storedImagePath: json['stored_image_path'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      modelProfile: json['model_profile'] as String? ?? '',
      vision: Map<String, dynamic>.from(json['vision'] as Map? ?? const {}),
      ocr: Map<String, dynamic>.from(json['ocr'] as Map? ?? const {}),
      decision: Map<String, dynamic>.from(json['decision'] as Map? ?? const {}),
    );
  }
}
