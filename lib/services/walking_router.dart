import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class WalkingRouter {
  // Valhalla public demo server.
  // For a deployed app, use your own Valhalla server or an appropriate
  // hosted Valhalla service.
  static const String baseUrl =
      'https://valhalla1.openstreetmap.de/route';

  Future<List<LatLng>?> getWalkingRoute(
      LatLng start,
      LatLng destination,
      ) async {
    final request = {
      'locations': [
        {
          'lat': start.latitude,
          'lon': start.longitude,
        },
        {
          'lat': destination.latitude,
          'lon': destination.longitude,
        },
      ],
      'costing': 'pedestrian',
      'costing_options': {
        'pedestrian': {
          'use_ferry': 0.0,
          'use_hills': 0.2,
          'walking_speed': 5.0,
        },
      },
      'units': 'kilometers',
      'directions_options': {
        'units': 'kilometers',
      },
    };

    final response = await http.get(
      Uri.parse(
        '$baseUrl?json=${Uri.encodeComponent(jsonEncode(request))}',
      ),
    );
    print('===== VALHALLA REQUEST =====');
    print(jsonEncode(request));
    print('Status: ${response.statusCode}');
    print('============================');

    if (response.statusCode != 200) {
      throw Exception(
        'Walking route failed: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    print('Valhalla trip summary:');
    print(data['trip']);

    if (data['trip'] == null ||
        data['trip']['legs'] == null ||
        data['trip']['legs'].isEmpty) {
      throw Exception('No walking route found');
    }

    final shape =
    data['trip']['legs'][0]['shape'] as String;

    return _decodeShape(shape);
  }

  List<LatLng> _decodeShape(String shape) {
    // Valhalla uses an encoded polyline with precision 6.
    final points = <LatLng>[];

    int index = 0;
    int latitude = 0;
    int longitude = 0;

    while (index < shape.length) {
      int result = 0;
      int shift = 0;
      int byte;

      do {
        byte = shape.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      final deltaLatitude =
      (result & 1) != 0
          ? ~(result >> 1)
          : (result >> 1);

      latitude += deltaLatitude;

      result = 0;
      shift = 0;

      do {
        byte = shape.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      final deltaLongitude =
      (result & 1) != 0
          ? ~(result >> 1)
          : (result >> 1);

      longitude += deltaLongitude;

      points.add(
        LatLng(
          latitude / 1000000.0,
          longitude / 1000000.0,
        ),
      );
    }

    return points;
  }
}