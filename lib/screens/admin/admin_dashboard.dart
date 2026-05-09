import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'admin_side_menu.dart';
import 'fee_setup_screen.dart';
import 'view_fees_screen.dart';
import 'academic_year_screen.dart';
import 'overdue_payments_screen.dart';
import 'user_approval_screen.dart';
import '../profile_screen.dart';
import '../notifications_screen.dart';
import '../../widgets/notification_badge.dart';
import 'admin_payment_list.dart';
import 'admin_student_list.dart';
import 'admin_staff_list.dart';
import 'department_screen.dart';
import 'quota_screen.dart';
import 'admin_student_database.dart';
import 'admin_staff_database.dart';
import 'admin_nodue_requests.dart'; 
import 'admin_analytics_screen.dart';
import 'manage_payment_methods.dart';
import '../support_inbox_screen.dart';
import '../../theme/app_colors.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0; 
  int _bottomNavIndex = 0; 
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sideMenu = AdminSideMenu(
      selectedIndex: _selectedIndex,
      onItemSelected: (index) {
        setState(() => _selectedIndex = index);
        if (Navigator.canPop(context)) Navigator.pop(context);
      },
      excludeIndices: const [1, 3, 5, 11, 12], 
    );

    if (_selectedIndex == 0) {
      return Scaffold(
        backgroundColor: AppColors.background,
        drawer: sideMenu,
        appBar: AppBar(
          backgroundColor: AppColors.red,
          foregroundColor: Colors.white,
          title: const Text("Admin Console"),
          actions: [
            NotificationBadge(
              child: const Icon(Icons.notifications_none_rounded, color: Colors.white),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              },
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                gradient: AppColors.redGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: AppColors.premiumShadow,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Quick Management",
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildQuickAction(Icons.settings_suggest_rounded, "Fee Setup", 3),
                        _buildQuickAction(Icons.analytics_rounded, "Analytics", 12),
                        _buildQuickAction(Icons.payment_rounded, "Payments", 11),
                        _buildQuickAction(Icons.calendar_today_rounded, "Session", 5),
                        _buildQuickAction(Icons.confirmation_number_rounded, "Clearance", 13),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _bottomNavIndex = index);
                },
                children: const [
                  PaymentListTab(isPending: true),
                  PaymentListTab(isPending: false),
                  AdminStudentList(),
                  AdminStaffList(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
          ),
          child: BottomNavigationBar(
            currentIndex: _bottomNavIndex,
            onTap: (index) {
              setState(() => _bottomNavIndex = index);
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            },
            selectedItemColor: AppColors.red,
            unselectedItemColor: AppColors.grey,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.surface,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.notifications_active_rounded), activeIcon: Icon(Icons.notifications_active), label: 'Pending'),
              BottomNavigationBarItem(icon: Icon(Icons.history_rounded), activeIcon: Icon(Icons.history), label: 'History'),
              BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), activeIcon: Icon(Icons.people_alt_rounded), label: 'Students'),
              BottomNavigationBarItem(icon: Icon(Icons.badge_outlined), activeIcon: Icon(Icons.badge_rounded), label: 'Staff'),
            ],
          ),
        ),
      );
    }

    // Sub-Pages
    Widget content;
    switch (_selectedIndex) {
      case 1: content = UserApprovalScreen(drawer: sideMenu); break;
      case 2: content = OverduePaymentsScreen(drawer: sideMenu); break;
      case 3: content = FeeSetupScreen(drawer: sideMenu); break;
      case 4: content = ViewFeesScreen(drawer: sideMenu); break;
      case 5: content = AcademicYearScreen(drawer: sideMenu); break;
      case 6: content = DepartmentScreen(drawer: sideMenu); break;
      case 7: content = QuotaScreen(drawer: sideMenu); break;
      case 8: content = AdminStudentDatabase(drawer: sideMenu); break; 
      case 9: content = AdminStaffDatabase(drawer: sideMenu); break;
      case 10: content = ProfileScreen(drawer: sideMenu, showLogout: false); break;
      case 11: content = ManagePaymentMethodsScreen(drawer: sideMenu); break;
      case 12: content = AdminAnalyticsScreen(drawer: sideMenu); break;
      case 13: content = AdminNoDueRequestsScreen(drawer: sideMenu); break;
      case 14: content = SupportInboxScreen(drawer: sideMenu); break;
      default: content = const Center(child: Text("Page not found"));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _selectedIndex = 0);
      },
      child: content,
    ); 
  }

  Widget _buildQuickAction(IconData icon, String label, int index) {
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.red, size: 28),
            ),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ).animate().scale(delay: (index * 50).ms, curve: Curves.easeOutBack),
    );
  }
}