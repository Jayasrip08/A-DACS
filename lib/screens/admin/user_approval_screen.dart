import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/notification_service.dart';
import '../../services/email_service.dart';
import '../../widgets/notification_badge.dart';
import '../notifications_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

class UserApprovalScreen extends StatelessWidget {
  final Widget? drawer;
  const UserApprovalScreen({super.key, this.drawer});

  Future<void> _approveUser(BuildContext context, String uid, String name, String email, String role) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'approvalStatus': 'approved',
      });
      
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': uid,
        'title': 'Account Approved',
        'body': 'Congratulations! Your account has been approved. You can now access all features.',
        'type': 'account_approved',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'received': false,
      });
      
      await EmailService().sendApprovalEmail(
        studentEmail: email, 
        studentName: name, 
        role: role.toLowerCase()
      );
      
      if (context.mounted) {
        NotificationService.showSuccess("$name has been approved and notified!");
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Approval Error: $e"), backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _rejectUser(BuildContext context, String uid, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text("Revoke Enrollment?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text("Are you certain you want to reject $name? This action permanently removes their record from the institutional registry."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: AppColors.slateLight, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red, 
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("REJECT & DELETE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User removed from registry."), backgroundColor: AppColors.slate));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Deletion Error: $e"), backgroundColor: AppColors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: drawer,
      appBar: AppBar(
        title: Text("Enrollment Approvals", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          NotificationBadge(
            child: const Icon(Icons.notifications_none_rounded, color: Colors.white),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('approvalStatus', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeletonLoader();
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.08), shape: BoxShape.circle),
                    child: const Icon(Icons.verified_user_rounded, size: 64, color: AppColors.success),
                  ),
                  const SizedBox(height: 24),
                  Text("Registry Cleared", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate)),
                  const SizedBox(height: 8),
                  const Text("All pending enrollments have been processed.", style: TextStyle(color: AppColors.slateLight, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              final uid = users[index].id;
              final name = user['name'] ?? 'Unknown applicant';
              final email = user['email'] ?? 'No contact provided';
              final role = (user['role'] ?? 'student').toString().toUpperCase();
              
              String roleLabel = role == 'STUDENT' ? 'CANDIDATE' : 'FACULTY';
              String regNo = role == 'STUDENT' 
                ? (user['regNo'] ?? user['registerNo'] ?? 'PENDING ID')
                : (user['employeeId'] ?? 'PENDING ID');
              String dept = user['dept'] ?? 'NO DEPT';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppColors.softShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(color: AppColors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                        child: Center(child: Text(name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.red))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.slate)),
                            const SizedBox(height: 4),
                            Text(email, style: const TextStyle(color: AppColors.slateLight, fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                                  child: Text(roleLabel, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text("$regNo • $dept", style: const TextStyle(color: AppColors.slateLight, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          _buildActionButton(
                            icon: Icons.check_rounded, 
                            color: AppColors.success, 
                            onTap: () => _approveUser(context, uid, name, email, role),
                            tooltip: "Approve Enrollment"
                          ),
                          const SizedBox(height: 8),
                          _buildActionButton(
                            icon: Icons.close_rounded, 
                            color: AppColors.red, 
                            onTap: () => _rejectUser(context, uid, name),
                            tooltip: "Reject Applicant"
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOut);
            },
          );
        },
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          width: double.infinity,
          height: 100,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onTap, required String tooltip}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}