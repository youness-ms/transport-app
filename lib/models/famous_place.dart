class FamousPlace {
  final String name;
  final String category;
  final double latitude;
  final double longitude;

  FamousPlace({
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
  });

  factory FamousPlace.fromJson(Map<String, dynamic> json) {
    return FamousPlace(
      name: json['name'] as String,
      category: json['category'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}