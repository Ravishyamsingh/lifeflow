import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_model.dart';
import '../models/donation_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../widgets/distance_badge.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'donation_history_page.dart';
import 'blood_request_page.dart';
import 'request_detail_page.dart';

class DonorHomePage extends StatefulWidget {
  const DonorHomePage({super.key});

  @override
  State<DonorHomePage> createState() => _DonorHomePageState();
}

class _DonorHomePageState extends State<DonorHomePage> {
  final AuthService _authService = AuthService();
  final DatabaseService _db = DatabaseService();
  int _currentIndex = 0;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    // Proactively request location permission on first load.
    // This ensures the permission dialog appears early, not when the user
    // taps a specific feature.
    LocationService().getPositionDetailed();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<UserModel?>(
      stream: _db.getUserStream(uid),
      builder: (context, snapshot) {
        final user = snapshot.data;

        final pages = [
          _DonorDashboard(user: user, db: _db),
          _DonorRequestsBrowser(user: user, db: _db),
          const DonationHistoryPage(),
          const ProfilePage(),
        ];

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_currentIndex != 0) {
              setState(() => _currentIndex = 0);
              return;
            }
            final now = DateTime.now();
            if (_lastBackPress == null ||
                now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
              _lastBackPress = now;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Press back again to exit'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            SystemNavigator.pop();
          },
          child: Scaffold(
            appBar: _buildAppBar(user),
            body: pages[_currentIndex],
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.list_alt_outlined),
                  selectedIcon: Icon(Icons.list_alt),
                  label: 'Requests',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: 'History',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(UserModel? user) {
    return AppBar(
      backgroundColor: Colors.red.shade600,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LifeFlow',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('Donor · ${user?.name ?? ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
        ],
      ),
      actions: [
        if (user?.bloodType != null)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user!.bloodType!,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) async {
            if (value == 'settings') {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()));
            } else if (value == 'logout') {
              await _authService.signOut();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'settings', child: Text('Settings')),
            const PopupMenuItem(value: 'logout', child: Text('Sign Out')),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────── Dashboard Tab ───────────────────────────

class _DonorDashboard extends StatelessWidget {
  final UserModel? user;
  final DatabaseService db;

  const _DonorDashboard({required this.user, required this.db});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade600, Colors.red.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${user?.name.split(' ').first ?? 'Donor'}! 👋',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user?.isAvailableToDonate == true
                            ? '✅ You are available to donate'
                            : '❌ You are not available to donate',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.volunteer_activism,
                    color: Colors.white.withValues(alpha: 0.4), size: 48),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.bloodtype,
                  iconColor: Colors.red.shade600,
                  value: '${user?.totalDonations ?? 0}',
                  label: 'Donations',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.favorite,
                  iconColor: Colors.pink.shade400,
                  value: '${user?.livesSaved ?? 0}',
                  label: 'Lives Saved',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: user?.isAvailableToDonate == true
                      ? Icons.check_circle
                      : Icons.cancel,
                  iconColor: user?.isAvailableToDonate == true
                      ? Colors.green
                      : Colors.grey,
                  value: user?.isAvailableToDonate == true ? 'Yes' : 'No',
                  label: 'Available',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Availability Toggle
          _AvailabilityToggle(user: user, db: db),
          const SizedBox(height: 24),

          // Quick Actions
          const Text('Quick Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _QuickAction(
                icon: Icons.list_alt,
                label: 'Blood Requests',
                color: Colors.orange.shade600,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BloodRequestPage())),
              ),
              _QuickAction(
                icon: Icons.history,
                label: 'My Donations',
                color: Colors.blue.shade600,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DonationHistoryPage())),
              ),
              _QuickAction(
                icon: Icons.person,
                label: 'My Profile',
                color: Colors.purple.shade600,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfilePage())),
              ),
              _QuickAction(
                icon: Icons.settings,
                label: 'Settings',
                color: Colors.grey.shade600,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsPage())),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Live Blood Requests
          const Text('Active Blood Requests Near You',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _LiveRequestsList(db: db, currentUserId: user?.uid ?? ''),
          const SizedBox(height: 24),

          // My Accepted Requests
          const Text('My Accepted Requests',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _MyAcceptedPreview(db: db, uid: user?.uid ?? ''),
        ],
      ),
    );
  }
}

// ─────────── Availability Toggle ───────────

class _AvailabilityToggle extends StatefulWidget {
  final UserModel? user;
  final DatabaseService db;

  const _AvailabilityToggle({required this.user, required this.db});

  @override
  State<_AvailabilityToggle> createState() => _AvailabilityToggleState();
}

class _AvailabilityToggleState extends State<_AvailabilityToggle> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final available = widget.user?.isAvailableToDonate ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: available ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: available ? Colors.green.shade300 : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.volunteer_activism,
              color: available ? Colors.green.shade600 : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  available ? 'Available to Donate' : 'Not Available',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: available
                        ? Colors.green.shade700
                        : Colors.grey.shade700,
                  ),
                ),
                Text(
                  available
                      ? 'Patients can find and contact you'
                      : 'Toggle ON to appear in donor searches',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          _loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Switch(
                  value: available,
                  activeTrackColor: Colors.green,
                  onChanged: (val) async {
                    if (widget.user == null) return;
                    setState(() => _loading = true);
                    try {
                      await widget.db
                          .setDonationAvailability(widget.user!.uid, val);
                      // Also update location when toggling available
                      if (val) {
                        final pos =
                            await LocationService().getCurrentPosition();
                        if (pos != null) {
                          await widget.db.updateUserLocation(
                            widget.user!.uid,
                            latitude: pos.latitude,
                            longitude: pos.longitude,
                          );
                        }
                      }
                    } catch (_) {}
                    if (mounted) setState(() => _loading = false);
                  },
                ),
        ],
      ),
    );
  }
}

// ─────────── Live Requests List ───────────

class _LiveRequestsList extends StatefulWidget {
  final DatabaseService db;
  final String currentUserId;

  const _LiveRequestsList({required this.db, required this.currentUserId});

  @override
  State<_LiveRequestsList> createState() => _LiveRequestsListState();
}

class _LiveRequestsListState extends State<_LiveRequestsList> {
  Position? _myPosition;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final result = await LocationService().getPositionDetailed();
    if (mounted) {
      setState(() => _myPosition = result.position);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DonationModel>>(
      stream: widget.db.getPendingBloodRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snapshot.data ?? [];
        final others = requests.where((r) => r.recipientId != widget.currentUserId).toList();
        if (others.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('No active blood requests at the moment',
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        // Limit to latest 5 on dashboard; full list is in Requests tab
        final display = others.length > 5 ? others.sublist(0, 5) : others;
        return Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: display.length,
              itemBuilder: (_, i) => _RequestCard(
                request: display[i],
                db: widget.db,
                myPosition: _myPosition,
              ),
            ),
            if (others.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${others.length - 5} more request(s) — see Requests tab',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final DonationModel request;
  final DatabaseService db;
  final Position? myPosition;

  const _RequestCard({
    required this.request,
    required this.db,
    this.myPosition,
  });

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestDetailPage(request: request),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Blood type badge + urgency dot
            Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      request.donorBloodType,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _urgencyColor(request.urgency),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(request.recipientName,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _urgencyColor(request.urgency)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          request.urgency.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _urgencyColor(request.urgency),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${request.unitsNeeded} unit(s) · ${request.hospitalName ?? request.location ?? 'Unknown'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: DistanceBadge(
                          myPosition: myPosition,
                          destLat: request.hospitalLat ?? request.patientLat,
                          destLng: request.hospitalLng ?? request.patientLng,
                          fallbackLocation: request.location,
                        ),
                      ),
                      if (request.patientDisease != null) ...[const SizedBox(width: 8),
                        Icon(Icons.medical_services,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(request.patientDisease!,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Requests Browser Tab ───────────────────────────

class _DonorRequestsBrowser extends StatefulWidget {
  final UserModel? user;
  final DatabaseService db;

  const _DonorRequestsBrowser({required this.user, required this.db});

  @override
  State<_DonorRequestsBrowser> createState() => _DonorRequestsBrowserState();
}

class _DonorRequestsBrowserState extends State<_DonorRequestsBrowser>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  Position? _myPosition;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final result = await LocationService().getPositionDetailed();
    if (mounted) {
      setState(() => _myPosition = result.position);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Filter donations by search query (name, blood type, hospital, urgency, location)
  List<DonationModel> _filterRequests(List<DonationModel> list) {
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((r) {
      return r.recipientName.toLowerCase().contains(q) ||
          r.donorBloodType.toLowerCase().contains(q) ||
          (r.hospitalName?.toLowerCase().contains(q) ?? false) ||
          r.urgency.toLowerCase().contains(q) ||
          (r.location?.toLowerCase().contains(q) ?? false) ||
          (r.hospitalAddress?.toLowerCase().contains(q) ?? false) ||
          (r.patientDisease?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, blood type, hospital, urgency…',
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
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
          ),
        ),
        TabBar(
          controller: _tab,
          labelColor: Colors.red.shade600,
          indicatorColor: Colors.red.shade600,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'All Requests'),
            Tab(text: 'My Accepted'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              // All pending requests
              StreamBuilder<List<DonationModel>>(
                stream: widget.db.getPendingBloodRequests(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final all = snap.data ?? [];
                  final list = _filterRequests(all);
                  if (all.isNotEmpty && list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No requests match "$_searchQuery"',
                              style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: const Text('Clear search'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (list.isEmpty) {
                    return const Center(child: Text('No pending requests'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _RequestCard(
                      request: list[i],
                      db: widget.db,
                      myPosition: _myPosition,
                    ),
                  );
                },
              ),
              // My accepted donations
              StreamBuilder<List<DonationModel>>(
                stream: widget.db.getAcceptedDonationsForDonor(uid),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return const Center(
                        child: Text('You haven\'t accepted any requests yet'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _DonorDonationTile(
                      donation: list[i],
                      myPosition: _myPosition,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonorDonationTile extends StatelessWidget {
  final DonationModel donation;
  final Position? myPosition;

  const _DonorDonationTile({required this.donation, this.myPosition});

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'accepted':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestDetailPage(request: donation),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _statusColor(donation.status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(donation.recipientName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        donation.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          color: _statusColor(donation.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: DistanceBadge(
                          myPosition: myPosition,
                          destLat: donation.hospitalLat ?? donation.patientLat,
                          destLng: donation.hospitalLng ?? donation.patientLng,
                          fallbackLocation: donation.location,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              donation.donorBloodType,
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ─────────── My Accepted Preview (Dashboard) ───────────

class _MyAcceptedPreview extends StatelessWidget {
  final DatabaseService db;
  final String uid;

  const _MyAcceptedPreview({required this.db, required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<DonationModel>>(
      stream: db.getAcceptedDonationsForDonor(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('No accepted requests yet',
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        final recent = list.take(3).toList();
        return Column(
          children: recent
              .map((d) => _DonorDonationTile(donation: d))
              .toList(),
        );
      },
    );
  }
}

// ─────────── Reusable Widgets ───────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
