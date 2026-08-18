import 'bus_line.dart';
import 'bus_stop.dart';

enum RouteInstructionType {
  walking,
  boardBus,
  stayOnBus,
  getOffBus,
}

class RouteInstruction {
  final RouteInstructionType type;

  final BusLine? line;
  final String? direction;

  final BusStop? stop;
  final BusStop? fromStop;
  final BusStop? toStop;

  RouteInstruction({
    required this.type,
    this.line,
    this.direction,
    this.stop,
    this.fromStop,
    this.toStop,
  });
}