import 'package:latlong2/latlong.dart';
import 'bus_line.dart';
import 'bus_direction.dart';
import 'bus_stop.dart';

class Journey {
  final List<JourneySegment> segments;

  Journey({
    required this.segments,
  });
}

abstract class JourneySegment {
  final List<LatLng> points;

  JourneySegment({
    required this.points,
  });
}
class WalkingSegment extends JourneySegment {
  WalkingSegment({
    required super.points,
  });
}
class TransportSegment extends JourneySegment {
  final BusLine line;
  final BusDirection direction;
  final BusStop fromStop;
  final BusStop toStop;

  TransportSegment({
    required this.line,
    required this.direction,
    required this.fromStop,
    required this.toStop,
    required super.points,
  });
}
class TransferSegment extends JourneySegment {
  final BusStop stop;

  TransferSegment({
    required this.stop,
    required super.points,
  });
}