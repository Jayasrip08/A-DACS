import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../login_screen.dart';

class AdminSideMenu extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final List<int> excludeIndices;

  const AdminSideMenu({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.excludeIndices = const [],
  });

  @override
  State<AdminSideMenu> createState() => _AdminSideMenuState();
}

class _AdminSideMenuState extends State<AdminSideMenu> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topRight: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              children: [
                _buildSectionHeader("MAINFRAME"),
                _buildNavItem(0, "Dashboard", Icons.dashboard_rounded),
                _buildNavItem(2, "Overdue Payments", Icons.warning_amber_rounded),
                _buildNavItem(12, "Income Analytics", Icons.analytics_rounded),
                _buildNavItem(13, "No-Due Requests", Icons.verified_user_rounded),
                _buildNavItem(1, "User Approvals", Icons.how_to_reg_rounded),
                _buildNavItem(14, "Support Inbox", Icons.support_agent_rounded),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Divider(color: AppColors.slateLighter),
                ),
                
                _buildSectionHeader("FEE MANAGEMENT"),
                _buildNavItem(3, "Set New Fee", Icons.add_moderator_rounded),
                _buildNavItem(4, "Structure Repository", Icons.account_tree_rounded),
                _buildNavItem(11, "Payment Settings", Icons.account_balance_rounded),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Divider(color: AppColors.slateLighter),
                ),
                
                _buildSectionHeader("CONFIGURATION"),
                _buildNavItem(5, "Academic Years", Icons.calendar_view_day_rounded),
                _buildNavItem(6, "Departments", Icons.business_rounded),
                _buildNavItem(7, "Student Quotas", Icons.pie_chart_rounded),
                _buildNavItem(8, "Student Database", Icons.person_search_rounded),
                _buildNavItem(9, "Staff Database", Icons.badge_rounded),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Divider(color: AppColors.slateLighter),
                ),
                
                _buildNavItem(10, "Control Profile", Icons.admin_panel_settings_rounded),
              ],
            ),
          ),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 64, 28, 28),
      decoration: const BoxDecoration(
        gradient: AppColors.redGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.security_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 20),
          Text("Admin Console", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("Institutional Management", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 12, top: 8),
      child: Text(
        title, 
        style: GoogleFonts.outfit(color: AppColors.grey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    if (widget.excludeIndices.contains(index)) return const SizedBox.shrink();
    bool isSelected = widget.selectedIndex == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.red.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        leading: Icon(icon, color: isSelected ? AppColors.red : AppColors.slateLight, size: 22),
        title: Text(
          title, 
          style: GoogleFonts.outfit(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.red : AppColors.slate,
            fontSize: 14,
          )
        ),
        onTap: () => widget.onItemSelected(index),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: AppColors.background,
      child: ListTile(
        leading: const Icon(Icons.logout_rounded, color: AppColors.red),
        title: Text('Sign Out', style: GoogleFonts.outfit(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 14)),
        onTap: () async {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context, 
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false
            );
          }
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}