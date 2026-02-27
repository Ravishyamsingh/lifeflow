import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/donation_model.dart';
import '../services/database_service.dart';

class DonationHistoryPage extends StatefulWidget {
  const DonationHistoryPage({super.key});

  @override
  State<DonationHistoryPage> createState() => _DonationHistoryPageState();
}

class _DonationHistoryPageState extends State<DonationHistoryPage>
    with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('User not found')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Donation History',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.red.shade600,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.red.shade600,
          tabs: const [
            Tab(text: 'My Donations'),
            Tab(text: 'My Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Donations Tab
          _buildDonationsList(
            stream: _databaseService.getUserDonations(currentUser.uid),
            emptyMessage: 'You haven\'t made any donations yet',
            emptySubtitle: 'Start donating to save lives!',
            isDonation: true,
          ),

          // My Requests Tab
          _buildDonationsList(
            stream: _databaseService.getUserDonationRequests(currentUser.uid),
            emptyMessage: 'You haven\'t made any requests yet',
            emptySubtitle: 'Request blood when you need it',
            isDonation: false,
          ),
        ],
      ),
    );
  }

  Widget _buildDonationsList({
    required Stream<List<DonationModel>> stream,
    required String emptyMessage,
    required String emptySubtitle,
    required bool isDonation,
  }) {
    return StreamBuilder<List<DonationModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Error loading data',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        final donations = snapshot.data ?? [];

        if (donations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isDonation ? Icons.favorite_border : Icons.bloodtype,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  emptySubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: donations.length,
          itemBuilder: (context, index) {
            final donation = donations[index];
            return _buildDonationCard(donation, isDonation);
          },
        );
      },
    );
  }

  Widget _buildDonationCard(DonationModel donation, bool isDonation) {
    final statusColor = _getStatusColor(donation.status);
    final statusText = _getStatusText(donation.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showDonationDetails(donation),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Blood type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bloodtype,
                            size: 18, color: Colors.red.shade600),
                        const SizedBox(width: 4),
                        Text(
                          donation.donorBloodType,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Names
              Text(
                isDonation
                    ? 'Recipient: ${donation.recipientName}'
                    : 'Donor: ${donation.donorName.isNotEmpty ? donation.donorName : 'Waiting for donor'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Date and location
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(donation.donationDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (donation.location != null &&
                      donation.location!.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.location_on,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        donation.location!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),

              // Action buttons for pending requests
              if (donation.status == 'pending' && !isDonation) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _cancelDonation(donation.donationId),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDonationDetails(DonationModel donation) {
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
              'Donation Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Blood Type', donation.donorBloodType),
            _buildDetailRow('Status', _getStatusText(donation.status)),
            _buildDetailRow('Date', _formatDate(donation.donationDate)),
            _buildDetailRow('Location', donation.location ?? 'Not specified'),
            _buildDetailRow(
                'Donor', donation.donorName.isNotEmpty ? donation.donorName : 'Waiting'),
            _buildDetailRow('Recipient', donation.recipientName),
            if (donation.notes != null && donation.notes!.isNotEmpty)
              _buildDetailRow('Notes', donation.notes!),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _cancelDonation(String donationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
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
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _databaseService.cancelDonation(donationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
