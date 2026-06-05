class ApiHealth {
  const ApiHealth({
    required this.status,
    required this.modelProfile,
    required this.databaseBackend,
  });

  final String status;
  final String modelProfile;
  final String databaseBackend;

  factory ApiHealth.fromJson(Map<String, dynamic> json) {
    return ApiHealth(
      status: json['status'] as String? ?? 'unknown',
      modelProfile: json['model_profile'] as String? ?? 'unknown',
      databaseBackend: json['database_backend'] as String? ?? 'unknown',
    );
  }
}
