import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

/// A widget that displays driving distance between two points.
///
/// Shows "~X km" (Haversine) immediately, then upgrades to actual
/// road distance + travel time from OSRM asynchronously.
class DistanceBadge extends StatefulWidget {
  final Position? myPosition;
  final double? destLat;
  final double? destLng;

  /// Optional fallback location text when no coordinates are available.
  final String? fallbackLocation;

  /// Size variant: 'small' (12px) or 'normal' (13px)
  final String size;

  const DistanceBadge({
    super.key,
    required this.myPosition,
    required this.destLat,
    required this.destLng,
    this.fallbackLocation,
    this.size = 'small',
  });

  @override
  State<DistanceBadge> createState() => _DistanceBadgeState();
}

class _DistanceBadgeState extends State<DistanceBadge> {
  final _locationService = LocationService();
  String? _distanceText;
  String? _durationText;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _computeDistance();
  }

  @override
  void didUpdateWidget(DistanceBadge old) {
    super.didUpdateWidget(old);
    if (old.myPosition != widget.myPosition ||
        old.destLat != widget.destLat ||
        old.destLng != widget.destLng) {
      _computeDistance();
    }
  }

  Future<void> _computeDistance() async {
    if (widget.myPosition == null ||
        widget.destLat == null ||
        widget.destLng == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Show Haversine immediately
    final km = _locationService.calculateDistanceKm(
      widget.myPosition!.latitude,
      widget.myPosition!.longitude,
      widget.destLat!,
      widget.destLng!,
    );
    if (mounted) {
      setState(() {
        _distanceText = '~${_locationService.formatDistance(km)}';
        _isLoading = false;
      });
    }

    // Upgrade with OSRM driving distance
    final info = await _locationService.getCachedDrivingInfo(
      widget.myPosition!.latitude,
      widget.myPosition!.longitude,
      widget.destLat!,
      widget.destLng!,
    );
    if (mounted && info != null) {
      setState(() {
        _distanceText = info.distance;
        _durationText = info.duration.isNotEmpty ? info.duration : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = widget.size == 'small';
    final fontSize = isSmall ? 12.0 : 13.0;
    final iconSize = isSmall ? 12.0 : 13.0;

    if (_distanceText != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car, size: iconSize, color: Colors.blue.shade500),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              _distanceText! + (_durationText != null ? ' · $_durationText' : ''),
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.blue.shade600,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      );
    }

    if (widget.fallbackLocation != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: iconSize + 1, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              widget.fallbackLocation!,
              style: TextStyle(fontSize: fontSize, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (_isLoading) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Colors.blue.shade300,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
