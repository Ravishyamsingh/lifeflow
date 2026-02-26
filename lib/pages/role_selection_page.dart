import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'donor_home_page.dart';
import 'patient_home_page.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  final DatabaseService _db = DatabaseService();
  String? _selectedRole;
  bool _isSaving = false;

  Future<void> _confirm() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your role to continue')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await _db.updateUserRole(uid, _selectedRole!);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => _selectedRole == 'donor'
              ? const DonorHomePage()
              : const PatientHomePage(),
        ),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Header
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: 28),
              const Center(
                child: Text(
                  'How will you use LifeFlow?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Choose your role to personalize your experience.\nYou can change this later in settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                ),
              ),
              const SizedBox(height: 48),

              // Donor Card
              _RoleCard(
                role: 'donor',
                selected: _selectedRole == 'donor',
                icon: Icons.volunteer_activism,
                color: Colors.red.shade600,
                title: 'I am a Donor',
                subtitle: 'I want to donate blood and save lives',
                benefits: const [
                  'Toggle availability to donate',
                  'Browse blood requests near you',
                  'Track your donation history',
                  'See impact — lives you\'ve saved',
                ],
                onTap: () => setState(() => _selectedRole = 'donor'),
              ),
              const SizedBox(height: 20),

              // Patient Card
              _RoleCard(
                role: 'patient',
                selected: _selectedRole == 'patient',
                icon: Icons.personal_injury,
                color: Colors.blue.shade600,
                title: 'I am a Patient / Seeker',
                subtitle: 'I need blood or am requesting for someone',
                benefits: const [
                  'Post urgent blood requests',
                  'Search available donors nearby',
                  'Track your requests in real-time',
                  'Get notified when a donor accepts',
                ],
                onTap: () => setState(() => _selectedRole = 'patient'),
              ),

              const Spacer(),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_isSaving || _selectedRole == null) ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String role;
  final bool selected;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<String> benefits;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.selected,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.benefits,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected ? color : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon,
                  color: selected ? Colors.white : Colors.grey.shade500, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: selected ? color : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      if (selected)
                        Icon(Icons.check_circle, color: color, size: 22),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...benefits.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          Icon(Icons.check, size: 14, color: color),
                          const SizedBox(width: 6),
                          Text(b,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
