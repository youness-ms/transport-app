import 'package:latlong2/latlong.dart';
import 'bus_stop.dart';

class BusDirection {
  final String destination;
  final List<BusStop> stops;
  final List<LatLng> routePoints;
  BusDirection({
    required this.destination,
    required this.stops,
    required this.routePoints,
});
}
