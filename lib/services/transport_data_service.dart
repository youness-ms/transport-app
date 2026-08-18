import 'dart:convert';
import '../models/famous_place.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../models/bus_line.dart';
import '../models/bus_direction.dart';
import '../models/bus_stop.dart';
import '../models/transport_type.dart';
List<FamousPlace> loadedPlaces = [];
class TransportDataService {
  static Future<List<BusLine>> loadLines() async {
    final jsonString =
    await rootBundle.loadString('assets/data/transport.json');

    final Map<String, dynamic> data =
    jsonDecode(jsonString);
    loadedPlaces = (data['places'] as List<dynamic>? ?? [])
        .map(
          (place) => FamousPlace.fromJson(
        place as Map<String, dynamic>,
      ),
    )
        .toList();

    final List<dynamic> linesJson =
    data['lines'];

    final List<BusLine> lines = [];

    // Shared stops
    final Map<String, BusStop> stopsMap = {};

    for (final lineJson in linesJson) {
      final List<BusDirection> directions = [];

      final List<dynamic> directionsJson =
      lineJson['directions'];

      for (final directionJson in directionsJson) {
        final List<BusStop> stops = [];

        final List<dynamic> stopsJson =
        directionJson['stops'];

        for (final stopJson in stopsJson) {
          final double latitude =
          (stopJson['latitude'] as num).toDouble();

          final double longitude =
          (stopJson['longitude'] as num).toDouble();

          final String stopKey =
              '${latitude.toStringAsFixed(6)},'
              '${longitude.toStringAsFixed(6)}';

          BusStop? stop = stopsMap[stopKey];

          if (stop == null) {
            stop = BusStop(
              name: stopJson['name'],
              latitude: latitude,
              longitude: longitude,
              lines: [],
            );

            stopsMap[stopKey] = stop;
          }

          stops.add(stop);
        }

        final List<LatLng> routePoints =
        (directionJson['routePoints'] as List<dynamic>)
            .map(
              (point) => LatLng(
            (point['latitude'] as num).toDouble(),
            (point['longitude'] as num).toDouble(),
          ),
        )
            .toList();

        directions.add(
          BusDirection(
            destination: directionJson['destination'],
            stops: stops,
            routePoints: routePoints,
          ),
        );
      }
      final TransportType type;

      switch (lineJson['type']) {
        case 'tram':
          type = TransportType.tram;
          break;

        case 'bus':
        default:
          type = TransportType.bus;
      }

      final BusLine line = BusLine(
        name: lineJson['name'],
        type: type,
        directions: directions,
      );

      lines.add(line);

      // Connect this line to its stops
      for (final direction in directions) {
        for (final stop in direction.stops) {
          if (!stop.lines.contains(line)) {
            stop.lines.add(line);
          }
        }
      }
    }

    return lines;
  }
}