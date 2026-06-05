class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.sortGuidance,
  });

  final int id;
  final String name;
  final String description;
  final String sortGuidance;

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sortGuidance: json['sort_guidance'] as String? ?? '',
    );
  }
}
