class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.profileImageUrl,
    required this.createdAt,
  });

  final int id;
  final String email;
  final String fullName;
  final String profileImageUrl;
  final String createdAt;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      profileImageUrl: json['profile_image_url'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'profile_image_url': profileImageUrl,
      'created_at': createdAt,
    };
  }
}
