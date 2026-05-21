import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/env_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snack_helper.dart';
import '../../data/services/ride_service.dart';
import '../../data/models/ride_model.dart';
import '../../data/models/booking_model.dart';

class ActiveRideScreen extends StatefulWidget {
  final String rideId;
  const ActiveRideScreen({super.key, required this.rideId});

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  final _rideService = RideService();

  RideModel? _ride;
  List<BookingModel> _acceptedBookings = [];
  bool _isLoading = true;
  bool _rideStarted = false;
  bool _isEndingRide = false;

  // Map
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // ── FIX 1: Store subscription so we can cancel it on dispose ──────
  StreamSubscription<Position>? _locationSub;

  @override
  void initState() {
    super.initState();
    _loadRide();
  }

  Future<void> _loadRide() async {
    try {
      final ride = await _rideService.getRideById(widget.rideId);
      if (ride == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final bookingsSnap = await _rideService
          .getRideBookings(widget.rideId)
          .first;
      final accepted = bookingsSnap
          .where((b) => b.status == 'accepted')
          .toList();

      final alreadyStarted = ride.status == 'active';

      if (mounted) {
        setState(() {
          _ride = ride;
          _acceptedBookings = accepted;
          _rideStarted = alreadyStarted;
          _isLoading = false;
        });
      }

      // ── FIX 2: Use Directions API for road-wise polyline ──────────
      if (ride.startPoint.lat != 0 && ride.endPoint.lat != 0) {
        await _buildRoutePolyline(
          LatLng(ride.startPoint.lat, ride.startPoint.lng),
          LatLng(ride.endPoint.lat, ride.endPoint.lng),
        );
      }

      if (alreadyStarted) _startLocationTracking();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnack(context, e);
      }
    }
  }

  // ── FIX 2: Road-wise polyline via Google Directions API ────────────
  Future<void> _buildRoutePolyline(LatLng start, LatLng end) async {
    if (!mounted) return;

    // Show markers immediately while route loads
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('start'),
          position: start,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
        Marker(
          markerId: const MarkerId('end'),
          position: end,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Dropoff'),
        ),
      };
    });

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${start.latitude},${start.longitude}'
        '&destination=${end.latitude},${end.longitude}'
        '&key=${EnvConfig.googleMapsApiKey}',
      );

      final resp = await http.get(url).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;

        if (routes != null && routes.isNotEmpty) {
          final points = routes[0]['overview_polyline']['points'] as String;
          final decoded = _decodePolyline(points);

          if (mounted) {
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
          return;
        }
      }
    } catch (_) {
      // Directions API failed — fall back to straight line silently
    }

    // Fallback: straight line if API fails
    if (mounted) {
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: [start, end],
            color: AppTheme.primary,
            width: 5,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        };
      });
    }
  }

  // Decode Google's encoded polyline format
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> pts = [];
    int idx = 0, lat = 0, lng = 0;
    while (idx < encoded.length) {
      int shift = 0, res = 0, b;
      do {
        b = encoded.codeUnitAt(idx++) - 63;
        res |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
      shift = 0;
      res = 0;
      do {
        b = encoded.codeUnitAt(idx++) - 63;
        res |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
      pts.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return pts;
  }

  void _fitRouteOnMap(List<LatLng> pts) {
    if (pts.isEmpty || _mapController == null) return;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        72,
      ),
    );
  }

  // ── FIX 3: Location tracking saves to Firestore for passenger view ─
  Future<void> _startLocationTracking() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final initLL = LatLng(pos.latitude, pos.longitude);
      _updateDriverMarker(initLL);

      // Save initial location to Firestore so passengers can see it
      await _rideService.updateDriverLocation(
        widget.rideId,
        pos.latitude,
        pos.longitude,
      );

      // ── FIX 1: Store subscription for proper disposal ─────────────
      _locationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) async {
        if (!mounted) return;
        final ll = LatLng(pos.latitude, pos.longitude);
        _updateDriverMarker(ll);

        // Save every update to Firestore — passengers read this
        await _rideService.updateDriverLocation(
          widget.rideId,
          pos.latitude,
          pos.longitude,
        );
      });
    } catch (_) {
      // Location unavailable — map still shows static route
    }
  }

  void _updateDriverMarker(LatLng pos) {
    if (!mounted) return;
    setState(() {
      _currentLocation = pos;
      _markers = {
        ..._markers.where((m) => m.markerId.value != 'driver'),
        Marker(
          markerId: const MarkerId('driver'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'You'),
          zIndex: 2,
        ),
      };
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
  }

  Future<void> _startRide() async {
    try {
      await _rideService.updateRideStatus(widget.rideId, 'active');
      setState(() => _rideStarted = true);
      _startLocationTracking();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _endRide() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Ride?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Mark this ride as completed? All passengers will be notified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Yes, End Ride'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isEndingRide = true);

    // ── FIX 1: Stop location stream before ending ride ────────────
    await _locationSub?.cancel();
    _locationSub = null;

    try {
      await _rideService.updateRideStatus(widget.rideId, 'completed');
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Ride Completed!',
                style: TextStyle(fontWeight: FontWeight.w700)),
            content: const Text(
                'Great job! The ride has been marked as completed.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/home');
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isEndingRide = false);
        showErrorSnack(context, e);
      }
    }
  }

  // ── FIX 1: Cancel stream subscription on dispose ──────────────────
  @override
  void dispose() {
    _locationSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: AppTheme.primary)));
    }

    final ride = _ride;
    if (ride == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Ride')),
        body: const Center(child: Text('Ride not found')),
      );
    }

    final startLL = ride.startPoint.lat != 0
        ? LatLng(ride.startPoint.lat, ride.startPoint.lng)
        : const LatLng(31.5204, 74.3587);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(_rideStarted ? 'Ride in Progress' : 'Start Ride'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation ?? startLL,
                    zoom: 14,
                  ),
                  onMapCreated: (c) {
                    _mapController = c;
                    // Fit route on map once controller is ready
                    if (_polylines.isNotEmpty) {
                      final pts = _polylines.first.points;
                      if (pts.length > 1) _fitRouteOnMap(pts);
                    }
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),

                if (_rideStarted)
                  Positioned(
                    top: 12,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gps_fixed,
                              color: Colors.white, size: 13),
                          SizedBox(width: 5),
                          Text('Live',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),

                if (_rideStarted && _acceptedBookings.isNotEmpty)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _PassengersOverlay(bookings: _acceptedBookings),
                  ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: _rideStarted
                  ? ElevatedButton(
                      onPressed: _isEndingRide ? null : _endRide,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isEndingRide
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const Text('End Ride',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                    )
                  : ElevatedButton(
                      onPressed: _startRide,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Start Ride',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengersOverlay extends StatelessWidget {
  final List<BookingModel> bookings;
  const _PassengersOverlay({required this.bookings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${bookings.length} passenger${bookings.length != 1 ? 's' : ''} on board',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: bookings
                .map((b) => _PassengerChip(
                      name: b.passengerName,
                      photo: b.passengerPhoto,
                      seats: b.seatsNeeded,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PassengerChip extends StatelessWidget {
  final String name;
  final String? photo;
  final int seats;
  const _PassengerChip(
      {required this.name, this.photo, required this.seats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.primaryLight,
            backgroundImage:
                photo != null ? NetworkImage(photo!) : null,
            child: photo == null
                ? Text(
                    name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            name.split(' ').first,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textDark),
          ),
          if (seats > 1) ...[
            const SizedBox(width: 4),
            Text(
              '×$seats',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textMedium),
            ),
          ],
        ],
      ),
    );
  }
}