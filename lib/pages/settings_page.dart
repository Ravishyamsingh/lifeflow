import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'find_donors_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  final currentUser = FirebaseAuth.instance.currentUser;

  // --- Color Palette ---
  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _deepBlue = Color(0xFF1565C0);
  static const Color _teal = Color(0xFF00897B);
  static const Color _orange = Color(0xFFF57C00);
  static const Color _amber = Color(0xFFFFB300);
  static const Color _purple = Color(0xFF7B1FA2);
  static const Color _green = Color(0xFF43A047);
  static const Color _dangerRed = Color(0xFFD32F2F);
  static const Color _slate = Color(0xFF546E7A);

  bool _notificationsEnabled = true;
  bool _emailUpdates = true;
  bool _availableToDonate = false;

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('User not found')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _deepBlue,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<UserModel?>(
        stream: _databaseService.getUserStream(currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: _primaryBlue),
            );
          }

          final user = snapshot.data;
          if (user != null) {
            _availableToDonate = user.isAvailableToDonate;
          }

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                // ── Find Nearest Blood Bank – Hero Card ──
                _buildBloodBankCard(),
                const SizedBox(height: 20),

                // ── Donation Status ──
                _buildSectionHeader('Donation Status'),
                const SizedBox(height: 8),
                _buildCard(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.volunteer_activism,
                      iconColor: _green,
                      activeColor: _green,
                      title: 'Available to Donate',
                      subtitle:
                          'Let others know you\'re ready to help save lives',
                      value: _availableToDonate,
                      onChanged: (value) async {
                        setState(() => _availableToDonate = value);
                        final messenger = ScaffoldMessenger.of(context);
                        await _databaseService.setDonationAvailability(
                          currentUser!.uid,
                          value,
                        );
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'You are now available to donate'
                                    : 'You are no longer available to donate',
                              ),
                              backgroundColor: _green,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Notifications ──
                _buildSectionHeader('Notifications'),
                const SizedBox(height: 8),
                _buildCard(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.notifications_active_outlined,
                      iconColor: _orange,
                      activeColor: _orange,
                      title: 'Push Notifications',
                      subtitle: 'Get notified about donation requests',
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() => _notificationsEnabled = value);
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildSwitchTile(
                      icon: Icons.mark_email_unread_outlined,
                      iconColor: _primaryBlue,
                      activeColor: _primaryBlue,
                      title: 'Email Updates',
                      subtitle: 'Receive updates via email',
                      value: _emailUpdates,
                      onChanged: (value) {
                        setState(() => _emailUpdates = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── About ──
                _buildSectionHeader('About'),
                const SizedBox(height: 8),
                _buildCard(
                  children: [
                    _buildNavigationTile(
                      icon: Icons.bloodtype_outlined,
                      iconColor: _teal,
                      title: 'About LifeFlow',
                      subtitle: 'Learn more about our mission',
                      onTap: _showAboutDialog,
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildNavigationTile(
                      icon: Icons.gavel_outlined,
                      iconColor: _amber,
                      title: 'Terms of Service',
                      subtitle: 'Read our terms and conditions',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Terms of Service will open'),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildNavigationTile(
                      icon: Icons.shield_outlined,
                      iconColor: _purple,
                      title: 'Privacy Policy',
                      subtitle: 'How we protect your data',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Privacy Policy will open'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Account ──
                _buildSectionHeader('Account'),
                const SizedBox(height: 8),
                _buildCard(
                  children: [
                    _buildNavigationTile(
                      icon: Icons.lock_reset_outlined,
                      iconColor: _slate,
                      title: 'Change Password',
                      subtitle: 'Update your password securely',
                      onTap: _showChangePasswordDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Delete Account – Separate Danger Card ──
                _buildDangerCard(),
                const SizedBox(height: 24),

                // ── Sign Out Button ──
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showSignOutDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _slate,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── App Version ──
                Center(
                  child: Text(
                    'LifeFlow v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ── Hero Card: Find Nearest Blood Bank ──
  // ─────────────────────────────────────────────
  Widget _buildBloodBankCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FindDonorsPage()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _deepBlue.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(
                Icons.local_hospital_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Find Nearest Blood Bank',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Locate blood banks and donors near you',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ── Danger Card: Delete Account ──
  // ─────────────────────────────────────────────
  Widget _buildDangerCard() {
    return Container(
      decoration: BoxDecoration(
        color: _dangerRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _dangerRed.withValues(alpha: 0.25)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          decoration: BoxDecoration(
            color: _dangerRed.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(8),
          child: const Icon(
            Icons.delete_forever_rounded,
            color: _dangerRed,
            size: 24,
          ),
        ),
        title: const Text(
          'Delete Account',
          style: TextStyle(
            color: _dangerRed,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Permanently remove your account and data',
          style: TextStyle(
            fontSize: 12,
            color: _dangerRed.withValues(alpha: 0.7),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: _dangerRed.withValues(alpha: 0.5),
        ),
        onTap: _showDeleteAccountDialog,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ── Shared Widgets ──
  // ─────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required Color activeColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }

  // ─────────────────────────────────────────────
  // ── Dialogs ──
  // ─────────────────────────────────────────────
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.bloodtype_outlined, color: _teal),
            const SizedBox(width: 10),
            const Text('About LifeFlow'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LifeFlow v1.0.0',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'LifeFlow is a community-driven app designed to save lives by '
                'connecting blood donors with those in need.',
              ),
              SizedBox(height: 12),
              Text(
                'Our Mission: To make blood donation accessible and convenient for everyone.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text('Close', style: TextStyle(color: _teal)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_reset_outlined, color: _slate),
            const SizedBox(width: 10),
            const Text('Change Password'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A password reset email will be sent to your email address.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: currentUser?.email,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _primaryBlue),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text('Cancel', style: TextStyle(color: _slate)),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _authService.resetPassword(currentUser!.email!);
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text('Password reset email sent'),
                      backgroundColor: _green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: _dangerRed,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _dangerRed),
            SizedBox(width: 10),
            Text('Delete Account'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone. '
          'All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text('Cancel', style: TextStyle(color: _slate)),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _databaseService.deleteUser(currentUser!.uid);
                await currentUser!.delete();
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text('Account deleted successfully'),
                      backgroundColor: _green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: _dangerRed,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _dangerRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text('Cancel', style: TextStyle(color: _slate)),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _authService.signOut();
                if (mounted) {
                  navigator.pop();
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: _dangerRed,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _slate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
