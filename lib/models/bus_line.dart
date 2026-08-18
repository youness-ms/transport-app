import 'bus_direction.dart';
import 'transport_type.dart';
class BusLine {

  final String name;
  final TransportType type;
  final List<BusDirection> directions;

  BusLine({
    required this.name,
    required this.type,
    required this.directions,
  });
}