import 'package:firebase_database/firebase_database.dart';

import '../models/ai_place.dart';

class AiDataService {
  final DatabaseReference placesRef =
  FirebaseDatabase.instance.ref('ai_places');

  Future<List<AiPlace>> loadPlaces() async {
    final snapshot = await placesRef.get();

    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }

    final data = Map<String, dynamic>.from(
      snapshot.value as Map,
    );

    final places =
        data['places'] as List<dynamic>? ?? [];

    return places
        .map(
          (place) => AiPlace.fromJson(
        Map<String, dynamic>.from(place as Map),
      ),
    )
        .toList();
  }
}