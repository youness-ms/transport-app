import 'package:geolocator/geolocator.dart';

class LocationService {

  static Future<Position> getCurrentLocation() async {

    bool enabled =
    await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      throw Exception("GPS is disabled");
    }


    LocationPermission permission =
    await Geolocator.checkPermission();


    if (permission == LocationPermission.denied) {

      permission =
      await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied");
      }
    }


    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();

      throw Exception(
          "Location permission permanently denied. Enable it from settings."
      );
    }


    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }
}