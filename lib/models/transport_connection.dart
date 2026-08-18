import 'bus_direction.dart';
import 'bus_line.dart';
import 'bus_stop.dart';

class TransportConnection {
  final BusStop from;
  final BusStop to;
  final BusLine line;
  final BusDirection direction;

  TransportConnection({
    required this.from,
    required this.to,
    required this.line,
    required this.direction,
  });
}