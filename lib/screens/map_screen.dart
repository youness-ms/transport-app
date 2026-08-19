import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math' as math;
import '../models/famous_place.dart';
import 'ai_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:transport/models/bus_direction.dart';
import 'package:transport/models/bus_line.dart';
import 'package:transport/models/bus_stop.dart';
import 'package:transport/widgets/current_location_button.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:transport/models/bus_line.dart';
import '../widgets/current_location_button.dart';
import '../models/bus_stop.dart';
import '../models/bus_line.dart';
import '../models/bus_direction.dart';
import 'package:transport/services/transport_data_service.dart';
import '../services/route_planner.dart';
import 'package:transport/models/route_instruction.dart';
import '../models/journey.dart';



class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}


class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {

  Position? position;
  String? locationError;
  bool openedLocationSettings = false;
  BusStop? selectedStop;
  BusLine? selectedLine;
  BusDirection? selectedDirection;
  StreamSubscription<Position>? positionSubscription;

  StreamSubscription<MagnetometerEvent>? magnetometerSubscription;
  double compassHeading = 0;

  final TextEditingController searchController = TextEditingController();
  List<BusStop> searchResults = [];
  final FocusNode searchFocusNode = FocusNode();
  List<BusLine> loadedLines = [];
  List<BusStop> loadedStops = [];
  LatLng? destinationPoint;
  Journey? selectedJourney;
  Set<String> transferStopNames = {};
  bool isRerouting = false;

  static const double offRouteDistance = 60;
  bool journeyCardOpen = false;


  final MapController mapController = MapController();
  List<Widget> _buildJourneyTimeline(Journey journey) {
    final widgets = <Widget>[];

    for (int i = 0; i < journey.segments.length; i++) {
      final segment = journey.segments[i];

      // =========================
      // WALKING
      // =========================
      if (segment is WalkingSegment) {
        widgets.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.directions_walk,
              color: Colors.green,
            ),
            title: const Text(
              'Walk',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Walk to the next stop',
            ),
          ),
        );

        continue;
      }

      // =========================
      // BUS
      // =========================
      if (segment is TransportSegment) {
        widgets.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.directions_bus,
              color: Colors.blue,
            ),
            title: Text(
              segment.line.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${segment.fromStop.name} → '
                  '${segment.toStop.name}',
            ),
          ),
        );

        // Check whether the next transport segment
        // means the passenger changes buses.
        if (i + 1 < journey.segments.length &&
            journey.segments[i + 1] is TransportSegment) {
          final next =
          journey.segments[i + 1] as TransportSegment;

          if (next.fromStop.name ==
              segment.toStop.name) {
            widgets.add(
              const Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  top: 4,
                  bottom: 4,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.swap_horiz,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Change bus here',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }
      }
    }

    widgets.add(
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.location_on,
          color: Colors.red,
        ),
        title: Text(
          'Destination',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    return widgets;
  }

  void updateTransferStops(Journey? journey) {
    final transfers = <String>{};

    if (journey == null) {
      transferStopNames = transfers;
      return;
    }

    final transportSegments =
    journey.segments.whereType<TransportSegment>().toList();

    for (int i = 0; i < transportSegments.length - 1; i++) {
      final current = transportSegments[i];
      final next = transportSegments[i + 1];

      if (current.toStop.name == next.fromStop.name) {
        transfers.add(current.toStop.name);
      }
    }

    transferStopNames = transfers;
  }
  double _getLocationHeading(Position position) {
    // GPS heading is more reliable while moving.
    if (position.speed > 1.0 &&
        position.heading.isFinite) {
      return position.heading;
    }

    // When standing still, use the compass.
    return compassHeading;
  }

  double distanceToJourney(LatLng location, Journey journey) {
    double closestDistance = double.infinity;

    for (final segment in journey.segments) {
      for (final point in segment.points) {
        final distance = const Distance().as(
          LengthUnit.Meter,
          location,
          point,
        );

        if (distance < closestDistance) {
          closestDistance = distance;
        }
      }
    }

    return closestDistance;
  }


  Future<void> updateRouteIfNeeded(
      LatLng newLocation,
      ) async {
    if (destinationPoint == null) return;

    if (selectedJourney == null) return;

    if (isRerouting) return;

    final distanceFromRoute = distanceToJourney(
      newLocation,
      selectedJourney!,
    );

    print(
      'Distance from route: '
          '${distanceFromRoute.toStringAsFixed(1)} m',
    );

    // We are still close enough to the route.
    if (distanceFromRoute <= offRouteDistance) {
      return;
    }

    // We are actually off the route.
    print('⚠️ OFF ROUTE — recalculating...');

    isRerouting = true;

    try {
      final journey = await calculateJourneyToPoint(
        destinationPoint!,
      );

      if (!mounted) return;

      if (journey != null) {
        setState(() {
          selectedJourney = journey;
          updateTransferStops(journey);
        });

        print('✅ Route recalculated');
      } else {
        print('❌ Could not find a new route');
      }
    } finally {
      isRerouting = false;
    }
  }


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadLocation();
    loadTransportData();
    positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      ),
    ).listen((Position position) {
      if (!mounted) return;

      setState(() {
        this.position = position;
      });
      final currentLocation = LatLng(
        position.latitude,
        position.longitude,
      );

      final nearbyStops = findNearbyStops(
        currentLocation,
        1000,
      );
      if (destinationPoint != null) {
        updateRouteIfNeeded(
          LatLng(
            position.latitude,
            position.longitude,
          ),
        );
      }


    });
    magnetometerSubscription =
        magnetometerEventStream().listen((MagnetometerEvent event) {
          if (!mounted) return;

          final heading = math.atan2(
            event.y,
            event.x,
          ) * 180 / math.pi;

          final normalizedHeading =
              (heading + 360) % 360;

          setState(() {
            compassHeading = normalizedHeading;
          });
        });
  }

  // routing

  Future<Journey?> calculateJourneyToPoint(
      LatLng destinationPoint,
      ) async {
    final planner = RoutePlanner(
      lines: loadedLines,
    );

    if (position == null) {
      print('Current location is not available');
      return null;
    }

    final startPoint = LatLng(
      position!.latitude,
      position!.longitude,
    );

    final nearbyStartStops = findNearbyStops(
      startPoint,
      1000,
    );

    final nearbyDestinationStops = findNearbyStops(
      destinationPoint,
      1000,
    );

    final route = planner.buildJourneyWithWalking(
      startPoint,
      destinationPoint,
      nearbyStartStops,
      nearbyDestinationStops,
    );

    if (route == null) {
      final walkingJourney = Journey(
        segments: [
          WalkingSegment(
            points: [
              startPoint,
              destinationPoint,
            ],
          ),
        ],
      );

      return await planner.addWalkingGeometry(
        walkingJourney,
      );
    }


    final journeyWithWalking =
    await planner.addWalkingGeometry(route);

    return journeyWithWalking;
  }

  // fitting the cammera on the route
  void fitJourneyOnMap(Journey journey) {
    final points = <LatLng>[];

    for (final segment in journey.segments) {
      points.addAll(segment.points);
    }

    if (points.length < 2) {
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);

    mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  void clearDestination() {
    setState(() {
      destinationPoint = null;
    });
  }
  //counting distance from bus stop to user
  List<BusStop> findNearbyStops(LatLng location, double maxDistance) {
    return loadedStops.where((stop) {
      final distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        stop.latitude,
        stop.longitude,
      );

      return distance <= maxDistance;
    }).toList();
  }

  List<Polyline<Object>> buildJourneyPolylines(Journey journey) {
    final polylines = <Polyline<Object>>[];

    for (int i = 0; i < journey.segments.length; i++) {
      final segment = journey.segments[i];

      // =========================
      // WALKING
      // =========================
      if (segment is WalkingSegment) {
        final walkingPoints = <LatLng>[
          ...segment.points,
        ];

        // Merge any immediately following walking segments.
        int j = i + 1;

        while (j < journey.segments.length &&
            journey.segments[j] is WalkingSegment) {
          final nextWalking =
          journey.segments[j] as WalkingSegment;

          if (nextWalking.points.isNotEmpty) {
            walkingPoints.addAll(
              nextWalking.points.skip(1),
            );
          }

          j++;
        }

        if (walkingPoints.length >= 2) {
          polylines.add(
            Polyline<Object>(
              points: walkingPoints,
              strokeWidth: 5,
              color: Colors.green,
            ),
          );
        }

        i = j - 1;
        continue;
      }

      // =========================
      // BUS
      // =========================
      if (segment is TransportSegment) {
        if (segment.points.length >= 2) {
          polylines.add(
            Polyline<Object>(
              points: segment.points,
              strokeWidth: 6,
              color: Colors.blue,
              pattern: StrokePattern.dashed(
                segments: [12, 8],
              ),
            ),
          );
        }
      }
    }

    return polylines;
  }



  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    positionSubscription?.cancel();
    magnetometerSubscription?.cancel();
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {

    if (state == AppLifecycleState.resumed && openedLocationSettings) {
      openedLocationSettings = false ;
      goToMyLocation();
    }

  }


  Future<void> loadLocation() async {
    try {
      Position pos = await LocationService.getCurrentLocation();

      setState(() {
        position = pos;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
          ),
        );
      }
    }
  }
  Future<void> loadTransportData() async {
    try {
      final lines = await TransportDataService.loadLines();

      if (!mounted) return;
      final Map<String, BusStop> stopsMap = {};
      for (final line in lines){
        for (final direction in line.directions){
          for (final stop in direction.stops){
            final String stopKey =
                '${stop.latitude.toStringAsFixed(6)},'
                '${stop.longitude.toStringAsFixed(6)}';

            stopsMap[stopKey] = stop;
          }
        }
      }
      setState(() {
        loadedLines = lines;
        loadedStops = stopsMap.values.toList();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load transport data: $e',
          ),
        ),
      );
    }
  }

  List<Polyline<Object>> buildSelectedLinePolylines() {
    if (selectedLine == null) {
      return [];
    }

    return selectedLine!.directions.map((direction) {
      return Polyline<Object>(
        points: direction.routePoints
            .map(
              (point) => LatLng(
            point.latitude,
            point.longitude,
          ),
        )
            .toList(),
        strokeWidth: 5,
        color: Colors.blue,
      );
    }).toList();
  }

  Future<void> goToMyLocation() async {

    try {
      Position pos =
      await LocationService.getCurrentLocation();

      setState(() {
        position = pos;
      });

      mapController.move(
        LatLng(
          pos.latitude,
          pos.longitude,
        ),
        16,
      );
    } catch (e) {
      if (e.toString().contains("GPS is disabled")) {
        showDialog(
          context: context,
          builder: (context) =>
              AlertDialog(
                title: const Text("Location is disabled"),
                content: const Text(
                  "Please turn on GPS to use your location.",
                ),
                actions: [

                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel"),
                  ),

                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      setState(() {
                        openedLocationSettings = true;
                      });
                      await Geolocator.openLocationSettings();
                    },
                    child: const Text("Open Settings"),
                  ),

                ],
              ),
        );
      } else if (e.toString().contains("permission")) {

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Location permission"),
            content: Text(
              e.toString(),
            ),
            actions: [

              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("OK"),
              ),

            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
          ),
        );
      }
    }
  }

  void goToRoute(BusDirection direction) {
    if (direction.routePoints.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(
      direction.routePoints,
    );

    mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: position != null
            ? LatLng(
              position!.latitude,
              position!.longitude,
            )
            : LatLng(35.18994, -0.63085),
            initialZoom: 16,
            onTap: (tapPosition, point) {
              setState(() {
                selectedLine = null;
                selectedDirection = null;
                selectedStop = null;
              });
            },
            onLongPress: (tapPosition, point) async {
              destinationPoint = point;

              final journey =
              await calculateJourneyToPoint(point);

              if (!mounted) return;

              setState(() {
                selectedJourney = journey;
                updateTransferStops(journey);
              });

              if (journey != null) {
                fitJourneyOnMap(journey);
              }
            },
          ),


          children: [

            TileLayer(
            urlTemplate:
            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

            userAgentPackageName:
            'com.example.transport_app',
          ),

            MarkerLayer(
              markers: [

                //user location
                if (position != null)
                  Marker(
                    key: ValueKey(
                      '${position!.latitude},${position!.longitude}',
                    ),
                    point: LatLng(
                      position!.latitude,
                      position!.longitude,
                    ),
                    width: 50,
                    height: 50,
                    child: Transform.rotate(
                      angle: _getLocationHeading(position!) * math.pi / 180,
                      child: const Icon(
                        Icons.navigation,
                        color: Colors.blue,
                        size: 42,
                      ),
                    ),
                  ),
                // bus stops
                  ...loadedStops.map(
                        (stop) {
                          return Marker(
                            point: LatLng(
                              stop.latitude,
                              stop.longitude,
                            ),
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: (){
                                setState(() {
                                  selectedStop = stop;
                                  selectedLine = null;
                                });
                              },


                              child: Icon(
                                Icons.directions_bus,
                                color: transferStopNames.contains(stop.name)
                                    ? Colors.orange
                                    : Colors.blue,
                                size: 35,
                              ),
                            ),
                          );
                  },
                  ),
                ...loadedPlaces.map(
                      (place) {
                    return Marker(
                      point: LatLng(
                        place.latitude,
                        place.longitude,
                      ),
                      width: 45,
                      height: 45,
                      child: GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) {
                              return SafeArea(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          place.name,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        const SizedBox(height: 8),

                                        Text(
                                          'ID: ${place.id}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),

                                        const SizedBox(height: 4),

                                        Text(
                                          place.category,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: const Icon(
                          Icons.place,
                          color: Colors.deepPurple,
                          size: 38,
                        ),
                      ),
                    );
                  },
                ),


                // Destination marker
                if (destinationPoint != null)
                  Marker(
                    point: destinationPoint!,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_on,
                      size: 50,
                      color: Colors.red,
                    ),
                  ),

                //selected line stops
                if (selectedDirection != null)
                  ...selectedDirection!.stops.map(
                      (stop) {
                        final isSelected = selectedStop == stop;
                        return Marker(
                          point: LatLng(
                              stop.latitude,
                              stop.longitude
                          ),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedStop =stop;

                              });
                            },
                            child: Icon(
                              Icons.location_on,
                              color: isSelected
                                ? Colors.red
                                : Colors.orange,
                              size: isSelected
                                ? 40
                                : 35,
                            ),
                          ),
                      );
                    }
                  ),
              ],
            ),

            PolylineLayer(
              polylines: [
                if (selectedJourney != null)
                  ...buildJourneyPolylines(selectedJourney!),

                ...buildSelectedLinePolylines(),
              ],
            ),

          ],
        ),
          if (selectedJourney != null &&
              selectedJourney!.segments.any(
                    (segment) => segment is TransportSegment,
              ) &&
              journeyCardOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: 200,
              child: DraggableScrollableSheet(
                initialChildSize: 0.35,
                minChildSize: 0.08,
                maxChildSize: 0.75,
                snap: true,
                snapSizes: const [0.08, 0.35, 0.75],
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 10,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        Center(
                          child: Container(
                            width: 45,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Your Journey',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  journeyCardOpen = false;
                                });
                              },
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.smart_toy),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AiScreen(
                                      onGoToPlace: (latitude, longitude) async {
                                        final destination = LatLng(
                                          latitude,
                                          longitude,
                                        );

                                        destinationPoint = destination;

                                        final journey =
                                        await calculateJourneyToPoint(
                                          destination,
                                        );

                                        if (!mounted) return;

                                        setState(() {
                                          selectedJourney = journey;
                                          updateTransferStops(journey);
                                        });

                                        if (journey != null) {
                                          fitJourneyOnMap(journey);
                                        }

                                        Navigator.pop(context);
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 15),

                        ..._buildJourneyTimeline(selectedJourney!),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (selectedJourney != null &&
              selectedJourney!.segments.any(
                    (segment) => segment is TransportSegment,
              ) &&
              !journeyCardOpen)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    journeyCardOpen = true;
                  });
                },
                icon: const Icon(Icons.directions),
                label: const Text('Show journey'),
              ),
            ),
          // SEARCH BUTTON
          Positioned(
            top: 20,
            left: 20,
            right: 20,

            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(15),

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  // SEARCH FIELD
                  TextField(
                    controller: searchController,
                    focusNode: searchFocusNode,
                    onTap: () {
                      searchFocusNode.requestFocus();
                    },

                    onChanged: (value) {
                      setState(() {
                        if (value.trim().isEmpty) {
                          searchResults = [];
                        } else {
                          searchResults = loadedStops.where(
                                (stop) => stop.name.toLowerCase().contains(
                              value.toLowerCase().trim(),
                            ),
                          ).toList();
                        }
                      });
                    },

                    decoration: InputDecoration(
                      hintText: "Search bus stop...",
                      prefixIcon: const Icon(Icons.search),

                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          searchController.clear();

                          setState(() {
                            searchResults = [];
                          });

                          searchFocusNode.unfocus();
                        },
                      )
                          : null,

                      filled: true,
                      fillColor: Colors.white,

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  // SEARCH RESULTS
                  ...searchResults.map(
                        (stop) => ListTile(
                      leading: const Icon(
                        Icons.directions_bus,
                      ),

                      title: Text(stop.name),

                      onTap: () {
                        setState(() {
                          selectedStop = stop;
                          selectedLine = null;
                          selectedDirection = null;
                          searchResults = [];
                        });

                        searchController.clear();
                        searchFocusNode.unfocus();

                        mapController.move(
                          LatLng(
                            stop.latitude - 0.002,
                            stop.longitude,
                          ),
                          17,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),


          // LOCATION BUTTON
          Positioned(
            right: 20,
            bottom: selectedStop != null ? 320 : 20,
            child: LocationButton(
              onPressed: () {
                goToMyLocation();
              },
            ),
          ),
          if (destinationPoint != null)
            Positioned(
              right: 16,
              bottom: 100,
              child: FloatingActionButton(
                onPressed: (){
                  clearDestination();
                  selectedJourney = null;
                  isRerouting = false;
                  selectedLine = null;
                },
                child: const Icon(Icons.clear),
              ),
            ),

          // INFO CARD
          if (selectedStop != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),

                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      15,
                    ),

                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [

                        // Drag handle
                        Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),

                        const SizedBox(height: 15),

                        // Stop name
                        Row(
                          children: [
                            const Icon(
                              Icons.directions_bus,
                              size: 30,
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Text(
                                selectedStop!.name,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // Close button
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  selectedStop = null;
                                  selectedLine = null;
                                  selectedDirection = null;
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Content
                          // Content
                          Expanded(
                            child: ListView(
                              children: selectedLine == null
                                  ? selectedStop!.lines.map(
                                    (line) => ListTile(
                                  contentPadding: EdgeInsets.zero,

                                  leading: const Icon(
                                    Icons.directions_bus,
                                  ),

                                  title: Text(
                                    line.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    line.directions
                                        .map((direction) => "→ ${direction.destination}")
                                        .join("   •   "),
                                    ),

                                  trailing: const Icon(
                                    Icons.chevron_right,
                                  ),

                                  onTap: () {
                                    print("LINE: ${line.name}");
                                    print("DIRECTIONS: ${line.directions.length}");
                                    setState(() {
                                      selectedLine = line;
                                      selectedDirection = null;
                                    });
                                  },
                                ),
                              ).toList()

                                  : selectedDirection == null
                                  ? [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,

                                  leading: const Icon(
                                    Icons.arrow_back,
                                  ),

                                  title: const Text(
                                    "Back to lines",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  onTap: () {
                                    setState(() {
                                      selectedLine = null;
                                    });
                                  },
                                ),

                                const Divider(),

                                const ListTile(
                                  contentPadding: EdgeInsets.zero,

                                  title: Text(
                                    "Choose destination",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                ...selectedLine!.directions.map(
                                      (direction) => ListTile(
                                    contentPadding: EdgeInsets.zero,

                                    leading: const Icon(
                                      Icons.directions_bus,
                                    ),

                                    title: Text(
                                      "→ ${direction.destination}",
                                    ),

                                    trailing: const Icon(
                                      Icons.chevron_right,
                                    ),

                                    onTap: () {
                                      setState(() {
                                        selectedDirection = direction;
                                      });

                                      goToRoute(direction);
                                    },
                                  ),
                                ),
                              ]

                                  : [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,

                                  leading: const Icon(
                                    Icons.arrow_back,
                                  ),

                                  title: Text(
                                    "→ ${selectedDirection!.destination}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  onTap: () {
                                    setState(() {
                                      selectedDirection = null;
                                    });
                                  },
                                ),

                                const Divider(),

                                ...selectedDirection!.stops.asMap().entries.map(
                                      (entry) {
                                    final index = entry.key;
                                    final stop = entry.value;

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,

                                      leading: CircleAvatar(
                                        radius: 16,
                                        child: Text(
                                          '${index + 1}',
                                        ),
                                      ),

                                      title: Text(
                                        stop.name,
                                        style: TextStyle(
                                          fontWeight: selectedStop == stop
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),

                                      trailing: selectedStop == stop
                                          ? const Icon(
                                        Icons.location_on,
                                        color: Colors.red,
                                      )
                                          : null,

                                      onTap: () {
                                        setState(() {
                                          selectedStop = stop;
                                        });

                                        mapController.move(
                                          LatLng(
                                            stop.latitude - 0.002,
                                            stop.longitude,
                                          ),
                                          17,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            )
        ],
      ),

    );
  }
}