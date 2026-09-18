import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class DeliveryLocationData {
  const DeliveryLocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.landmark,
    required this.instructions,
    required this.contactless,
  });

  final double latitude;
  final double longitude;
  final String address;
  final String landmark;
  final String instructions;
  final bool contactless;

  Map<String, dynamic> toJson() => {
    'delivery_latitude': latitude,
    'delivery_longitude': longitude,
    'delivery_address': address,
    'delivery_landmark': landmark,
    'delivery_instructions': instructions,
    'contactless_delivery': contactless,
  };
}

class DeliveryLocationPage extends StatefulWidget {
  const DeliveryLocationPage({
    super.key,
    required this.initialAddress,
    this.initialLocation,
  });

  final String initialAddress;
  final DeliveryLocationData? initialLocation;

  @override
  State<DeliveryLocationPage> createState() => _DeliveryLocationPageState();
}

class _DeliveryLocationPageState extends State<DeliveryLocationPage> {
  static const LatLng _kandy = LatLng(7.2906, 80.6337);
  static const String _packageName = 'com.supermart.supermart_flutter';
  static const String _tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  final Geocoding _geocoding = Geocoding();
  final MapController mapController = MapController();
  final GlobalKey<DragMarkerWidgetState> doorstepMarkerKey =
      GlobalKey<DragMarkerWidgetState>();
  final address = TextEditingController();
  final landmark = TextEditingController();
  final instructions = TextEditingController();

  LatLng? selected;
  bool contactless = false;
  bool locating = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final existing = widget.initialLocation;
    address.text = existing?.address ?? widget.initialAddress;
    landmark.text = existing?.landmark ?? '';
    instructions.text = existing?.instructions ?? '';
    contactless = existing?.contactless ?? false;
    selected = existing == null
        ? null
        : LatLng(existing.latitude, existing.longitude);
  }

  @override
  void dispose() {
    address.dispose();
    landmark.dispose();
    instructions.dispose();
    mapController.dispose();
    super.dispose();
  }

  Future<void> useCurrentLocation() async {
    setState(() {
      locating = true;
      error = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Turn on GPS/location services and try again.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission is required for doorstep delivery.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Enable it from phone settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
      await selectPoint(point, moveCamera: true);
    } catch (exception) {
      if (mounted) {
        setState(
          () => error = exception.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> selectPoint(LatLng point, {bool moveCamera = false}) async {
    setState(() {
      selected = point;
      error = null;
    });

    if (moveCamera) {
      mapController.move(point, 17);
    }
    await reverseGeocode(point);
  }

  Future<void> reverseGeocode(LatLng point) async {
    if (kIsWeb) return;
    try {
      final places = await _geocoding.placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (places.isEmpty || !mounted) return;

      final place = places.first;
      final parts = <String?>[
        place.subThoroughfare,
        place.thoroughfare,
        place.subLocality,
        place.locality,
        place.administrativeArea,
        place.postalCode,
      ].where((part) => part != null && part.trim().isNotEmpty).cast<String>();

      if (parts.isNotEmpty) {
        setState(() => address.text = parts.join(', '));
      }
    } catch (_) {
      // The customer can type the address manually if reverse geocoding fails.
    }
  }

  void save() {
    if (selected == null) {
      setState(() => error = 'Tap the map or use your current GPS location.');
      return;
    }
    if (address.text.trim().isEmpty) {
      setState(() => error = 'Enter the delivery address.');
      return;
    }

    Navigator.pop(
      context,
      DeliveryLocationData(
        latitude: selected!.latitude,
        longitude: selected!.longitude,
        address: address.text.trim(),
        landmark: landmark.text.trim(),
        instructions: instructions.text.trim(),
        contactless: contactless,
      ),
    );
  }

  Future<void> openOsmCopyright() async {
    await launchUrl(
      Uri.parse('https://www.openstreetmap.org/copyright'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = selected ?? _kandy;

    return Scaffold(
      appBar: AppBar(title: const Text('Doorstep delivery location')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 330,
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: target,
                  initialZoom: selected == null ? 14 : 17,
                  minZoom: 4,
                  maxZoom: 19,
                  onTap: (_, point) => selectPoint(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate: _tileUrl,
                    userAgentPackageName: _packageName,
                    maxZoom: 19,
                  ),
                  if (selected != null)
                    DragMarkers(
                      alignment: Alignment.topCenter,
                      markers: [
                        DragMarker(
                          key: doorstepMarkerKey,
                          point: selected!,
                          size: const Size.square(58),
                          offset: const Offset(0, -22),
                          dragOffset: const Offset(0, -34),
                          scrollMapNearEdge: true,
                          builder: (_, __, isDragging) => Icon(
                            isDragging
                                ? Icons.edit_location_alt
                                : Icons.location_on,
                            size: isDragging ? 58 : 52,
                            color: const Color(0xffc62828),
                            shadows: const [
                              Shadow(
                                blurRadius: 5,
                                color: Colors.black38,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          onDragEnd: (_, point) => selectPoint(point),
                        ),
                      ],
                    ),
                  SimpleAttributionWidget(
                    source: const Text('OpenStreetMap contributors'),
                    onTap: openOsmCopyright,
                    backgroundColor: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: locating ? null : useCurrentLocation,
            icon: locating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(
              locating ? 'Finding your location…' : 'Use my current location',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the map or drag the red pin to your exact gate or doorstep.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: address,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Full delivery address',
              prefixIcon: Icon(Icons.home_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: landmark,
            decoration: const InputDecoration(
              labelText: 'Nearby landmark',
              hintText: 'Blue gate, near mosque, opposite school',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: instructions,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Delivery instructions',
              hintText: 'Call when arriving or leave at the front gate',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: contactless,
            onChanged: (value) => setState(() => contactless = value),
            title: const Text('Contactless delivery'),
            subtitle: const Text(
              'The rider can leave the order at your selected location.',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.check_circle_outline),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Confirm delivery location'),
            ),
          ),
        ],
      ),
    );
  }
}
