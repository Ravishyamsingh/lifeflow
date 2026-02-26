import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'otp_verification_page.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final AuthService _authService = AuthService();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String _selectedCountryCode = '+91';

  // Common country codes
  final List<Map<String, String>> _countryCodes = [
    {'code': '+91', 'country': 'IN', 'flag': '🇮🇳'},
    {'code': '+1', 'country': 'US', 'flag': '🇺🇸'},
    {'code': '+44', 'country': 'UK', 'flag': '🇬🇧'},
    {'code': '+61', 'country': 'AU', 'flag': '🇦🇺'},
    {'code': '+971', 'country': 'AE', 'flag': '🇦🇪'},
    {'code': '+966', 'country': 'SA', 'flag': '🇸🇦'},
    {'code': '+880', 'country': 'BD', 'flag': '🇧🇩'},
    {'code': '+92', 'country': 'PK', 'flag': '🇵🇰'},
    {'code': '+977', 'country': 'NP', 'flag': '🇳🇵'},
    {'code': '+94', 'country': 'LK', 'flag': '🇱🇰'},
    {'code': '+86', 'country': 'CN', 'flag': '🇨🇳'},
    {'code': '+81', 'country': 'JP', 'flag': '🇯🇵'},
    {'code': '+49', 'country': 'DE', 'flag': '🇩🇪'},
    {'code': '+33', 'country': 'FR', 'flag': '🇫🇷'},
    {'code': '+39', 'country': 'IT', 'flag': '🇮🇹'},
    {'code': '+55', 'country': 'BR', 'flag': '🇧🇷'},
    {'code': '+234', 'country': 'NG', 'flag': '🇳🇬'},
    {'code': '+27', 'country': 'ZA', 'flag': '🇿🇦'},
    {'code': '+82', 'country': 'KR', 'flag': '🇰🇷'},
    {'code': '+7', 'country': 'RU', 'flag': '🇷🇺'},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber {
    return '$_selectedCountryCode${_phoneController.text.trim()}';
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: _fullPhoneNumber,
        onCodeSent: (verificationId) {
          if (mounted) {
            setState(() => _isLoading = false);
            // Navigate to OTP verification page
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OtpVerificationPage(
                  phoneNumber: _fullPhoneNumber,
                  verificationId: verificationId,
                ),
              ),
            );
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: Colors.red.shade400,
              ),
            );
          }
        },
        onAutoVerified: (credential) async {
          // Android auto-verification
          try {
            await _authService.signInWithPhoneCredential(credential);
            // Auth state stream will handle navigation
          } catch (e) {
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.toString()),
                  backgroundColor: Colors.red.shade400,
                ),
              );
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  void _showCountryCodePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Select Country',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 0),
              Expanded(
                child: ListView.builder(
                  itemCount: _countryCodes.length,
                  itemBuilder: (context, index) {
                    final country = _countryCodes[index];
                    final isSelected =
                        country['code'] == _selectedCountryCode;
                    return ListTile(
                      leading: Text(
                        country['flag']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(country['country']!),
                      trailing: Text(
                        country['code']!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.red.shade600
                              : Colors.black,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: Colors.red.shade50,
                      onTap: () {
                        setState(() {
                          _selectedCountryCode = country['code']!;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Find current country info
    final currentCountry = _countryCodes.firstWhere(
      (c) => c['code'] == _selectedCountryCode,
      orElse: () => _countryCodes.first,
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.phone_android,
                  size: 40,
                  color: Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              const Text(
                'Phone Verification',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                'Enter your phone number to receive a\nverification code via SMS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // Phone Input
              Form(
                key: _formKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phone Number',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Country Code Selector
                          GestureDetector(
                            onTap: _showCountryCodePicker,
                            child: Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    currentCountry['flag']!,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedCountryCode,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.grey.shade600,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Phone Number Input
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(12),
                              ],
                              decoration: InputDecoration(
                                hintText: 'Enter phone number',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.normal,
                                  letterSpacing: 0,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                prefixIcon: Icon(
                                  Icons.phone_outlined,
                                  color: Colors.grey.shade600,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.red.shade600,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.red.shade400,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                if (value.length < 7) {
                                  return 'Phone number is too short';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Send OTP Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Send Verification Code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),

              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A 6-digit verification code will be sent to your phone number via SMS. Standard messaging rates may apply.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Terms
              Text(
                'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
