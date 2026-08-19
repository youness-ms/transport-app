class AiPlace {
  final int id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final String description;

  AiPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.description,
  });

  factory AiPlace.fromJson(
      Map<String, dynamic> json,
      ) {
    return AiPlace(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      category: json['category'] as String,
      latitude:
      (json['latitude'] as num).toDouble(),
      longitude:
      (json['longitude'] as num).toDouble(),
      description:
      json['description'] as String? ?? '',
    );
  }
}