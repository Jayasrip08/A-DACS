import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_colors.dart';
import 'semester_detail_screen.dart';
import 'documents_screen.dart';
import 'clearance_screen.dart';
import 'fees_ledger_screen.dart';
import 'support_screen.dart';
import '../profile_screen.dart';
import '../notifications_screen.dart';
import '../../widgets/notification_badge.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final User user = FirebaseAuth.instance.currentUser!;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      if (mounted) {
        setState(() {
          _userData = userDoc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  Widget _buildBody() {
    if (_isLoading) return _buildSkeletonLoader();
    
    switch (_currentIndex) {
      case 1:
        return const NotificationsScreen();
      case 2:
        return const ProfileScreen();
      default:
        return _buildHomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _currentIndex == 0 
        ? AppBar(
            title: const Text("A-DACS"),
            actions: [
              NotificationBadge(
                child: const Icon(Icons.notifications_none_rounded, color: AppColors.slate),
                onTap: () => setState(() => _currentIndex = 1),
              ),
              const SizedBox(width: 16),
            ],
          )
        : null,
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: AppColors.red,
          unselectedItemColor: AppColors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: "Board"),
            BottomNavigationBarItem(icon: Icon(Icons.campaign_outlined), label: "Notice"),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: "Profile"),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('semesters')
          .where('academicYear', isEqualTo: _userData!['batch'] ?? '')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeletonLoader();
        }

        final docs = snapshot.data?.docs ?? [];
        
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            _buildGreetingHeader(),
            const SizedBox(height: 24),
            _buildWalletCard(),
            const SizedBox(height: 32),
            const Text("Services", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate)),
            const SizedBox(height: 16),
            _buildStaticQuickActions(),
            const SizedBox(height: 32),
            _buildDynamicClearedHighlights(),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Active Semesters", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate)),
                if (docs.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(12)),
                    child: Text("${docs.length} Active", style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (docs.isEmpty) 
              _buildEmptyState()
            else
              ...docs.map((doc) => _buildSemesterCard(doc)),
            const SizedBox(height: 20),
          ],
        ).animate().fadeIn(duration: 400.ms);
      },
    );
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 100, height: 16, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(width: 150, height: 32, color: Colors.white),
                ],
              ),
              Container(width: 60, height: 30, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
            ],
          ),
          const SizedBox(height: 24),
          Container(width: double.infinity, height: 160, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
          const SizedBox(height: 32),
          Container(width: 100, height: 20, color: Colors.white),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (index) => Column(
              children: [
                Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
                const SizedBox(height: 10),
                Container(width: 40, height: 12, color: Colors.white),
              ],
            )),
          ),
          const SizedBox(height: 32),
          Container(width: double.infinity, height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader() {
    String firstName = _userData!['name']?.split(' ')[0] ?? 'Student';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${_getGreeting()},", style: const TextStyle(color: AppColors.slateLight, fontSize: 16)),
            Text(
              firstName,
              style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.slate),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.red.withOpacity(0.1)),
          ),
          child: Text(
            _userData!['dept'] ?? 'N/A',
            style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildStaticQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _quickActionItem(Icons.history_edu_rounded, "Clearance", color: const Color(0xFF3498DB), onTap: () => _nav(ClearanceScreen(userData: _userData!))),
        _quickActionItem(Icons.account_balance_rounded, "Fees", color: AppColors.red, onTap: () => _nav(FeesLedgerScreen(userData: _userData!))),
        _quickActionItem(Icons.file_present_rounded, "Files", color: AppColors.slate, onTap: () => _nav(DocumentsScreen(userData: _userData!))),
        _quickActionItem(Icons.help_outline_rounded, "Help", color: const Color(0xFFF39C12), onTap: () => _nav(SupportScreen(userData: _userData!))),
      ],
    );
  }

  void _nav(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildDynamicClearedHighlights() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('no_due_certificates')
          .where('uid', isEqualTo: user.uid)
          .where('status', isEqualTo: 'issued')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink(); 
        final certificates = snapshot.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Milestones", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate)),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: certificates.length,
                itemBuilder: (context, index) {
                  final data = certificates[index].data() as Map<String, dynamic>;
                  return _clearedSemesterItem(data['semester']?.toString() ?? '?');
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _clearedSemesterItem(String sem) {
    return GestureDetector(
      onTap: () => _nav(SemesterDetailScreen(userData: _userData!, semester: sem)),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(height: 8),
            Text("Sem $sem", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate)),
            const Text("CLEARED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.green, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _quickActionItem(IconData icon, String label, {required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppColors.softShadow,
              border: Border.all(color: AppColors.slateLighter.withOpacity(0.5)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.slate, fontWeight: FontWeight.w600)),
        ],
      ),
    ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack);
  }

  Widget _buildWalletCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('wallets').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        double balance = 0.0;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          balance = (data?['balance'] as num?)?.toDouble() ?? 0.0;
        } else {
          balance = (_userData?['walletBalance'] as num?)?.toDouble() ?? 0.0;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: AppColors.redGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.premiumShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Wallet Balance", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  Icon(Icons.account_balance_wallet_rounded, color: Colors.white.withOpacity(0.2), size: 32),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "₹${balance.toStringAsFixed(0)}",
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: const Text("Automatic Fee Deduction Active", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
      },
    );
  }

  Widget _buildSemesterCard(QueryDocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String sem = data['semesterNumber'].toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.softShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: AppColors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text(sem, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 20))),
        ),
        title: Text("Semester $sem", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.slate)),
        subtitle: Text(data['academicSession'] ?? 'Active Session', style: const TextStyle(color: AppColors.slateLight)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.grey),
        onTap: () => _nav(SemesterDetailScreen(userData: _userData!, semester: sem)),
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0, curve: Curves.easeOut);
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 48),
        Icon(Icons.school_outlined, size: 80, color: AppColors.slateLighter),
        const SizedBox(height: 20),
        const Text("No Active Semesters", style: TextStyle(color: AppColors.slateLight, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}