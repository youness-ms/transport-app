import '../models/bus_line.dart';
import '../models/bus_stop.dart';
import '../models/bus_direction.dart';
import '../models/transport_connection.dart';
import '../models/journey.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_connection.dart';
import 'package:transport/models/route_instruction.dart';
import 'walking_router.dart';




class RoutePlanner {

  static const double transferPenalty = 300.0;

  final List<BusLine> lines;

  RoutePlanner({
    required this.lines,
  });

  Map<BusStop, List<RouteConnection>> buildGraph() {
    final Map<BusStop, List<RouteConnection>> graph = {};

    // -------------------------
    // 1. BUS CONNECTIONS
    // -------------------------

    for (final line in lines) {
      for (final direction in line.directions) {
        final stops = direction.stops;

        for (int i = 0; i < stops.length - 1; i++) {
          final from = stops[i];
          final to = stops[i + 1];

          final connection = RouteConnection(
            from: from,
            to: to,
            type: RouteConnectionType.bus,
            line: line,
            direction: direction,
            cost: 120,
          );

          graph.putIfAbsent(from, () => []);
          graph[from]!.add(connection);
        }
      }
    }

    // -------------------------
    // 2. WALKING CONNECTIONS
    // -------------------------

    const walkingDistanceLimit = 500.0;

    final distance = const Distance();

    final allStops = <BusStop>{};

    for (final line in lines) {
      for (final direction in line.directions) {
        allStops.addAll(direction.stops);
      }
    }

    for (final from in allStops) {
      for (final to in allStops) {
        if (from == to) {
          continue;
        }

        final fromLocation = LatLng(
          from.latitude,
          from.longitude,
        );

        final toLocation = LatLng(
          to.latitude,
          to.longitude,
        );

        final meters = distance.as(
          LengthUnit.Meter,
          fromLocation,
          toLocation,
        );

        if (meters <= walkingDistanceLimit) {
          final connection = RouteConnection(
            from: from,
            to: to,
            type: RouteConnectionType.walking,
            cost: meters/1.4,
          );

          graph.putIfAbsent(from, () => []);
          graph[from]!.add(connection);
        }
      }
    }

    return graph;
  }

  Journey? findRoute(
      BusStop start,
      BusStop destination,
      ) {
    final graph = buildGraph();

    final distances = <BusStop, double>{};
    final previous = <BusStop, RouteConnection?>{};
    final unvisited = <BusStop>{};

    for (final stop in graph.keys) {
      distances[stop] = double.infinity;
      previous[stop] = null;
      unvisited.add(stop);
    }

    distances[start] = 0;

    while (unvisited.isNotEmpty) {
      BusStop? current;
      double smallestDistance = double.infinity;

      for (final stop in unvisited) {
        final distance = distances[stop] ?? double.infinity;

        if (distance < smallestDistance) {
          smallestDistance = distance;
          current = stop;
        }
      }

      if (current == null) {
        break;
      }

      unvisited.remove(current);

      if (current == destination) {
        break;
      }

      final connections = graph[current] ?? [];

      for (final connection in connections) {
        if (!unvisited.contains(connection.to)) {
          continue;
        }

        final currentDistance =
            distances[current] ?? double.infinity;

        final newDistance =
            currentDistance + connection.cost;

        final oldDistance =
            distances[connection.to] ?? double.infinity;

        if (newDistance < oldDistance) {
          distances[connection.to] = newDistance;
          previous[connection.to] = connection;
        }
      }
    }

    if (distances[destination] == double.infinity) {
      return null;
    }

    // Reconstruct route backwards.
    final connections = <RouteConnection>[];

    BusStop current = destination;

    while (current != start) {
      final connection = previous[current];

      if (connection == null) {
        return null;
      }

      connections.add(connection);
      current = connection.from;
    }

    final orderedConnections =
    connections.reversed.toList();

    return _buildJourney(
      orderedConnections,
    );
  }

  Journey? findRouteFromStops(
      List<BusStop> startStops,
      BusStop destination,
      ) {
    Journey? bestJourney;

    for (final startStop in startStops) {
      final journey = findRoute(
        startStop,
        destination,
      );

      if (journey == null) {
        continue;
      }

      if (bestJourney == null ||
          journey.segments.length < bestJourney.segments.length) {
        bestJourney = journey;
      }
    }

    return bestJourney;
  }

  Journey? findRouteToStops(
      BusStop start,
      List<BusStop> destinationStops,
      ) {
    Journey? bestJourney;

    for (final destinationStop in destinationStops) {
      final journey = findRoute(
        start,
        destinationStop,
      );

      if (journey == null) {
        continue;
      }

      if (bestJourney == null ||
          journey.segments.length < bestJourney.segments.length) {
        bestJourney = journey;
      }
    }

    return bestJourney;
  }


  Journey? findBestJourney(
      List<BusStop> startStops,
      List<BusStop> destinationStops,
      ) {
    Journey? bestJourney;

    for (final startStop in startStops) {
      for (final destinationStop in destinationStops) {
        final journey = findRoute(
          startStop,
          destinationStop,
        );

        if (journey == null) {
          continue;
        }

        if (bestJourney == null ||
            journey.segments.length < bestJourney.segments.length) {
          bestJourney = journey;
        }
      }
    }

    return bestJourney;
  }

  Journey? buildJourneyWithWalking(
      LatLng startPoint,
      LatLng destinationPoint,
      List<BusStop> startStops,
      List<BusStop> destinationStops,
      ) {
    final busJourney = findBestJourney(
      startStops,
      destinationStops,
    );

    if (busJourney == null) {
      return null;
    }

    final segments = <JourneySegment>[];

    // Walking from the starting point to the first bus stop.
    final busSegments =
    busJourney.segments.whereType<TransportSegment>().toList();

    if (busSegments.isEmpty) {
      return null;
    }

    final firstBusSegment = busSegments.first;

    segments.add(
      WalkingSegment(
        points: [
          startPoint,
          LatLng(
            firstBusSegment.fromStop.latitude,
            firstBusSegment.fromStop.longitude,
          ),
        ],
      ),
    );

    // Add the bus and transfer segments.
    segments.addAll(busJourney.segments);

    // Walking from the final bus stop to the destination.
    final lastBusSegment =
        busJourney.segments.whereType<TransportSegment>().last;

    segments.add(
      WalkingSegment(
        points: [
          LatLng(
            lastBusSegment.toStop.latitude,
            lastBusSegment.toStop.longitude,
          ),
          destinationPoint,
        ],
      ),
    );

    return Journey(
      segments: segments,
    );
  }



  Journey _buildJourney(
      List<RouteConnection> connections,
      ) {
    final segments = <JourneySegment>[];

    if (connections.isEmpty) {
      return Journey(
        segments: segments,
      );
    }

    int i = 0;

    while (i < connections.length) {
      final connection = connections[i];

      // =========================
      // WALKING
      // =========================
      if (connection.type == RouteConnectionType.walking) {
        final points = <LatLng>[
          LatLng(
            connection.from.latitude,
            connection.from.longitude,
          ),
          LatLng(
            connection.to.latitude,
            connection.to.longitude,
          ),
        ];

        i++;

        // Combine consecutive walking connections
        // into ONE WalkingSegment.
        while (i < connections.length &&
            connections[i].type == RouteConnectionType.walking) {
          final next = connections[i];

          points.add(
            LatLng(
              next.to.latitude,
              next.to.longitude,
            ),
          );

          i++;
        }

        segments.add(
          WalkingSegment(
            points: points,
          ),
        );

        continue;
      }

      // =========================
      // BUS
      // =========================

      final line = connection.line!;
      final direction = connection.direction!;

      final fromStop = connection.from;
      BusStop toStop = connection.to;

      final points = <LatLng>[
        LatLng(
          connection.from.latitude,
          connection.from.longitude,
        ),
        LatLng(
          connection.to.latitude,
          connection.to.longitude,
        ),
      ];

      i++;

      // Continue while we're still on the same bus.
      while (i < connections.length) {
        final next = connections[i];

        if (next.type != RouteConnectionType.bus ||
            next.line != line ||
            next.direction != direction) {
          break;
        }

        toStop = next.to;

        points.add(
          LatLng(
            next.to.latitude,
            next.to.longitude,
          ),
        );

        i++;
      }

      segments.add(
        TransportSegment(
          line: line,
          direction: direction,
          fromStop: fromStop,
          toStop: toStop,
          points: points,
        ),
      );

      // We DO NOT add a transfer here automatically.
      //
      // If the next segment is walking, the walking segment
      // already explains what the passenger needs to do.
      //
      // If the next segment is another bus, add a transfer.
      if (i < connections.length) {
        final next = connections[i];

        if (next.type == RouteConnectionType.bus &&
            next.line != line) {
          segments.add(
            TransferSegment(
              stop: toStop,
              points: [
                LatLng(
                  toStop.latitude,
                  toStop.longitude,
                ),
              ],
            ),
          );
        }
      }
    }

    return Journey(
      segments: segments,
    );
  }
  List<RouteInstruction> buildInstructions(Journey journey) {
    final instructions = <RouteInstruction>[];

    for (final segment in journey.segments) {
      // =========================
      // WALKING
      // =========================
      if (segment is WalkingSegment) {
        instructions.add(
          RouteInstruction(
            type: RouteInstructionType.walking,
          ),
        );

        continue;
      }

      // =========================
      // BUS
      // =========================
      if (segment is TransportSegment) {
        instructions.add(
          RouteInstruction(
            type: RouteInstructionType.boardBus,
            line: segment.line,
            direction: segment.direction.destination,
            fromStop: segment.fromStop,
          ),
        );

        instructions.add(
          RouteInstruction(
            type: RouteInstructionType.getOffBus,
            line: segment.line,
            direction: segment.direction.destination,
            toStop: segment.toStop,
          ),
        );

        continue;
      }
    }

    return instructions;
  }
  Future<Journey> loadWalkingGeometry(
      Journey journey,
      ) async {
    return journey;
  }
  final WalkingRouter walkingRouter = WalkingRouter();
  Future<Journey> addWalkingGeometry(
      Journey journey,
      ) async {
    final newSegments = <JourneySegment>[];

    for (final segment in journey.segments) {
      if (segment is! WalkingSegment ||
          segment.points.length < 2) {
        newSegments.add(segment);
        continue;
      }

      final start = segment.points.first;
      final destination = segment.points.last;

      try {
        final walkingPoints =
        await walkingRouter.getWalkingRoute(
          start,
          destination,
        );

        if (walkingPoints != null &&
            walkingPoints.length >= 2) {
          newSegments.add(
            WalkingSegment(
              points: walkingPoints,
            ),
          );
        } else {
          newSegments.add(segment);
        }
      } catch (e) {
        // If pedestrian routing fails, keep
        // the original straight walking segment.
        newSegments.add(segment);
      }
    }

    return Journey(
      segments: newSegments,
    );
  }
}