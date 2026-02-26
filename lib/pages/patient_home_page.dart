import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/donation_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'find_donors_page.dart';
import 'blood_request_page.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  final AuthService _authService = AuthService();
  final DatabaseService _db = DatabaseService();
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<UserModel?>(
      stream: _db.getUserStream(uid),
      builder: (context, snapshot) {
        final user = snapshot.data;

        final pages = [
          _PatientDashboard(user: user, db: _db),
          const FindDonorsPage(),
          _MyRequestsTab(db: _db, uid: uid),
          const ProfilePage(),
        ];

        return Scaffold(
          appBar: _buildAppBar(user),
          body: pages[_currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            indicatorColor: Colors.blue.shade100,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: 'Find Donors',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment),
                label: 'My Requests',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
          floatingActionButton: _currentIndex == 0 || _currentIndex == 2
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BloodRequestPage())),
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Request Blood'),
                )
              : null,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(UserModel? user) {
    return AppBar(
      backgroundColor: Colors.blue.shade600,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LifeFlow',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('Patient · ${user?.name ?? ''}',
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

// ─────────────────────────── Dashboard ───────────────────────────

class _PatientDashboard extends StatelessWidget {
  final UserModel? user;
  final DatabaseService db;

  const _PatientDashboard({required this.user, required this.db});

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
                colors: [Colors.blue.shade700, Colors.blue.shade400],
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
                        'Hello, ${user?.name.split(' ').first ?? 'there'}! 💙',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Find a donor or post a blood request',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.personal_injury,
                    color: Colors.white.withValues(alpha: 0.4), size: 48),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Quick Actions
          const Text('Quick Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.add_circle_outline,
                  label: 'Request Blood',
                  description: 'Post an urgent request',
                  color: Colors.blue.shade600,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BloodRequestPage())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.search,
                  label: 'Find Donors',
                  description: 'Search by blood type',
                  color: Colors.green.shade600,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const FindDonorsPage())),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // My Active Requests
          const Text('My Active Requests',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _ActiveRequestsPreview(
              db: db,
              uid: FirebaseAuth.instance.currentUser?.uid ?? ''),
          const SizedBox(height: 24),

          // Available Donors
          const Text('Available Donors',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _AvailableDonorsList(db: db),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(description,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

// ─────────── Active Requests Preview ───────────

class _ActiveRequestsPreview extends StatelessWidget {
  final DatabaseService db;
  final String uid;

  const _ActiveRequestsPreview({required this.db, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DonationModel>>(
      stream: db.getUserDonationRequests(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data ?? [];
        final active = list
            .where((r) => r.status == 'pending' || r.status == 'accepted')
            .take(3)
            .toList();

        if (active.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined,
                    size: 36, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                const Text('No active requests',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text('Tap "Request Blood" to create one',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        return Column(
          children: active
              .map((r) => _PatientRequestTile(request: r))
              .toList(),
        );
      },
    );
  }
}

class _PatientRequestTile extends StatelessWidget {
  final DonationModel request;

  const _PatientRequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final isAccepted = request.status == 'accepted';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                isAccepted ? Colors.green.shade200 : Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isAccepted ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isAccepted ? Icons.check_circle : Icons.hourglass_top,
              color: isAccepted ? Colors.green : Colors.orange,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.donorBloodType} blood needed',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                if (request.notes != null)
                  Text(request.notes!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isAccepted ? Colors.green.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isAccepted ? 'Accepted' : 'Pending',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isAccepted ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────── Available Donors List ───────────

class _AvailableDonorsList extends StatelessWidget {
  final DatabaseService db;

  const _AvailableDonorsList({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: db.getAvailableDonors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final donors = snapshot.data ?? [];
        if (donors.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('No donors available at the moment',
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: donors.length > 5 ? 5 : donors.length,
          itemBuilder: (_, i) => _DonorTile(donor: donors[i]),
        );
      },
    );
  }
}

class _DonorTile extends StatelessWidget {
  final UserModel donor;

  const _DonorTile({required this.donor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.green.shade100,
            backgroundImage: donor.photoUrl != null
                ? NetworkImage(donor.photoUrl!)
                : null,
            child: donor.photoUrl == null
                ? Text(
                    donor.name.isNotEmpty
                        ? donor.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(donor.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (donor.bloodType != null) ...[
                      Icon(Icons.bloodtype,
                          size: 12, color: Colors.red.shade400),
                      const SizedBox(width: 3),
                      Text(donor.bloodType!,
                          style: TextStyle(
                              fontSize: 12, color: Colors.red.shade600,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                    ],
                    if (donor.location != null)
                      Row(children: [
                        Icon(Icons.location_on,
                            size: 12, color: Colors.grey.shade500),
                        Text(donor.location!,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ]),
                  ],
                ),
                if (donor.totalDonations > 0)
                  Text('${donor.totalDonations} donations',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, color: Colors.green, size: 14),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── My Requests Tab ───────────────────────────

class _MyRequestsTab extends StatefulWidget {
  final DatabaseService db;
  final String uid;

  const _MyRequestsTab({required this.db, required this.uid});

  @override
  State<_MyRequestsTab> createState() => _MyRequestsTabState();
}

class _MyRequestsTabState extends State<_MyRequestsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tab,
          labelColor: Colors.blue.shade600,
          indicatorColor: Colors.blue.shade600,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'Completed'),
          ],
        ),
        Expanded(
          child: StreamBuilder<List<DonationModel>>(
            stream: widget.db.getUserDonationRequests(widget.uid),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snap.data ?? [];
              return TabBarView(
                controller: _tab,
                children: [
                  _RequestList(
                      requests: all
                          .where((r) => r.status == 'pending')
                          .toList()),
                  _RequestList(
                      requests: all
                          .where((r) => r.status == 'accepted')
                          .toList()),
                  _RequestList(
                      requests: all
                          .where((r) =>
                              r.status == 'completed' ||
                              r.status == 'cancelled')
                          .toList()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RequestList extends StatelessWidget {
  final List<DonationModel> requests;

  const _RequestList({required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(child: Text('No requests in this category'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (_, i) => _PatientRequestTile(request: requests[i]),
    );
  }
}
