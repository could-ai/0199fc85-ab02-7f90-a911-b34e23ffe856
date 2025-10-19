import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

// Mock data for radar locations in Brazil.
// In a real app, this would be fetched from an API like www.aze.com.br.
const List<LatLng> radarLocations = [
  LatLng(-23.5505, -46.6333), // São Paulo
  LatLng(-22.9068, -43.1729), // Rio de Janeiro
  LatLng(-15.7801, -47.9292), // Brasília
  LatLng(-12.9714, -38.5014), // Salvador
];

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isNearRadar = false;
  StreamSubscription<Position>? _positionStream;

  final Set<Marker> _radarMarkers = {};

  // Initial camera position (centered on Brazil)
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(-14.2350, -51.9253),
    zoom: 4,
  );

  @override
  void initState() {
    super.initState();
    _setupRadars();
    _determinePosition();
  }

  void _setupRadars() {
    for (var i = 0; i < radarLocations.length; i++) {
      _radarMarkers.add(
        Marker(
          markerId: MarkerId('radar_$i'),
          position: radarLocations[i],
          infoWindow: const InfoWindow(title: 'Radar de Velocidade'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, don't continue.
      // In a real app, you'd want to prompt the user to enable them.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    _currentPosition = await Geolocator.getCurrentPosition();
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 15,
          ),
        ),
      );
    }
    setState(() {});

    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters.
    );
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
      _checkProximity();
    });
  }

  void _checkProximity() {
    if (_currentPosition == null) return;

    bool foundNearRadar = false;
    for (final radar in radarLocations) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        radar.latitude,
        radar.longitude,
      );

      // Trigger alert if within 500 meters
      if (distance < 500) {
        foundNearRadar = true;
        break;
      }
    }

    if (_isNearRadar != foundNearRadar) {
      setState(() {
        _isNearRadar = foundNearRadar;
      });
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerta de Radar'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: _initialCameraPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _radarMarkers,
            zoomControlsEnabled: false,
          ),
          if (_isNearRadar)
            Container(
              color: Colors.red.withOpacity(0.5),
              child: const Center(
                child: Text(
                  'RADAR À FRENTE!',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
