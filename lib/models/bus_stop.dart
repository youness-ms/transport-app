import 'package:transport/models/bus_line.dart';
import 'bus_line.dart';


class BusStop {
  final String name;
  final double latitude;
  final double longitude;
  final List<BusLine> lines;
  BusStop({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.lines,
  });
}