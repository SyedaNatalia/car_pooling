import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snack_helper.dart';
import '../../data/services/ride_service.dart';

import '../../core/constants/env_config.dart';

String get _kGoogleApiKey => EnvConfig.googleMapsApiKey;


class FindRideScreen extends StatefulWidget {
  const FindRideScreen({super.key});
  @override
  State<FindRideScreen> createState() => _FindRideScreenState();
}

class _FindRideScreenState extends State<FindRideScreen> {
  // ── Controllers & Focus ───────────────────────────────────────────
  final _fromController = TextEditingController();
  final _toController   = TextEditingController();
  final _fromFocus      = FocusNode();
  final _toFocus        = FocusNode();

  // ── Location state ────────────────────────────────────────────────
  LatLng? _pickupLatLng;
  LatLng? _dropoffLatLng;
  DateTime  _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool   _isLoadingLocation = false;

  // ── Route info from Directions API ────────────────────────────────
  double _routeDistanceKm  = 0;
  int    _routeDurationSec = 0;

  // ── Map ───────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  bool _isLoadingRoute = false;

  // ── Autocomplete — offer-ride style (single list + activeField) ───
  String? _activeField;                    
  List<Map<String, dynamic>> _suggestions = [];
  Timer?  _debounce;
  String  _lastQuery = '';

  // ── Active booking state ──────────────────────────────────────────
  String? _activeBookingId;
  String? _activeBookingStatus;
  String? _activeBookingRideId;        
  bool _checkingActiveBooking = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadActiveBooking();
    _checkNotDriver();
  }

  Future<void> _checkNotDriver() async {
  }

  Future<void> _loadActiveBooking() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('passengerId', isEqualTo: uid)
          .where('status', whereIn: ['pending', 'accepted'])
          .limit(1)
          .get();
      if (mounted && snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        setState(() {
          _activeBookingId = doc.id;
          _activeBookingStatus = doc.data()['status'] as String?;
          _activeBookingRideId = doc.data()['rideId'] as String?;
        });
      } else if (mounted) {
        setState(() { _activeBookingId = null; _activeBookingStatus = null; _activeBookingRideId = null; });
      }
    } catch (_) {}
  }

  Future<void> _cancelActiveBooking() async {
    if (_activeBookingId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: const Text('Are you sure you want to cancel your active booking?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await RideService().cancelBooking(_activeBookingId!);
      if (mounted) {
        setState(() { _activeBookingId = null; _activeBookingStatus = null; _activeBookingRideId = null; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      }
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    _debounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Current location ──────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Please enable it in Settings.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() { _pickupLatLng = ll; _isLoadingLocation = false; });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(ll, 14));
      await _addressFromLatLng(ll, _fromController);
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      // Friendly location error
      if (mounted) {
        final msg = e.toString().contains('network') || e.toString().contains('SocketException')
            ? 'No internet — could not get location. Please check your Wi-Fi.'
            : 'Could not detect location. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _addressFromLatLng(LatLng ll, TextEditingController ctrl) async {
    try {
      final marks = await placemarkFromCoordinates(ll.latitude, ll.longitude);
      if (marks.isNotEmpty) {
        final p = marks.first;
        ctrl.text =
            '${p.street ?? ''}, ${p.subLocality ?? ''}, ${p.locality ?? ''}'
                .replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '');
      }
    } catch (_) {}
  }

  void _onFromChanged(String query) => _onFieldChanged(query, 'from');
  void _onToChanged(String query)   => _onFieldChanged(query, 'to');

  void _onFieldChanged(String query, String fieldKey) {
    _debounce?.cancel();
    setState(() {
      _activeField = fieldKey;
      _lastQuery   = query;
      if (query.trim().length < 2) {
        _suggestions = [];
        if (fieldKey == 'from' && _pickupLatLng  != null) _pickupLatLng  = null;
        if (fieldKey == 'to'   && _dropoffLatLng != null) { _dropoffLatLng = null; _polylines = {}; }
        return;
      }
      if (fieldKey == 'from' && _pickupLatLng  != null) _pickupLatLng  = null;
      if (fieldKey == 'to'   && _dropoffLatLng != null) { _dropoffLatLng = null; _polylines = {}; }
    });
    if (query.trim().length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (_lastQuery == query) _fetchSuggestions(query, fieldKey);
    });
  }

  // ── Google Places Autocomplete ─────────────────────────────────────
  Future<void> _fetchSuggestions(String query, String fieldKey) async {
    if (!mounted) return;
    final bias = _pickupLatLng ?? const LatLng(31.5204, 74.3587);
    List<Map<String, dynamic>> results = [];

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&location=${bias.latitude},${bias.longitude}'
        '&radius=50000'
        '&key=$_kGoogleApiKey'
        '&language=en',
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
              'placeId': pred['place_id']    as String?,
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
            results.add({
              'name': name.isEmpty ? query : name,
              'placeId': null,
              'lat': loc.latitude,
              'lng': loc.longitude,
            });
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    if (_lastQuery != query || _activeField != fieldKey) return;
    setState(() => _suggestions = results);
  }

  Future<LatLng?> _resolvePlace(String placeId) async {
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
          return LatLng(
              (loc['lat'] as num).toDouble(),
              (loc['lng'] as num).toDouble());
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Select suggestion — offer-ride style ──────────────────────────
  Future<void> _selectSuggestion(Map<String, dynamic> s, bool isFrom) async {
    setState(() { _suggestions = []; _activeField = null; });

    LatLng? ll;
    if (s['placeId'] != null) ll = await _resolvePlace(s['placeId'] as String);
    if (ll == null && s['lat'] != null) {
      ll = LatLng(s['lat'] as double, s['lng'] as double);
    }

    setState(() {
      if (isFrom) {
        _fromController.text = s['name'] as String;
        _pickupLatLng        = ll;
        _fromFocus.unfocus();
      } else {
        _toController.text = s['name'] as String;
        _dropoffLatLng     = ll;
        _toFocus.unfocus();
      }
    });

    if (_pickupLatLng != null && _dropoffLatLng != null) {
      await _drawRoute();
    } else if (ll != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(ll, 14));
    }
  }

  // ── Draw route + parse real distance & duration ───────────────────
  Future<void> _drawRoute() async {
    if (_pickupLatLng == null || _dropoffLatLng == null) return;
    setState(() => _isLoadingRoute = true);

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${_pickupLatLng!.latitude},${_pickupLatLng!.longitude}'
        '&destination=${_dropoffLatLng!.latitude},${_dropoffLatLng!.longitude}'
        '&key=$_kGoogleApiKey',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data   = jsonDecode(resp.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final leg    = routes[0]['legs'][0] as Map<String, dynamic>;
          final distM  = (leg['distance']['value'] as num).toInt();
          final durSec = (leg['duration']['value'] as num).toInt();
          final distKm = distM / 1000.0;
          final etaMins = (durSec / 60).ceil();

          setState(() {
            _routeDistanceKm  = distKm;
            _routeDurationSec = durSec;
            // no ride types to update
          });

          final points  = routes[0]['overview_polyline']['points'] as String;
          final decoded = _decodePolyline(points);
          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: decoded,
                color: AppTheme.primary,
                width: 8,
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
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: [_pickupLatLng!, _dropoffLatLng!],
            color: AppTheme.primary,
            width: 8,
          ),
        };
        _routeDistanceKm = _haversineKm();
      });
      _fitRouteOnMap([_pickupLatLng!, _dropoffLatLng!]);
    } finally {
      setState(() => _isLoadingRoute = false);
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
      LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
      120,
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

  // ── Distance helpers ──────────────────────────────────────────────
  double _haversineKm() {
    if (_pickupLatLng == null || _dropoffLatLng == null) return 0;
    const R = 6371.0;
    final dLat = _toRad(_dropoffLatLng!.latitude  - _pickupLatLng!.latitude);
    final dLon = _toRad(_dropoffLatLng!.longitude - _pickupLatLng!.longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(_pickupLatLng!.latitude)) *
            cos(_toRad(_dropoffLatLng!.latitude)) *
            sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double d) => d * pi / 180;

  double _effectiveDistanceKm() =>
      _routeDistanceKm > 0 ? _routeDistanceKm : _haversineKm();

  String _formattedDuration() {
    if (_routeDurationSec == 0) return '';
    final mins = (_routeDurationSec / 60).round();
    return mins < 60 ? '$mins min' : '${mins ~/ 60}h ${mins % 60}m';
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
        child: child!,
      ),
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
        child: child!,
      ),
    );
    if (t != null) setState(() => _selectedTime = t);
  }

  void _search() {
    if (_toController.text.isEmpty) {
      showErrorSnack(context, 'Please enter a destination to search for rides.');
      return;
    }
    if (_fromController.text.isEmpty) {
      showErrorSnack(context, 'Please enter a pickup location.');
      return;
    }
    final dt = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute,
    );
    context.push('/ride-results', extra: {
      'date': dt,
      'pickup': _fromController.text,
      'dropoff': _toController.text,
      'fromCity': _fromController.text,
      'toCity': _toController.text,
      'pickupLocation': _pickupLatLng,
      'dropoffLocation': _dropoffLatLng,
      'distance': _effectiveDistanceKm(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = _pickupLatLng != null && _dropoffLatLng != null;
    final dist     = _effectiveDistanceKm();

    if (_activeBookingId != null) {
      return Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(
          title: const Text('Find a Ride'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_car_rounded,
                      color: AppTheme.primary, size: 40),
                ),
                const SizedBox(height: 20),
                const Text(
                  'You Already Have a Ride',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your booking is ${_activeBookingStatus == 'accepted' ? 'confirmed ✓' : 'pending approval'}. Cancel it first to search for a new ride.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMedium,
                      height: 1.5),
                ),
                const SizedBox(height: 28),
                if (_activeBookingRideId != null)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          context.push('/ride/$_activeBookingRideId'),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('View Your Ride',
                          style: TextStyle(fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                // Cancel booking
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _cancelActiveBooking,
                    icon: const Icon(Icons.cancel_outlined, size: 18,
                        color: AppTheme.error),
                    label: const Text('Cancel Booking',
                        style: TextStyle(
                            fontSize: 15, color: AppTheme.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.error),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() { _activeField = null; _suggestions = []; });
      },
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _pickupLatLng ?? const LatLng(31.5204, 74.3587),
                zoom: 13,
              ),
              onMapCreated: (c) => _mapController = c,
              markers: {
                if (_pickupLatLng != null)
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: _pickupLatLng!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen),
                    infoWindow: const InfoWindow(title: 'Pickup'),
                  ),
                if (_dropoffLatLng != null)
                  Marker(
                    markerId: const MarkerId('dropoff'),
                    position: _dropoffLatLng!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed),
                    infoWindow: const InfoWindow(title: 'Dropoff'),
                  ),
              },
              polylines: _polylines,
              zoomControlsEnabled:    false,
              mapToolbarEnabled:      false,
              myLocationEnabled:      true,
              myLocationButtonEnabled: false,
            ),

            // Route loading indicator
            if (_isLoadingRoute)
              Positioned(
                top: MediaQuery.of(context).padding.top + 200,
                left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                      SizedBox(width: 8),
                      Text('Finding route...', style: TextStyle(fontSize: 12)),
                    ]),
                  ),
                ),
              ),

            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 20, offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // From field
                          _LocationField(
                            controller: _fromController,
                            focusNode: _fromFocus,
                            hint: 'Pickup location',
                            icon: Icons.radio_button_checked,
                            iconColor: AppTheme.success,
                            trailing: _isLoadingLocation
                                ? const SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : IconButton(
                                    icon: const Icon(Icons.my_location, size: 20, color: AppTheme.primary),
                                    onPressed: _getCurrentLocation,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                            onChanged: _onFromChanged,
                          ),

                          // Swap divider
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                const Expanded(child: Divider(color: AppTheme.border, height: 1)),
                                GestureDetector(
                                  onTap: () {
                                    final tmpText = _fromController.text;
                                    final tmpLL   = _pickupLatLng;
                                    setState(() {
                                      _fromController.text = _toController.text;
                                      _pickupLatLng        = _dropoffLatLng;
                                      _toController.text   = tmpText;
                                      _dropoffLatLng       = tmpLL;
                                      _polylines           = {};
                                      _routeDistanceKm     = 0;
                                      _routeDurationSec    = 0;
                                    });
                                    if (_pickupLatLng != null && _dropoffLatLng != null) {
                                      _drawRoute();
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bgLight,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: const Icon(Icons.swap_vert, size: 16, color: AppTheme.textMedium),
                                  ),
                                ),
                                const Expanded(child: Divider(color: AppTheme.border, height: 1)),
                              ],
                            ),
                          ),

                          // To field
                          _LocationField(
                            controller: _toController,
                            focusNode: _toFocus,
                            hint: 'Where to?',
                            icon: Icons.location_on,
                            iconColor: AppTheme.error,
                            onChanged: _onToChanged,
                          ),

                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _DateTimeChip(
                                    icon: Icons.calendar_today_outlined,
                                    label: DateFormat('d MMM').format(_selectedDate),
                                    onTap: _pickDate,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _DateTimeChip(
                                    icon: Icons.access_time,
                                    label: _selectedTime.format(context),
                                    onTap: _pickTime,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Single suggestions list (offer-ride style) ─
                    if (_suggestions.isNotEmpty && _activeField != null)
                      _SuggestionsList(
                        suggestions: _suggestions,
                        onSelect: (s) => _selectSuggestion(s, _activeField == 'from'),
                      ),
                  ],
                ),
              ),
            ),

            Positioned(
              right: 16, bottom: 340,
              child: FloatingActionButton.small(
                heroTag: 'loc_fab',
                backgroundColor: Colors.white,
                elevation: 4,
                onPressed: _getCurrentLocation,
                child: const Icon(Icons.my_location, color: AppTheme.primary, size: 20),
              ),
            ),

            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(2)),
                    ),

                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          hasRoute
                              ? '${dist.toStringAsFixed(1)} km'
                                '${_formattedDuration().isNotEmpty ? "  •  ${_formattedDuration()}" : ""}'
                                '  •  Choose ride'
                              : 'Choose ride type',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── Distance info ─────────────────────────────
                    if (hasRoute)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Card(
                          color: AppTheme.bgWhite, elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppTheme.border)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(children: [
                              const Icon(Icons.route_outlined, size: 18, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                '${dist.toStringAsFixed(1)} km${_formattedDuration().isNotEmpty ? "  ·  ${_formattedDuration()}" : ""}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                              const Spacer(),
                              const Text('Driver sets price',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
                            ]),
                          ),
                        ),
                      ),

                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
                      child: SizedBox(
                        width: double.infinity, height: 52,
                        child: ElevatedButton(
                          onPressed: _search,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Search Rides',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Suggestions list ───────────────────────────────────────────────
class _SuggestionsList extends StatelessWidget {
  final List<Map<String, dynamic>> suggestions;
  final ValueChanged<Map<String, dynamic>> onSelect;
  const _SuggestionsList({required this.suggestions, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
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
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: AppTheme.bgLight,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(s['name'] as String,
                      style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
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

// ── Location field ─────────────────────────────────────────────────
class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final ValueChanged<String> onChanged;

  const _LocationField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            style: const TextStyle(
                fontSize: 16, color: AppTheme.textDark, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppTheme.textLight, fontSize: 16),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class _DateTimeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DateTimeChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 14, color: AppTheme.textLight),
        ]),
      ),
    );
  }
}