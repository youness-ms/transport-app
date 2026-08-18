import 'bus_direction.dart';
import 'bus_line.dart';
import 'bus_stop.dart';

class RouteState {
  final BusStop stop;
  final BusLine? line;
  final BusDirection? direction;

  RouteState({
    required this.stop,
    this.line,
    this.direction,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! RouteState) {
      return false;
    }

    return stop == other.stop &&
        line == other.line &&
        direction == other.direction;
  }

  @override
  int get hashCode {
    return Object.hash(
      stop,
      line,
      direction,
    );
  }
}