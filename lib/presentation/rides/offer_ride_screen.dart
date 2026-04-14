import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/ride_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/ride_model.dart';

const String _kGoogleApiKey = 'AIzaSyBqIfdzqfPN8JIcLkEaGObApnn5JKk-BZI';

// ── Small data class to hold a resolved location ──────────────────
class _ResolvedLocation {
  final String address;
  final LatLng latLng;
  const _ResolvedLocation({required this.address, required this.latLng});
}

class OfferRideScreen extends StatefulWidget {
  const OfferRideScreen({super.key});

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends State<OfferRideScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;
  bool _isLoading = false;

  // ── Map ───────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};
  bool _isLoadingRoute = false;

  // ── Resolved locations ────────────────────────────────────────────
  _ResolvedLocation? _startLocation;
  _ResolvedLocation? _endLocation;
  final List<_ResolvedLocation?> _stopLocations = []; // parallel to controllers

  // ── Step 1 text controllers ───────────────────────────────────────
  final _startController = TextEditingController();
  final _endController   = TextEditingController(text: '');
  final List<TextEditingController> _stopControllers = [];

  // ── Autocomplete state ────────────────────────────────────────────
  // 'start' | 'end' | 'stop_N'
  String? _activeField;
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  String _lastQuery = '';
  bool _isLoadingLocation = false;

  // ── Step 2 fields ─────────────────────────────────────────────────
  DateTime _departureTime = DateTime.now().add(const Duration(hours: 1));
  int _totalSeats = 3;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    // Pre-resolve the default end location
    _resolveAndSetEnd(_endController.text);
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _notesController.dispose();
    for (final c in _stopControllers) c.dispose();
    _debounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Get current location for start ───────────────────────────────
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final ll  = LatLng(pos.latitude, pos.longitude);

      final marks = await placemarkFromCoordinates(ll.latitude, ll.longitude);
      if (marks.isNotEmpty) {
        final p    = marks.first;
        final addr = '${p.street ?? ''}, ${p.subLocality ?? ''}, ${p.locality ?? ''}'
            .replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '');
        if (mounted) {
          setState(() {
            _startController.text = addr;
            _startLocation = _ResolvedLocation(address: addr, latLng: ll);
          });
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(ll, 13));
          _refreshMapMarkersAndRoute();
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // ── Pre-resolve default end location ─────────────────────────────
  Future<void> _resolveAndSetEnd(String address) async {
    try {
      final locs = await locationFromAddress(address).timeout(const Duration(seconds: 5));
      if (locs.isNotEmpty) {
        final ll = LatLng(locs.first.latitude, locs.first.longitude);
        if (mounted) {
          setState(() => _endLocation = _ResolvedLocation(address: address, latLng: ll));
          _refreshMapMarkersAndRoute();
        }
      }
    } catch (_) {}
  }

  // ── Text change → debounced autocomplete ─────────────────────────
  void _onFieldChanged(String query, String fieldKey) {
    _debounce?.cancel();
    setState(() {
      _activeField  = fieldKey;
      _lastQuery    = query;
      if (query.trim().length < 2) {
        _suggestions = [];
        return;
      }
    });
    if (query.trim().length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (_lastQuery == query) _fetchSuggestions(query, fieldKey);
    });
  }

  Future<void> _fetchSuggestions(String query, String fieldKey) async {
    if (!mounted) return;
    List<Map<String, dynamic>> results = [];

    // Google Places Autocomplete
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&key=$_kGoogleApiKey'
        '&language=en'
        '&types=geocode',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data        = jsonDecode(resp.body) as Map<String, dynamic>;
        final status      = data['status'] as String? ?? '';
        final predictions = data['predictions'] as List<dynamic>? ?? [];
        if (status == 'OK' && predictions.isNotEmpty) {
          for (final pred in predictions.take(5)) {
            results.add({
              'name':    pred['description'] as String,
              'placeId': pred['place_id']   as String?,
            });
          }
        }
      }
    } catch (_) {}

    // Geocoding fallback
    if (results.isEmpty) {
      try {
        final locs = await locationFromAddress(query).timeout(const Duration(seconds: 4));
        for (final loc in locs.take(5)) {
          final marks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
          if (marks.isNotEmpty) {
            final p    = marks.first;
            final name = [p.name, p.locality, p.administrativeArea]
                .where((s) => s != null && s.isNotEmpty).join(', ');
            results.add({'name': name.isEmpty ? query : name, 'placeId': null,
                         'lat': loc.latitude, 'lng': loc.longitude});
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    if (_lastQuery != query || _activeField != fieldKey) return;
    setState(() => _suggestions = results);
  }

  Future<LatLng?> _resolvePlaceId(String placeId) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId&fields=geometry&key=$_kGoogleApiKey',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final loc  = data['result']?['geometry']?['location'];
        if (loc != null) {
          return LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _selectSuggestion(Map<String, dynamic> s) async {
    final fieldKey = _activeField!;
    final name     = s['name'] as String;

    // Immediately hide suggestions
    setState(() {
      _suggestions = [];
      _activeField = null;
    });

    // Resolve LatLng
    LatLng? ll;
    if (s['placeId'] != null) ll = await _resolvePlaceId(s['placeId'] as String);
    if (ll == null && s['lat'] != null) ll = LatLng(s['lat'] as double, s['lng'] as double);
    if (ll == null || !mounted) return;

    final resolved = _ResolvedLocation(address: name, latLng: ll);

    setState(() {
      if (fieldKey == 'start') {
        _startController.text = name;
        _startLocation = resolved;
      } else if (fieldKey == 'end') {
        _endController.text = name;
        _endLocation = resolved;
      } else if (fieldKey.startsWith('stop_')) {
        final idx = int.tryParse(fieldKey.split('_')[1]);
        if (idx != null && idx < _stopControllers.length) {
          _stopControllers[idx].text = name;
          while (_stopLocations.length <= idx) _stopLocations.add(null);
          _stopLocations[idx] = resolved;
        }
      }
    });

    _refreshMapMarkersAndRoute();
  }

  // ── Rebuild markers + polyline whenever locations change ──────────
  Future<void> _refreshMapMarkersAndRoute() async {
    final newMarkers = <Marker>{};

    if (_startLocation != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('start'),
        position: _startLocation!.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Start', snippet: _startLocation!.address),
      ));
    }

    for (int i = 0; i < _stopLocations.length; i++) {
      final stop = _stopLocations[i];
      if (stop != null) {
        newMarkers.add(Marker(
          markerId: MarkerId('stop_$i'),
          position: stop.latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: 'Stop ${i + 1}', snippet: stop.address),
        ));
      }
    }

    if (_endLocation != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('end'),
        position: _endLocation!.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'End', snippet: _endLocation!.address),
      ));
    }

    setState(() => _markers = newMarkers);

    // Draw route if at least start + end are known
    if (_startLocation != null && _endLocation != null) {
      await _drawRoute();
    } else if (_startLocation != null) {
      _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_startLocation!.latLng, 13));
    }
  }

  Future<void> _drawRoute() async {
    if (_startLocation == null || _endLocation == null) return;
    setState(() => _isLoadingRoute = true);

    // Build waypoints from resolved stops
    final waypoints = _stopLocations
        .whereType<_ResolvedLocation>()
        .map((s) => '${s.latLng.latitude},${s.latLng.longitude}')
        .join('|');

    try {
      final waypointParam = waypoints.isNotEmpty ? '&waypoints=$waypoints' : '';
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${_startLocation!.latLng.latitude},${_startLocation!.latLng.longitude}'
        '&destination=${_endLocation!.latLng.latitude},${_endLocation!.latLng.longitude}'
        '$waypointParam'
        '&key=$_kGoogleApiKey',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data   = jsonDecode(resp.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final points  = routes[0]['overview_polyline']['points'] as String;
          final decoded = _decodePolyline(points);
          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: decoded,
                color: AppTheme.primary,
                width: 5,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              ),
            };
          });
          _fitRouteOnMap(decoded);
        }
      }
    } catch (_) {
      // Fallback: straight line
      final allPoints = [
        _startLocation!.latLng,
        ..._stopLocations.whereType<_ResolvedLocation>().map((s) => s.latLng),
        _endLocation!.latLng,
      ];
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: allPoints,
            color: AppTheme.primary,
            width: 5,
          ),
        };
      });
      _fitRouteOnMap(allPoints);
    } finally {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  void _fitRouteOnMap(List<LatLng> points) {
    if (points.isEmpty) return;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude  < minLat) minLat = p.latitude;
      if (p.latitude  > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      80,
    ));
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> pts = [];
    int idx = 0, lat = 0, lng = 0;
    while (idx < encoded.length) {
      int shift = 0, res = 0, b;
      do { b = encoded.codeUnitAt(idx++) - 63; res |= (b & 0x1F) << shift; shift += 5; } while (b >= 0x20);
      lat += (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
      shift = 0; res = 0;
      do { b = encoded.codeUnitAt(idx++) - 63; res |= (b & 0x1F) << shift; shift += 5; } while (b >= 0x20);
      lng += (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
      pts.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return pts;
  }

  // ── Date/time picker ──────────────────────────────────────────────
  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departureTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departureTime),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
        child: child!,
      ),
    );
    if (time == null) return;

    setState(() {
      _departureTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  // ── Publish to backend ────────────────────────────────────────────
  Future<void> _publishRide() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService().getCurrentUserProfile();
      if (user == null) throw Exception('User not found');

      // Build stops list from resolved locations
      final stops = <LocationPoint>[];
      for (int i = 0; i < _stopControllers.length; i++) {
        final text = _stopControllers[i].text.trim();
        if (text.isEmpty) continue;
        final loc = i < _stopLocations.length ? _stopLocations[i] : null;
        stops.add(LocationPoint(
          address: text,
          lat: loc?.latLng.latitude  ?? 0,
          lng: loc?.latLng.longitude ?? 0,
        ));
      }

      final ride = RideModel(
        id: '',
        driverId:     user.uid,
        driverName:   user.name,
        driverPhoto:  user.photoUrl,
        driverRating: user.rating,
        startPoint: LocationPoint(
          address: _startController.text.trim(),
          lat: _startLocation?.latLng.latitude  ?? 0,
          lng: _startLocation?.latLng.longitude ?? 0,
        ),
        endPoint: LocationPoint(
          address: _endController.text.trim(),
          lat: _endLocation?.latLng.latitude  ?? 0,
          lng: _endLocation?.latLng.longitude ?? 0,
        ),
        stops:          stops,
        departureTime:  _departureTime,
        totalSeats:     _totalSeats,
        availableSeats: _totalSeats,
        status:         'upcoming',
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      final rideId = await RideService().createRide(ride);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride published successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.push('/ride/$rideId/requests');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // ── Step 1: Route setup with map ─────────────────────────────────
  // ─────────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Map preview card
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _startLocation?.latLng ?? const LatLng(31.5204, 74.3587),
                    zoom: 13,
                  ),
                  onMapCreated: (c) {
                    _mapController = c;
                    if (_startLocation != null) {
                      c.animateCamera(CameraUpdate.newLatLngZoom(_startLocation!.latLng, 13));
                    }
                  },
                  markers:          _markers,
                  polylines:        _polylines,
                  zoomControlsEnabled:   false,
                  mapToolbarEnabled:     false,
                  myLocationEnabled:     true,
                  myLocationButtonEnabled: false,
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled:   true,
                ),
                // Route loading overlay
                if (_isLoadingRoute)
                  Positioned(
                    bottom: 12, left: 0, right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 8)],
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(width: 12, height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                          SizedBox(width: 8),
                          Text('Drawing route...', style: TextStyle(fontSize: 11)),
                        ]),
                      ),
                    ),
                  ),
                // My location FAB
                Positioned(
                  right: 10, top: 10,
                  child: GestureDetector(
                    onTap: _getCurrentLocation,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: _isLoadingLocation
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                          : const Icon(Icons.my_location, color: AppTheme.primary, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ── Start location ──────────────────────────────────────────
        _FieldLabel(label: 'Start Location', icon: Icons.radio_button_checked, color: AppTheme.success),
        const SizedBox(height: 8),
        _LocationInputField(
          controller: _startController,
          hint: 'Your starting point',
          onChanged: (q) => _onFieldChanged(q, 'start'),
          trailing: IconButton(
            icon: const Icon(Icons.my_location, size: 18, color: AppTheme.primary),
            onPressed: _getCurrentLocation,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Start location required' : null,
        ),
        if (_activeField == 'start' && _suggestions.isNotEmpty)
          _SuggestionDropdown(
            suggestions: _suggestions,
            onSelect: _selectSuggestion,
          ),

        const SizedBox(height: 16),

        // ── Intermediate stops ──────────────────────────────────────
        if (_stopControllers.isNotEmpty) ...[
          _FieldLabel(label: 'Stops (optional)', icon: Icons.add_location_alt_outlined, color: AppTheme.textLight),
          const SizedBox(height: 8),
          ..._stopControllers.asMap().entries.map((e) {
            final i      = e.key;
            final stopKey = 'stop_$i';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _LocationInputField(
                          controller: e.value,
                          hint: 'Stop ${i + 1}',
                          onChanged: (q) => _onFieldChanged(q, stopKey),
                          validator: null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() {
                          e.value.dispose();
                          _stopControllers.removeAt(i);
                          if (i < _stopLocations.length) _stopLocations.removeAt(i);
                          _refreshMapMarkersAndRoute();
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.close, color: AppTheme.error, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_activeField == stopKey && _suggestions.isNotEmpty)
                  _SuggestionDropdown(
                    suggestions: _suggestions,
                    onSelect: _selectSuggestion,
                  ),
              ],
            );
          }),
          const SizedBox(height: 4),
        ],

        TextButton.icon(
          onPressed: _stopControllers.length < 3
              ? () => setState(() {
                  _stopControllers.add(TextEditingController());
                  _stopLocations.add(null);
                })
              : null,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add a stop'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
        ),

        const SizedBox(height: 8),

        // ── End location ────────────────────────────────────────────
        _FieldLabel(label: 'End Location', icon: Icons.location_on, color: AppTheme.error),
        const SizedBox(height: 8),
        _LocationInputField(
          controller: _endController,
          hint: 'Destination',
          onChanged: (q) => _onFieldChanged(q, 'end'),
          validator: (v) => v == null || v.isEmpty ? 'End location required' : null,
        ),
        if (_activeField == 'end' && _suggestions.isNotEmpty)
          _SuggestionDropdown(
            suggestions: _suggestions,
            onSelect: _selectSuggestion,
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // ── Step 2: Ride details ──────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Departure Time',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDateTime,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('EEE, MMM d • h:mm a').format(_departureTime),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textDark),
                  ),
                ),
                const Icon(Icons.edit_outlined, color: AppTheme.textLight, size: 18),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        const Text('Available Seats',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SeatButton(
              icon: Icons.remove,
              onTap: _totalSeats > 1 ? () => setState(() => _totalSeats--) : null,
            ),
            const SizedBox(width: 28),
            Column(children: [
              Text('$_totalSeats',
                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: AppTheme.primary)),
              const Text('seats', style: TextStyle(color: AppTheme.textMedium, fontSize: 13)),
            ]),
            const SizedBox(width: 28),
            _SeatButton(
              icon: Icons.add,
              onTap: _totalSeats < 6 ? () => setState(() => _totalSeats++) : null,
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Text('Notes (optional)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'e.g. I can pick up from nearby streets, no pets please...',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // ── Step 3: Review ────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────
  Widget _buildReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mini map showing final route
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 180,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _startLocation?.latLng ?? const LatLng(31.5204, 74.3587),
                zoom: 12,
              ),
              onMapCreated: (c) {
                _mapController = c;
                if (_polylines.isNotEmpty) {
                  final pts = _polylines.first.points;
                  if (pts.isNotEmpty) _fitRouteOnMap(pts);
                }
              },
              markers:               _markers,
              polylines:             _polylines,
              zoomControlsEnabled:   false,
              mapToolbarEnabled:     false,
              myLocationEnabled:     false,
              myLocationButtonEnabled: false,
              scrollGesturesEnabled: false,
              zoomGesturesEnabled:   false,
            ),
          ),
        ),

        const SizedBox(height: 20),
        const Text('Review your ride',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        const SizedBox(height: 16),

        _ReviewRow(label: 'From', value: _startController.text),
        if (_stopControllers.any((c) => c.text.isNotEmpty))
          _ReviewRow(
            label: 'Stops',
            value: _stopControllers.where((c) => c.text.isNotEmpty).map((c) => c.text).join(', '),
          ),
        _ReviewRow(label: 'To', value: _endController.text),
        _ReviewRow(label: 'Departure', value: DateFormat('EEE, MMM d • h:mm a').format(_departureTime)),
        _ReviewRow(label: 'Seats', value: '$_totalSeats seats available'),
        if (_notesController.text.isNotEmpty)
          _ReviewRow(label: 'Notes', value: _notesController.text),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Once published, colleagues can find and book your ride. You can manage requests from the ride page.',
                style: TextStyle(fontSize: 12, color: AppTheme.primary, height: 1.5),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final stepLabels = ['Set Route', 'Ride Details', 'Review & Publish'];

    return GestureDetector(
      // Tap anywhere outside a field hides suggestions
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() { _activeField = null; _suggestions = []; });
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(
          title: Text(stepLabels[_step]),
          leading: _step > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  onPressed: () => setState(() => _step--),
                )
              : null,
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              // Step progress bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: List.generate(3, (i) => Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _step ? AppTheme.primary : AppTheme.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  )),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _step == 0
                      ? _buildStep1()
                      : _step == 1
                          ? _buildStep2()
                          : _buildReview(),
                ),
              ),

              // Bottom action button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () {
                      if (_step < 2) {
                        if (_formKey.currentState!.validate()) {
                          setState(() {
                            _activeField = null;
                            _suggestions = [];
                            _step++;
                          });
                        }
                      } else {
                        _publishRide();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(
                            _step < 2 ? 'Continue' : 'Publish Ride',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable field label with icon ────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _FieldLabel({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
    ]);
  }
}

// ── Location input with consistent styling ────────────────────────
class _LocationInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String>? validator;
  final Widget? trailing;

  const _LocationInputField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.validator,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: AppTheme.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textLight, fontSize: 15),
        suffixIcon: trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ── Suggestions dropdown ──────────────────────────────────────────
class _SuggestionDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> suggestions;
  final ValueChanged<Map<String, dynamic>> onSelect;
  const _SuggestionDropdown({required this.suggestions, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: suggestions.asMap().entries.map((entry) {
          final i       = entry.key;
          final s       = entry.value;
          final isFirst = i == 0;
          final isLast  = i == suggestions.length - 1;
          return InkWell(
            onTap: () => onSelect(s),
            borderRadius: BorderRadius.only(
              topLeft:     Radius.circular(isFirst ? 12 : 0),
              topRight:    Radius.circular(isFirst ? 12 : 0),
              bottomLeft:  Radius.circular(isLast  ? 12 : 0),
              bottomRight: Radius.circular(isLast  ? 12 : 0),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: AppTheme.bgLight, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.location_on_outlined, size: 15, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(s['name'] as String,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Seat +/- button ───────────────────────────────────────────────
class _SeatButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _SeatButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: onTap != null ? AppTheme.primaryLight : AppTheme.bgLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: onTap != null ? AppTheme.primary : AppTheme.border),
        ),
        child: Icon(icon, color: onTap != null ? AppTheme.primary : AppTheme.textLight, size: 22),
      ),
    );
  }
}

// ── Review row ────────────────────────────────────────────────────
class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMedium)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
            ),
          ],
        ),
      ),
    );
  }
}