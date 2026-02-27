import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../widgets/distance_badge.dart';

class FindDonorsPage extends StatefulWidget {
  const FindDonorsPage({super.key});

  @override
  State<FindDonorsPage> createState() => _FindDonorsPageState();
}

class _FindDonorsPageState extends State<FindDonorsPage> {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedBloodType;
  bool _showOnlyAvailable = true;
  bool _sortByDistance = false;
  Position? _myPosition;
  String? _locationError;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final result = await _locationService.getPositionDetailed();
    if (!mounted) return;
    setState(() {
      _myPosition = result.position;
      _locationError = result.isSuccess ? null : result.userMessage;
    });
  }

  double? _distanceKmTo(UserModel donor) {
    if (_myPosition == null ||
        donor.latitude == null ||
        donor.longitude == null) {
      return null;
    }
    return _locationService.calculateDistanceKm(
      _myPosition!.latitude,
      _myPosition!.longitude,
      donor.latitude!,
      donor.longitude!,
    );
  }

  /// Filter donors by search query (name, location, blood type)
  List<UserModel> _filterDonors(List<UserModel> donors) {
    if (_searchQuery.isEmpty) return donors;
    final q = _searchQuery.toLowerCase();
    return donors.where((d) {
      return d.name.toLowerCase().contains(q) ||
          (d.location?.toLowerCase().contains(q) ?? false) ||
          (d.bloodType?.toLowerCase().contains(q) ?? false) ||
          (d.email.toLowerCase().contains(q));
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final List<String> bloodTypes = [
    'All',
    'O+',
    'O-',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-'
  ];

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Find Donors',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, location…',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
            ),
          ),
          // Filter chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: bloodTypes.map((type) {
                  final isSelected = _selectedBloodType == type ||
                      (_selectedBloodType == null && type == 'All');
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(type),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedBloodType = type == 'All' ? null : type;
                        });
                      },
                      selectedColor: Colors.red.shade100,
                      checkmarkColor: Colors.red.shade600,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // Location error banner
          if (_locationError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(Icons.location_off,
                      size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationError!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade700),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadLocation,
                    child: const Text('Retry', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

          // Donors list
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _selectedBloodType != null
                  ? _databaseService.getUsersByBloodType(_selectedBloodType!)
                  : _databaseService.getAvailableDonors(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading donors',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                final donors = snapshot.data ?? [];
                // Filter out current user
                var filteredDonors = donors
                    .where((donor) => donor.uid != currentUser?.uid)
                    .toList();

                // Apply text search filter
                filteredDonors = _filterDonors(filteredDonors);

                // Sort by distance if enabled
                if (_sortByDistance && _myPosition != null) {
                  filteredDonors.sort((a, b) {
                    final distA = _distanceKmTo(a);
                    final distB = _distanceKmTo(b);
                    if (distA == null && distB == null) return 0;
                    if (distA == null) return 1;
                    if (distB == null) return -1;
                    return distA.compareTo(distB);
                  });
                }

                if (filteredDonors.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No donors match "$_searchQuery"'
                              : 'No donors found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedBloodType != null
                              ? 'No donors with blood type $_selectedBloodType available'
                              : _searchQuery.isNotEmpty
                                  ? 'Try a different search term'
                                  : 'No donors are currently available',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: const Text('Clear search'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDonors.length,
                  itemBuilder: (context, index) {
                    final donor = filteredDonors[index];
                    return _buildDonorCard(donor);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorCard(UserModel donor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.red.shade100,
              backgroundImage:
                  donor.photoUrl != null ? NetworkImage(donor.photoUrl!) : null,
              child: donor.photoUrl == null
                  ? Icon(Icons.person, color: Colors.red.shade600, size: 30)
                  : null,
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    donor.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          donor.bloodType ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DistanceBadge(
                          myPosition: _myPosition,
                          destLat: donor.latitude,
                          destLng: donor.longitude,
                          fallbackLocation: donor.location,
                          size: 'normal',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${donor.totalDonations} donations made',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            // Contact button
            ElevatedButton(
              onPressed: () => _showContactDialog(donor),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Contact'),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactDialog(UserModel donor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contact ${donor.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (donor.phoneNumber != null && donor.phoneNumber!.isNotEmpty)
              ListTile(
                leading: Icon(Icons.phone, color: Colors.red.shade600),
                title: const Text('Phone'),
                subtitle: Text(donor.phoneNumber!),
                onTap: () async {
                  Navigator.pop(context);
                  final url = Uri.parse('tel:${donor.phoneNumber}');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
              ),
            ListTile(
              leading: Icon(Icons.email, color: Colors.red.shade600),
              title: const Text('Email'),
              subtitle: Text(donor.email),
              onTap: () async {
                Navigator.pop(context);
                final url = Uri.parse('mailto:${donor.email}');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
            ),
            if (donor.latitude != null && donor.longitude != null)
              ListTile(
                leading:
                    Icon(Icons.directions, color: Colors.blue.shade600),
                title: const Text('Get Directions'),
                subtitle: Text(donor.location ?? 'View on map'),
                onTap: () async {
                  Navigator.pop(context);
                  final url = Uri.parse(
                    'https://www.openstreetmap.org/directions?engine=osrm_car&route='
                    ';${donor.latitude},${donor.longitude}',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url,
                        mode: LaunchMode.externalApplication);
                  }
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Donors',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('Show only available donors'),
              value: _showOnlyAvailable,
              onChanged: (value) {
                setState(() => _showOnlyAvailable = value);
                Navigator.pop(context);
              },
              activeTrackColor: Colors.red.shade600,
            ),
            SwitchListTile(
              title: const Text('Sort by distance'),
              subtitle: Text(
                _myPosition != null
                    ? 'Uses your current location'
                    : 'Enable location to use this',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              value: _sortByDistance,
              onChanged: _myPosition != null
                  ? (value) {
                      setState(() => _sortByDistance = value);
                      Navigator.pop(context);
                    }
                  : null,
              activeTrackColor: Colors.blue.shade600,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedBloodType = null;
                    _showOnlyAvailable = true;
                    _sortByDistance = false;
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Reset Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
