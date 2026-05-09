import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';
import '../theme/app_colors.dart';
import '../services/error_handler.dart';

class IdentityVerificationScreen extends StatefulWidget {
  final String userType; // 'student' or 'staff'
  const IdentityVerificationScreen({super.key, this.userType = 'student'});

  @override
  State<IdentityVerificationScreen> createState() => _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen> {
  final _idCtrl = TextEditingController(); 
  final _otpCtrl = TextEditingController();
  
  bool _isLoading = false;
  bool _otpSent = false;
  String? _verificationId;
  int? _resendToken;
  
  Map<String, dynamic>? _userData;
  String _maskedPhone = "";

  String get _idLabel => widget.userType == 'student' ? "Registration Number" : "Employee ID";
  String get _collectionName => widget.userType == 'student' ? 'student_master_list' : 'staff_master_list';

  void _lookupUser() async {
    if (_idCtrl.text.trim().isEmpty) {
      ErrorHandler.showError(context, "Please enter $_idLabel");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection(_collectionName).doc(_idCtrl.text.trim()).get();
      
      if (!doc.exists) {
        if (mounted) {
           ErrorHandler.showError(context, "$_idLabel not found in college records. Please contact Admin.");
        }
        setState(() => _isLoading = false);
        return;
      }

      final data = doc.data()!;
      if (data['isRegistered'] == true) {
        if (mounted) {
           ErrorHandler.showWarning(context, "This user is already registered. Please Login.");
        }
        setState(() => _isLoading = false);
        return;
      }

      _userData = data;
      String phone = data['phone'] ?? '';
      
      if (phone.length > 4) {
        _maskedPhone = phone.replaceRange(0, phone.length - 4, '*' * (phone.length - 4));
      } else {
        _maskedPhone = "****";
      }

      _sendOTP(phone);

    } catch (e) {
      ErrorHandler.showError(context, "Error: $e");
      setState(() => _isLoading = false);
    }
  }

  void _sendOTP(String phoneNumber) async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          ErrorHandler.showError(context, "Verification Failed: ${e.message}");
          setState(() => _isLoading = false);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _otpSent = true;
            _isLoading = false;
          });
          ErrorHandler.showSuccess(context, "OTP Sent to your registered mobile number");
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      ErrorHandler.showError(context, "Error sending OTP: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpCtrl.text.isEmpty || _verificationId == null) return;

    setState(() => _isLoading = true);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpCtrl.text.trim()
      );
      
      await _signInWithCredential(credential);
    } catch (e) {
      ErrorHandler.showError(context, "Invalid OTP: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      await FirebaseAuth.instance.signOut(); 
      
      if (mounted) {
         Navigator.pushReplacement(
           context, 
           MaterialPageRoute(
             builder: (_) => RegisterScreen(
               verifiedStudentData: widget.userType == 'student' ? _userData : null,
               verifiedStaffData: widget.userType == 'staff' ? _userData : null,
             )
           )
         );
      }
    } catch (e) {
         ErrorHandler.showError(context, "OTP Error: $e");
         setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "${widget.userType == 'student' ? 'Student' : 'Staff'} Verification",
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              // THEME CARD
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppColors.premiumShadow,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.red.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _otpSent ? Icons.mark_email_read_rounded : Icons.verified_user_rounded, 
                        size: 64, 
                        color: AppColors.red
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _otpSent ? "Verify OTP" : "Identity Check", 
                      style: const TextStyle(
                        fontSize: 26, 
                        fontWeight: FontWeight.bold, 
                        color: AppColors.slate
                      )
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _otpSent 
                        ? "We've sent a 6-digit code to your registered mobile number ending in $_maskedPhone"
                        : "Please enter your official $_idLabel. We will verify this against the college master records.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.slateLight, fontSize: 15, height: 1.5),
                    ),
                    const SizedBox(height: 48),
                    
                    if (!_otpSent) ...[
                      // ID INPUT
                      TextFormField(
                        controller: _idCtrl,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        decoration: InputDecoration(
                          labelText: _idLabel,
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _lookupUser,
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5) 
                            : const Text("VERIFY & SEND OTP"),
                        ),
                      ),
                    ] else ...[
                      // OTP INPUT
                      TextFormField(
                        controller: _otpCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: "6-Digit OTP",
                          prefixIcon: Icon(Icons.lock_clock_outlined),
                          counterText: "",
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOTP,
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5) 
                            : const Text("CONFIRM & REGISTER"),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => setState(() {
                          _otpSent = false;
                          _isLoading = false;
                          _otpCtrl.clear();
                        }),
                        child: Text(
                          "Change $_idLabel",
                          style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 48),
              // SECURITY NOTE
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.shield_outlined, size: 16, color: AppColors.grey.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Text(
                    "Secure Identity Verification System", 
                    style: TextStyle(color: AppColors.grey.withOpacity(0.5), fontSize: 12)
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}