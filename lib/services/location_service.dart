import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// ─── Detailed location result types ───

enum LocationStatus {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

class LocationResult {
  final Position? position;
  final LocationStatus status;

  const LocationResult({this.position, required this.status});

  bool get isSuccess => status == LocationStatus.success && position != null;

  String get userMessage {
    switch (status) {
      case LocationStatus.serviceDisabled:
        return 'Location services are disabled. Please enable GPS in your device settings.';
      case LocationStatus.permissionDenied:
        return 'Location permission denied. Please grant location access to use this feature.';
      case LocationStatus.permissionDeniedForever:
        return 'Location permission is permanently denied. Go to Settings → App Permissions to enable it.';
      case LocationStatus.timeout:
        return 'Could not determine your location (timed out). Move to an open area and try again.';
      case LocationStatus.unknown:
        return 'Could not determine your location. Please try again.';
      case LocationStatus.success:
        return '';
    }
  }

  /// Whether user can resolve by opening location or app settings
  bool get canOpenSettings =>
      status == LocationStatus.serviceDisabled ||
      status == LocationStatus.permissionDeniedForever;
}

// ─── Location Service ───

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _lastPosition;

  /// Cache for driving distances to avoid repeated OSRM calls.
  /// Key: "fromLat,fromLng-toLat,toLng" (4-decimal precision)
  final Map<String, ({String distance, String duration})>
      _drivingDistanceCache = {};

  /// Get driving distance text with caching. Falls back to Haversine with ~prefix.
  Future<({String distance, String duration})?> getCachedDrivingInfo(
      double fromLat, double fromLng, double toLat, double toLng) async {
    final key =
        '${fromLat.toStringAsFixed(4)},${fromLng.toStringAsFixed(4)}-'
        '${toLat.toStringAsFixed(4)},${toLng.toStringAsFixed(4)}';
    if (_drivingDistanceCache.containsKey(key)) {
      return _drivingDistanceCache[key];
    }
    final info = await getDrivingInfo(fromLat, fromLng, toLat, toLng);
    if (info != null) {
      _drivingDistanceCache[key] = info;
      return info;
    }
    // Fallback: Haversine with ~ prefix
    final km = calculateDistanceKm(fromLat, fromLng, toLat, toLng);
    final fallback = (distance: '~${formatDistance(km)}', duration: '');
    _drivingDistanceCache[key] = fallback;
    return fallback;
  }

  // ── Settings helpers ──

  /// Opens the device location settings (GPS toggle)
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Opens the app-specific settings (permissions)
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  // ── Detailed position acquisition ──

  /// Get position with detailed status for UI error reporting.
  Future<LocationResult> getPositionDetailed() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[Location] GPS/Location service is DISABLED on device');
        return LocationResult(
          position: _lastPosition,
          status: _lastPosition != null
              ? LocationStatus.success
              : LocationStatus.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[Location] Permission not yet granted, requesting…');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[Location] User DENIED location permission');
          return LocationResult(
            position: _lastPosition,
            status: _lastPosition != null
                ? LocationStatus.success
                : LocationStatus.permissionDenied,
          );
        }
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('[Location] Location permission is PERMANENTLY denied');
        return LocationResult(
          position: _lastPosition,
          status: _lastPosition != null
              ? LocationStatus.success
              : LocationStatus.permissionDeniedForever,
        );
      }

      debugPrint('[Location] Permission granted ($permission), getting position…');

      // Try high accuracy first
      try {
        _lastPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
        debugPrint('[Location] Got position: ${_lastPosition!.latitude}, ${_lastPosition!.longitude}');
        return LocationResult(
            position: _lastPosition, status: LocationStatus.success);
      } catch (e) {
        debugPrint('[Location] High accuracy failed ($e), trying low…');
      }

      // Fall back to low accuracy
      try {
        _lastPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),
          ),
        );
        debugPrint('[Location] Low-accuracy position: ${_lastPosition!.latitude}, ${_lastPosition!.longitude}');
        return LocationResult(
            position: _lastPosition, status: LocationStatus.success);
      } catch (e) {
        debugPrint('[Location] Low accuracy also failed ($e)');
      }

      // Last resort: cached position
      try {
        _lastPosition = await Geolocator.getLastKnownPosition();
        if (_lastPosition != null) {
          debugPrint('[Location] Using last-known position: ${_lastPosition!.latitude}, ${_lastPosition!.longitude}');
          return LocationResult(
              position: _lastPosition, status: LocationStatus.success);
        }
      } catch (_) {}

      debugPrint('[Location] All strategies failed — no position available');
      return const LocationResult(status: LocationStatus.timeout);
    } catch (e) {
      debugPrint('[Location] Unexpected error: $e');
      return LocationResult(
        position: _lastPosition,
        status:
            _lastPosition != null ? LocationStatus.success : LocationStatus.unknown,
      );
    }
  }

  /// Get the user's current position. Returns null if permission denied.
  Future<Position?> getCurrentPosition() async {
    final result = await getPositionDetailed();
    return result.position;
  }

  /// Cached last known position
  Position? get lastPosition => _lastPosition;

  /// Calculate distance in km between two coordinates using Haversine
  double calculateDistanceKm(
      double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371.0; // km
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * (pi / 180);

  /// Format distance as human-readable string
  String formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  /// Geocode an address string → (lat, lng) using Nominatim (OpenStreetMap)
  Future<({double lat, double lng})?> geocodeAddress(String address) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': address,
        'format': 'json',
        'limit': '1',
        'addressdetails': '1',
      });
      final resp = await http.get(uri, headers: {
        'User-Agent': 'LifeFlow/1.0',
      }).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        debugPrint('[Geocode] HTTP ${resp.statusCode}: ${resp.body}');
        return null;
      }

      final json = jsonDecode(resp.body);
      if (json is! List || json.isEmpty) {
        debugPrint('[Geocode] No results for: $address');
        return null;
      }

      final result = json[0];
      final lat = double.tryParse(result['lat']?.toString() ?? '');
      final lng = double.tryParse(result['lon']?.toString() ?? '');
      if (lat == null || lng == null) return null;

      debugPrint('[Geocode] Resolved: $lat, $lng via Nominatim');
      return (lat: lat, lng: lng);
    } catch (e) {
      debugPrint('[Geocode] Exception: $e');
      return null;
    }
  }

  /// Reverse geocode (lat, lng) → address string
  Future<String?> reverseGeocode(double lat, double lng) async {
    final detail = await reverseGeocodeDetailed(lat, lng);
    return detail?.formattedAddress;
  }

  /// Reverse geocode with full address components using Nominatim
  Future<ReverseGeocodeResult?> reverseGeocodeDetailed(
      double lat, double lng) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': lat.toString(),
        'lon': lng.toString(),
        'format': 'json',
        'addressdetails': '1',
        'zoom': '18',
      });
      final resp = await http.get(uri, headers: {
        'User-Agent': 'LifeFlow/1.0',
      }).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        debugPrint('[ReverseGeocode] HTTP ${resp.statusCode}: ${resp.body}');
        return null;
      }

      final json = jsonDecode(resp.body);
      if (json['error'] != null) {
        debugPrint('[ReverseGeocode] Error: ${json['error']}');
        return null;
      }

      final addr = json['address'] as Map<String, dynamic>? ?? {};
      final formattedAddress = json['display_name'] as String? ?? '';

      final placeName = addr['amenity'] as String? ??
          addr['building'] as String? ??
          addr['shop'] as String? ??
          addr['tourism'] as String? ??
          addr['leisure'] as String?;
      final subLocality = addr['suburb'] as String? ??
          addr['neighbourhood'] as String? ??
          addr['quarter'] as String?;
      final locality = addr['city'] as String? ??
          addr['town'] as String? ??
          addr['village'] as String?;
      final district =
          addr['county'] as String? ?? addr['state_district'] as String?;
      final state = addr['state'] as String?;
      final pincode = addr['postcode'] as String?;
      final country = addr['country'] as String?;
      final city = locality ?? district;

      debugPrint('[ReverseGeocode] Resolved: place=$placeName, '
          'subLocality=$subLocality, city=$city, state=$state, '
          'pincode=$pincode, full=$formattedAddress');

      return ReverseGeocodeResult(
        formattedAddress: formattedAddress,
        placeName: placeName,
        subLocality: subLocality,
        city: city,
        district: district,
        state: state,
        pincode: pincode,
        country: country,
        lat: lat,
        lng: lng,
      );
    } catch (e) {
      debugPrint('[ReverseGeocode] Exception: $e');
      return null;
    }
  }

  /// Autocomplete place search using Nominatim
  Future<List<PlacePrediction>> searchPlaces(String query,
      {String? types}) async {
    if (query.isEmpty) return [];
    try {
      final params = <String, String>{
        'q': query,
        'format': 'json',
        'limit': '5',
        'addressdetails': '1',
      };

      final uri =
          Uri.https('nominatim.openstreetmap.org', '/search', params);
      final resp = await http.get(uri, headers: {
        'User-Agent': 'LifeFlow/1.0',
      }).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        debugPrint('[PlacesSearch] HTTP ${resp.statusCode}: ${resp.body}');
        return [];
      }

      final json = jsonDecode(resp.body);
      if (json is! List) {
        debugPrint('[PlacesSearch] Unexpected response format');
        return [];
      }

      return json.map((p) {
        final addr = p['address'] as Map<String, dynamic>? ?? {};
        final displayName = p['display_name'] as String? ?? '';
        final name = p['name'] as String? ??
            addr['amenity'] as String? ??
            displayName.split(',').first;
        final parts = displayName.split(',');
        final secondary =
            parts.length > 1 ? parts.sublist(1).join(',').trim() : '';

        return PlacePrediction(
          placeId: p['osm_id']?.toString() ?? '',
          description: displayName,
          mainText: name,
          secondaryText: secondary,
          lat: double.tryParse(p['lat']?.toString() ?? ''),
          lng: double.tryParse(p['lon']?.toString() ?? ''),
        );
      }).toList();
    } catch (e) {
      debugPrint('[PlacesSearch] Exception: $e');
      return [];
    }
  }

  /// Get place details from a Nominatim search result
  /// Since Nominatim search already returns full info, this does a
  /// lookup by OSM ID or falls back to re-searching
  Future<PlaceDetail?> getPlaceDetails(String placeId) async {
    try {
      // Try OSM lookup by ID
      final uri =
          Uri.https('nominatim.openstreetmap.org', '/lookup', {
        'osm_ids': 'N$placeId,W$placeId,R$placeId',
        'format': 'json',
        'addressdetails': '1',
      });
      final resp = await http.get(uri, headers: {
        'User-Agent': 'LifeFlow/1.0',
      }).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        if (json is List && json.isNotEmpty) {
          final result = json[0];
          return _parsePlaceDetail(result);
        }
      }

      debugPrint('[PlaceDetails] Lookup failed for ID: $placeId');
      return null;
    } catch (e) {
      debugPrint('[PlaceDetails] Exception: $e');
      return null;
    }
  }

  /// Parse a Nominatim result into PlaceDetail
  PlaceDetail? _parsePlaceDetail(Map<String, dynamic> result) {
    final lat = double.tryParse(result['lat']?.toString() ?? '');
    final lng = double.tryParse(result['lon']?.toString() ?? '');
    if (lat == null || lng == null) return null;

    final addr = result['address'] as Map<String, dynamic>? ?? {};
    final name = result['name'] as String? ??
        addr['amenity'] as String? ??
        '';
    final formattedAddress = result['display_name'] as String? ?? '';
    final city = addr['city'] as String? ??
        addr['town'] as String? ??
        addr['village'] as String? ??
        addr['county'] as String?;
    final pincode = addr['postcode'] as String?;
    final state = addr['state'] as String?;

    debugPrint('[PlaceDetails] name=$name, address=$formattedAddress, '
        'city=$city, pincode=$pincode, lat=$lat, lng=$lng');

    return PlaceDetail(
      lat: lat,
      lng: lng,
      name: name,
      formattedAddress: formattedAddress,
      city: city,
      pincode: pincode,
      state: state,
    );
  }

  /// Get lat/lng for a place ID (backward compat)
  Future<({double lat, double lng})?> getPlaceLatLng(String placeId) async {
    final detail = await getPlaceDetails(placeId);
    if (detail == null) return null;
    return (lat: detail.lat, lng: detail.lng);
  }

  /// Get driving distance and duration between two points using OSRM
  Future<({String distance, String duration})?> getDrivingInfo(
      double fromLat, double fromLng, double toLat, double toLng) async {
    try {
      // OSRM uses lon,lat order (not lat,lon)
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '$fromLng,$fromLat;$toLng,$toLat?overview=false',
      );
      final resp = await http.get(uri, headers: {
        'User-Agent': 'LifeFlow/1.0',
      }).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        debugPrint('[OSRM] HTTP ${resp.statusCode}: ${resp.body}');
        return null;
      }

      final json = jsonDecode(resp.body);
      if (json['code'] != 'Ok' ||
          (json['routes'] as List?)?.isEmpty == true) {
        debugPrint('[OSRM] code=${json['code']}');
        return null;
      }

      final route = json['routes'][0];
      final distMeters = (route['distance'] as num).toDouble();
      final durSeconds = (route['duration'] as num).toDouble();

      // Format distance
      String distText;
      if (distMeters < 1000) {
        distText = '${distMeters.round()} m';
      } else {
        final km = distMeters / 1000;
        distText = km < 10
            ? '${km.toStringAsFixed(1)} km'
            : '${km.round()} km';
      }

      // Format duration
      String durText;
      if (durSeconds < 60) {
        durText = '${durSeconds.round()} sec';
      } else if (durSeconds < 3600) {
        durText = '${(durSeconds / 60).round()} min';
      } else {
        final hours = (durSeconds / 3600).floor();
        final mins = ((durSeconds % 3600) / 60).round();
        durText = mins > 0 ? '$hours hr $mins min' : '$hours hr';
      }

      debugPrint('[OSRM] distance=$distText, duration=$durText');
      return (distance: distText, duration: durText);
    } catch (e) {
      debugPrint('[OSRM] Exception: $e');
      return null;
    }
  }
}

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final double? lat;
  final double? lng;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    this.secondaryText = '',
    this.lat,
    this.lng,
  });
}

class PlaceDetail {
  final double lat;
  final double lng;
  final String name;
  final String formattedAddress;
  final String? city;
  final String? pincode;
  final String? state;

  PlaceDetail({
    required this.lat,
    required this.lng,
    required this.name,
    required this.formattedAddress,
    this.city,
    this.pincode,
    this.state,
  });
}

class ReverseGeocodeResult {
  final String formattedAddress;
  final String? placeName;
  final String? subLocality;
  final String? city;
  final String? district;
  final String? state;
  final String? pincode;
  final String? country;
  final double lat;
  final double lng;

  ReverseGeocodeResult({
    required this.formattedAddress,
    this.placeName,
    this.subLocality,
    this.city,
    this.district,
    this.state,
    this.pincode,
    this.country,
    required this.lat,
    required this.lng,
  });

  /// Build a clean comma-separated full address with pincode
  String get fullAddress {
    final parts = <String>[];
    if (placeName != null && placeName!.isNotEmpty) parts.add(placeName!);
    if (subLocality != null && subLocality!.isNotEmpty) parts.add(subLocality!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    if (pincode != null && pincode!.isNotEmpty) parts.add(pincode!);
    if (parts.isEmpty) return formattedAddress;
    return parts.join(', ');
  }
}
