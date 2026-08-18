import 'bus_direction.dart';
import 'bus_line.dart';
import 'bus_stop.dart';

enum RouteConnectionType {
  walking,
  bus,
}

class RouteConnection {
  final BusStop from;
  final BusStop to;

  final RouteConnectionType type;

  // Used when this connection is a bus.
  final BusLine? line;
  final BusDirection? direction;

  // The cost of using this connection.
  // For now this will represent distance/time approximately.
  final double cost;

  RouteConnection({
    required this.from,
    required this.to,
    required this.type,
    required this.cost,
    this.line,
    this.direction,
  });
}