import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class SupportScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SupportScreen({super.key, required this.userData});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> with SingleTickerProviderStateMixin {
  final User _user = FirebaseAuth.instance.currentUser!;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRaiseTicketDialog() {
    final TextEditingController subjectCtrl = TextEditingController();
    final TextEditingController descCtrl = TextEditingController();
    String category = 'Technical';
    String dept = 'IT Support';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            left: 24,
            right: 24,
            top: 32,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Raise Ticket", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: AppColors.grey)),
                  ],
                ),
                const SizedBox(height: 24),
                
                Text("ISSUE CATEGORY", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.grey, letterSpacing: 1)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.slateLighter),
                  ),
                  child: DropdownButton<String>(
                    value: category,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: ['Technical', 'Financial', 'Academic', 'Others'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          category = val;
                          if (val == 'Technical') dept = 'IT Support';
                          else if (val == 'Financial') dept = 'Accounts Office';
                          else if (val == 'Academic') dept = 'Academic Cell';
                          else dept = 'General Admin';
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),
                
                TextFormField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(
                    labelText: "Subject",
                    hintText: "Briefly what's wrong?",
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "Detailed Description",
                    hintText: "Tell us more about your issue...",
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (subjectCtrl.text.isEmpty || descCtrl.text.isEmpty) return;
                      
                      await FirebaseFirestore.instance.collection('support_tickets').add({
                        'uid': _user.uid,
                        'studentName': widget.userData['name'] ?? 'Student',
                        'regNo': widget.userData['regNo'] ?? 'N/A',
                        'studentDept': (widget.userData['dept'] ?? 'N/A').toString().trim(),
                        'category': category,
                        'visibility': [dept, (widget.userData['dept'] ?? 'N/A').toString().trim()],
                        'department': dept,
                        'subject': subjectCtrl.text,
                        'description': descCtrl.text,
                        'status': 'open',
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Ticket raised. Our team will review it."), backgroundColor: AppColors.success)
                        );
                      }
                    },
                    child: const Text("SUBMIT TICKET"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help Center'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.red,
          unselectedLabelColor: AppColors.grey,
          indicatorColor: AppColors.red,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
          tabs: const [
            Tab(text: "DIRECT SUPPORT"),
            Tab(text: "MY TICKETS"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContactsTab(),
          _buildTicketsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRaiseTicketDialog,
        backgroundColor: AppColors.red,
        icon: const Icon(Icons.add_comment_rounded, color: Colors.white, size: 20),
        label: const Text("RAISE TICKET", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildContactsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildInstitutionalHeader(),
        const SizedBox(height: 32),
        const Text("Support Channels", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate)),
        const SizedBox(height: 16),
        _buildSupportCategory("Accounts Office", "Fee records, wallet issues & bank transfers.", Icons.account_balance_rounded, AppColors.red, "accounts@aec.edu", "+91 94440 12345"),
        _buildSupportCategory("Technical Helpdesk", "Login issues, portal errors & access.", Icons.computer_rounded, const Color(0xFF3498DB), "support@aec.edu", "+91 94440 67890"),
        _buildSupportCategory("Academic Cell", "Registration, scholarships & certificates.", Icons.school_rounded, const Color(0xFFF39C12), "academic@aec.edu", "+91 94440 54321"),
        const SizedBox(height: 32),
        _buildOfficeDetails(),
        const SizedBox(height: 80), // Fab space
      ],
    );
  }

  Widget _buildTicketsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_tickets')
          .where('uid', isEqualTo: _user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.confirmation_number_outlined, size: 72, color: AppColors.slateLighter),
                const SizedBox(height: 16),
                const Text("No active tickets", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.slateLight, fontSize: 16)),
                const SizedBox(height: 8),
                const Text("We're here to help when you need it.", style: TextStyle(color: AppColors.grey, fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildTicketCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildTicketCard(String docId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'open';
    final Color statusColor = status == 'open' ? AppColors.info : (status == 'resolved' ? AppColors.success : AppColors.grey);
    
    String dateStr = '—';
    if (data['createdAt'] != null) {
      dateStr = DateFormat('dd MMM, hh:mm a').format((data['createdAt'] as Timestamp).toDate());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppColors.grey,
          title: Text(data['subject'] ?? 'No Subject', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate)),
          subtitle: Row(
            children: [
              Text(data['category'] ?? 'General', style: const TextStyle(fontSize: 12, color: AppColors.slateLight)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AppColors.slateLighter),
                  const SizedBox(height: 8),
                  const Text("MESSAGE LOG", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.grey, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Text(data['description'] ?? 'No description provided.', style: const TextStyle(fontSize: 13, color: AppColors.slate, height: 1.5)),
                  if (data['resolutionNote'] != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.mark_chat_read_rounded, color: AppColors.success, size: 16),
                              SizedBox(width: 8),
                              Text("ADMIN RESOLUTION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.success)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(data['resolutionNote'], style: const TextStyle(fontSize: 13, color: AppColors.slate)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Department: ${data['department']}", style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.grey)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.red),
                        onPressed: () => _confirmDeleteTicket(docId),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTicket(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Ticket?"),
        content: const Text("This action will permanently remove this ticket from your history."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: AppColors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('support_tickets').doc(docId).delete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ticket deleted")));
              }
            },
            child: const Text("DELETE", style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionalHeader() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: AppColors.redGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.premiumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Help Center", style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            "Access direct support from AEC's official administrative and technical teams.", 
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.5, fontWeight: FontWeight.w500)
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCategory(String title, String desc, IconData icon, Color color, String email, String phone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.softShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate)),
          subtitle: Text(desc, style: const TextStyle(color: AppColors.slateLight, fontSize: 12)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    _detailRow(Icons.alternate_email_rounded, email),
                    const SizedBox(height: 12),
                    _detailRow(Icons.phone_android_rounded, phone),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.grey),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: AppColors.slate, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildOfficeDetails() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slateLighter.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("OFFICE HOURS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.grey, letterSpacing: 1)),
          const SizedBox(height: 16),
          _officeRow("Mon - Fri", "09:00 AM - 04:30 PM"),
          const SizedBox(height: 8),
          _officeRow("Saturday", "09:00 AM - 12:30 PM"),
          const SizedBox(height: 8),
          _officeRow("Sunday", "Holiday (Closed)"),
          const Divider(height: 48, color: AppColors.slateLighter),
          const Row(
            children: [
              Icon(Icons.location_on_rounded, color: AppColors.red, size: 20),
              SizedBox(width: 8),
              Text("Admin Block, Ground Floor", style: TextStyle(color: AppColors.slateLight, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          )
        ],
      ),
    );
  }

  Widget _officeRow(String days, String hours) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(days, style: const TextStyle(color: AppColors.slateLight, fontSize: 13, fontWeight: FontWeight.w500)),
        Text(hours, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate)),
      ],
    );
  }
}
