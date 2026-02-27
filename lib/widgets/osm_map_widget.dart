import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A reusable OpenStreetMap widget powered by flutter_map + Leaflet tiles.
/// No API key required — uses OpenStreetMap tile server.
class OsmMapWidget extends StatefulWidget {
  /// Center coordinates — defaults to Vadodara [22.3072, 73.1812]
  final double latitude;
  final double longitude;

  /// Initial zoom level (default: 13)
  final double zoom;

  /// Map height in pixels (default: 500)
  final double height;

  /// Optional list of markers to display on the map
  final List<MapMarkerData> markers;

  /// Whether the user can interact with the map
  final bool interactive;

  /// Called when user taps on the map
  final void Function(LatLng)? onTap;

  const OsmMapWidget({
    super.key,
    this.latitude = 22.3072,
    this.longitude = 73.1812,
    this.zoom = 13,
    this.height = 500,
    this.markers = const [],
    this.interactive = true,
    this.onTap,
  });

  @override
  State<OsmMapWidget> createState() => _OsmMapWidgetState();
}

class _OsmMapWidgetState extends State<OsmMapWidget> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(widget.latitude, widget.longitude),
            initialZoom: widget.zoom,
            interactionOptions: InteractionOptions(
              flags: widget.interactive
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
            onTap: widget.onTap != null
                ? (tapPosition, point) => widget.onTap!(point)
                : null,
          ),
          children: [
            // OpenStreetMap tile layer — no API key needed
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              maxZoom: 19,
              userAgentPackageName: 'com.example.lifeflow',
            ),
            // Markers
            if (widget.markers.isNotEmpty)
              MarkerLayer(
                markers: widget.markers
                    .map((m) => Marker(
                          point: LatLng(m.latitude, m.longitude),
                          width: 40,
                          height: 40,
                          child: _buildMarkerIcon(m),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkerIcon(MapMarkerData marker) {
    return GestureDetector(
      onTap: marker.onTap,
      child: Tooltip(
        message: marker.label ?? '',
        child: Icon(
          marker.icon ?? Icons.location_on,
          color: marker.color ?? Colors.red,
          size: 36,
        ),
      ),
    );
  }
}

/// Data class for map markers
class MapMarkerData {
  final double latitude;
  final double longitude;
  final String? label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  const MapMarkerData({
    required this.latitude,
    required this.longitude,
    this.label,
    this.icon,
    this.color,
    this.onTap,
  });
}
