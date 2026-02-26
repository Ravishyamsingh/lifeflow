import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/auth_service.dart';

class OtpVerificationPage extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OtpVerificationPage({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final AuthService _authService = AuthService();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late String _verificationId;
  bool _isLoading = false;
  bool _isResending = false;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _otpCode {
    return _otpControllers.map((c) => c.text).join();
  }

  Future<void> _verifyOTP() async {
    final code = _otpCode;
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter the complete 6-digit code'),
          backgroundColor: Colors.red.shade400,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.verifyOTP(
        verificationId: _verificationId,
        smsCode: code,
      );
      // On success, FirebaseAuth stream in main.dart will navigate to HomePage
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade400,
          ),
        );
        // Clear OTP fields on error
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_resendTimer > 0) return;

    setState(() => _isResending = true);

    try {
      await _authService.resendOTP(
        phoneNumber: widget.phoneNumber,
        onCodeSent: (verificationId) {
          setState(() {
            _verificationId = verificationId;
            _isResending = false;
          });
          _startResendTimer();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('New OTP sent successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() => _isResending = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: Colors.red.shade400,
              ),
            );
          }
        },
        onAutoVerified: (credential) async {
          setState(() => _isResending = false);
          try {
            await _authService.signInWithPhoneCredential(credential);
          } catch (e) {
            if (mounted) {
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
        setState(() => _isResending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Icons.sms_outlined,
                  size: 40,
                  color: Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              const Text(
                'Verification Code',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                'We have sent the verification code to',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.phoneNumber,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 40),

              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    width: 48,
                    height: 56,
                    margin: EdgeInsets.only(
                      right: index < 5 ? 8 : 0,
                      left: index == 3 ? 8 : 0, // Extra gap after 3rd digit
                    ),
                    child: TextFormField(
                      controller: _otpControllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.red.shade600,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          // Move to next field
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          // Move to previous field on backspace
                          _focusNodes[index - 1].requestFocus();
                        }

                        // Auto-verify when all 6 digits entered
                        if (_otpCode.length == 6) {
                          _verifyOTP();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
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
                          'Verify & Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),

              // Resend Code
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Didn\'t receive the code? ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (_isResending)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red.shade600,
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _resendTimer == 0 ? _resendCode : null,
                      child: Text(
                        _resendTimer > 0
                            ? 'Resend in ${_resendTimer}s'
                            : 'Resend Code',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _resendTimer > 0
                              ? Colors.grey.shade400
                              : Colors.red.shade600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Change number link
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Change phone number',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
