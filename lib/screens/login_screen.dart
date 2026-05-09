import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../services/error_handler.dart';
import '../utils/validators.dart';
import 'identity_verification_screen.dart';
import 'student/student_dashboard.dart';
import 'admin/admin_dashboard.dart';
import 'staff/staff_dashboard.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final userData = await _authService.loginUser(_emailCtrl.text.trim(), _passCtrl.text.trim());
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (userData != null) {
        final role = (userData['role'] as String? ?? '').trim().toLowerCase();
        Widget nextScreen = role == 'admin' ? const AdminDashboard() : (role == 'staff' ? const StaffDashboard() : const StudentDashboard());
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => nextScreen));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = ErrorHandler.getFirebaseErrorMessage(e);
      if (msg.toLowerCase().contains('pending admin approval') || msg.toLowerCase().contains('pending')) {
        _showApprovalPendingDialog();
      } else {
        ErrorHandler.showError(context, msg);
      }
    }
  }

  void _showApprovalPendingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.warning),
          const SizedBox(width: 12),
          Text("Verification Pending", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ]),
        content: const Text("Your institutional account is currently under review by the administration. You will receive an automated email once your access is granted."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("UNDERSTOOD", style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Gradient Accent
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(color: AppColors.red.withOpacity(0.03), shape: BoxShape.circle),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  children: [
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppColors.softShadow),
                        child: Image.asset(
                          'assets/app_logo.png',
                          width: 80,
                          height: 80,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.school_rounded, size: 64, color: AppColors.red),
                        ),
                      ),
                    ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 24),
                    Text("A-DACS", style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.red, letterSpacing: 1.5))
                        .animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
                    Text("Digital Clearance Center", style: GoogleFonts.outfit(fontSize: 14, color: AppColors.slateLight, fontWeight: FontWeight.w500, letterSpacing: 1))
                        .animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
                    const SizedBox(height: 48),
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(32), boxShadow: AppColors.premiumShadow),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text("Welcome Back", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate)),
                            const SizedBox(height: 8),
                            const Text("Authorized personnel & student sign-in", style: TextStyle(fontSize: 14, color: AppColors.slateLight, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.validateEmail,
                              decoration: const InputDecoration(labelText: "Institutional Email", prefixIcon: Icon(Icons.email_outlined, color: AppColors.red)),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: _obscurePassword,
                              validator: Validators.validatePassword,
                              decoration: InputDecoration(
                                labelText: "Password",
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.red),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.black, size: 20),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            SizedBox(
                              height: 60,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                child: _isLoading 
                                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                                  : const Text("SIGN IN", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: () => _showRegistrationTypeDialog(context),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500),
                          children: const [
                            TextSpan(text: "New to A-DACS? ", style: TextStyle(color: AppColors.slateLight)),
                            TextSpan(text: "Register Now", style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRegistrationTypeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text("Initiate Registry", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _registerTile(
              icon: Icons.school_rounded,
              color: AppColors.red,
              label: "Student Enrollment",
              subtitle: "Requires APEC Student Credentials",
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const IdentityVerificationScreen()));
              },
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: AppColors.slateLighter)),
            _registerTile(
              icon: Icons.admin_panel_settings_rounded,
              color: AppColors.info,
              label: "Staff / Faculty",
              subtitle: "Institutional Employee Verification",
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const IdentityVerificationScreen(userType: 'staff')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _registerTile({required IconData icon, required Color color, required String label, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.slateLight, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.slateLighter),
          ],
        ),
      ),
    );
  }
}