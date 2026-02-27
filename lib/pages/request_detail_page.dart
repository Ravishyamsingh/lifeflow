import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/donation_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../widgets/osm_map_widget.dart';

class RequestDetailPage extends StatefulWidget {
  final DonationModel request;

  const RequestDetailPage({super.key, required this.request});

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  final DatabaseService _db = DatabaseService();
  final LocationService _loc = LocationService();

  bool _loadingDistance = true;
  bool _accepting = false;
  bool _cancelling = false;
  bool _completing = false;
  double? _distanceKm;
  String? _drivingDistance;
  String? _drivingDuration;
  Position? _myPosition;
  String? _locationError;

  bool get _isPatientView =>
      FirebaseAuth.instance.currentUser?.uid == widget.request.recipientId;

  @override
  void initState() {
    super.initState();
    _loadDistanceInfo();
  }

  Future<void> _loadDistanceInfo() async {
    final result = await _loc.getPositionDetailed();
    _myPosition = result.position;
    if (!result.isSuccess) {
      _locationError = result.userMessage;
    }

    // Resolve hospital coordinates — use stored values or fallback geocode
    double? hospLat = widget.request.hospitalLat;
    double? hospLng = widget.request.hospitalLng;
    if ((hospLat == null || hospLng == null) &&
        widget.request.hospitalName != null &&
        widget.request.hospitalName!.isNotEmpty) {
      debugPrint('[RequestDetail] Hospital coords missing, geocoding: ${widget.request.hospitalName}');
      final coords = await _loc.geocodeAddress(widget.request.hospitalName!);
      if (coords != null) {
        hospLat = coords.lat;
        hospLng = coords.lng;
        debugPrint('[RequestDetail] Geocoded hospital: $hospLat, $hospLng');
      }
    }

    if (_myPosition != null && hospLat != null && hospLng != null) {
      _distanceKm = _loc.calculateDistanceKm(
        _myPosition!.latitude,
        _myPosition!.longitude,
        hospLat,
        hospLng,
      );

      final driving = await _loc.getDrivingInfo(
        _myPosition!.latitude,
        _myPosition!.longitude,
        hospLat,
        hospLng,
      );
      if (driving != null) {
        _drivingDistance = driving.distance;
        _drivingDuration = driving.duration;
      }
    }
    if (mounted) setState(() => _loadingDistance = false);
  }

  Future<void> _acceptRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Accept This Request?'),
        content: Text(
          'You are about to accept the blood request for '
          '${widget.request.recipientName}.\n\n'
          'Blood type: ${widget.request.donorBloodType}\n'
          'Units needed: ${widget.request.unitsNeeded}\n\n'
          'The patient will be notified that you are willing to donate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Accept'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _accepting = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final userData = await _db.getUserById(currentUser.uid);

      await _db.acceptDonation(
        widget.request.donationId,
        currentUser.uid,
        donorName: userData?.name ?? currentUser.displayName ?? 'Donor',
        donorBloodType: userData?.bloodType,
      );

      // Also update donor's location if we have it
      if (_myPosition != null) {
        await _db.updateUserLocation(
          currentUser.uid,
          latitude: _myPosition!.latitude,
          longitude: _myPosition!.longitude,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request accepted! The patient will be notified.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _openInMaps() async {
    if (widget.request.hospitalLat == null ||
        widget.request.hospitalLng == null) {
      // Fallback: search by hospital name on OpenStreetMap
      final query =
          Uri.encodeComponent(widget.request.hospitalName ?? widget.request.location ?? '');
      final url = Uri.parse('https://www.openstreetmap.org/search?query=$query');
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }
    final lat = widget.request.hospitalLat!;
    final lng = widget.request.hospitalLng!;
    // Open directions on OpenStreetMap via OSRM
    final url = Uri.parse(
        'https://www.openstreetmap.org/directions?engine=osrm_car&route=;$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPatient() async {
    final phone = widget.request.patientPhone;
    if (phone == null || phone.isEmpty) return;
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _cancelRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Request?'),
        content:
            const Text('Are you sure you want to cancel this blood request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _cancelling = true);
    try {
      await _db.cancelDonation(widget.request.donationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Request cancelled'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _completeRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as Completed?'),
        content: const Text(
          'Confirm that the blood donation has been received successfully.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Completed'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _completing = true);
    try {
      await _db.completeDonation(widget.request.donationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Donation marked as completed! Thank you!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'critical':
        return Colors.red.shade700;
      case 'urgent':
        return Colors.orange.shade700;
      default:
        return Colors.green.shade700;
    }
  }

  IconData _urgencyIcon(String urgency) {
    switch (urgency) {
      case 'critical':
        return Icons.warning_amber_rounded;
      case 'urgent':
        return Icons.access_time_filled;
      default:
        return Icons.event_available;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: _urgencyColor(r.urgency),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Request Details'),
        actions: [
          if (r.hospitalLat != null || r.hospitalName != null)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: 'Open in Maps',
              onPressed: _openInMaps,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Urgency Banner ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: _urgencyColor(r.urgency),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        r.donorBloodType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_urgencyIcon(r.urgency),
                                color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              r.urgency.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${r.unitsNeeded} unit(s) of ${r.donorBloodType} needed',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Distance Card ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildDistanceCard(),
            ),

            // ── Hospital Map ──
            if (widget.request.hospitalLat != null &&
                widget.request.hospitalLng != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: OsmMapWidget(
                    latitude: widget.request.hospitalLat!,
                    longitude: widget.request.hospitalLng!,
                    zoom: 15,
                    height: 200,
                    interactive: true,
                    markers: [
                      MapMarkerData(
                        latitude: widget.request.hospitalLat!,
                        longitude: widget.request.hospitalLng!,
                        label: widget.request.hospitalName ?? 'Hospital',
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              ),

            // ── Patient Information ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _infoSection(
                title: 'Patient Information',
                icon: Icons.person_outline,
                children: [
                  _infoRow('Name', r.recipientName),
                  if (r.patientPhone != null)
                    _infoRowWithAction(
                      'Phone',
                      r.patientPhone!,
                      icon: Icons.call,
                      onTap: _callPatient,
                    ),
                  if (r.patientAddress != null)
                    _infoRow('Address', r.patientAddress!),
                  if (r.patientDob != null)
                    _infoRow(
                      'Date of Birth',
                      '${r.patientDob!.day.toString().padLeft(2, '0')}/'
                      '${r.patientDob!.month.toString().padLeft(2, '0')}/'
                      '${r.patientDob!.year}',
                    ),
                  if (r.relationToPatient != null)
                    _infoRow('Relation', r.relationToPatient!),
                ],
              ),
            ),

            // ── Medical Information ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _infoSection(
                title: 'Medical Details',
                icon: Icons.medical_information_outlined,
                children: [
                  _infoRow('Blood Type', r.donorBloodType),
                  _infoRow('Units Needed', '${r.unitsNeeded}'),
                  if (r.patientDisease != null)
                    _infoRow('Condition', r.patientDisease!),
                  if (r.hospitalName != null)
                    _infoRow('Hospital', r.hospitalName!),
                  if (r.doctorName != null)
                    _infoRow('Doctor', r.doctorName!),
                  _infoRow(
                    'Required By',
                    '${r.donationDate.day.toString().padLeft(2, '0')}/'
                    '${r.donationDate.month.toString().padLeft(2, '0')}/'
                    '${r.donationDate.year}',
                  ),
                ],
              ),
            ),

            // ── Notes ──
            if (r.notes != null && r.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _infoSection(
                  title: 'Additional Notes',
                  icon: Icons.note_outlined,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        r.notes!,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 100),
          ],
        ),
      ),

      // ── Bottom Action Bar (role-aware) ──
      bottomNavigationBar: _buildBottomBar(r),
    );
  }

  Widget _buildBottomBar(DonationModel r) {
    if (_isPatientView) {
      // ── Patient View ──
      if (r.status == 'pending') {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _cancelling ? null : _cancelRequest,
                icon: _cancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cancel_outlined),
                label: Text(
                    _cancelling ? 'Cancelling...' : 'Cancel Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        );
      } else if (r.status == 'accepted') {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green.shade600),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Donor ${r.donorName.isNotEmpty ? r.donorName : "someone"} has accepted',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _completing ? null : _completeRequest,
                    icon: _completing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.done_all),
                    label: Text(_completing
                        ? 'Processing...'
                        : 'Mark as Completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This request has been ${r.status}.',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    // ── Donor View ──
    if (r.status != 'pending') {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This request has already been ${r.status}.',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openInMaps,
                icon: const Icon(Icons.directions),
                label: const Text('Directions'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.blue.shade400),
                  foregroundColor: Colors.blue.shade600,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _accepting ? null : _acceptRequest,
                icon: _accepting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.volunteer_activism),
                label: Text(
                    _accepting ? 'Accepting...' : 'Accept Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _loadingDistance
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Calculating distance...'),
              ],
            )
          : _distanceKm != null
              ? Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.near_me,
                          color: Colors.blue.shade600, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _drivingDistance ?? _loc.formatDistance(_distanceKm!),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _drivingDuration != null
                                ? '$_drivingDuration by car'
                                : '${_loc.formatDistance(_distanceKm!)} straight line',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openInMaps,
                      icon: Icon(Icons.map, size: 18, color: Colors.blue.shade600),
                      label: Text('Map',
                          style: TextStyle(color: Colors.blue.shade600)),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(Icons.location_off, color: Colors.orange.shade400),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _locationError ?? 'Unable to calculate distance',
                        style: TextStyle(
                            color: Colors.orange.shade700, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _loadingDistance = true);
                        _loadDistanceInfo();
                      },
                      child: const Text('Retry', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
    );
  }

  Widget _infoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _infoRowWithAction(
    String label,
    String value, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: Colors.green.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
