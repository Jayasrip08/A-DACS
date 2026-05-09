import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_colors.dart';
import '../../services/fee_service.dart';
import 'verification_screen.dart';

class PaymentListTab extends StatefulWidget {
  final bool isPending;

  const PaymentListTab({super.key, required this.isPending});

  @override
  State<PaymentListTab> createState() => _PaymentListTabState();
}

class _PaymentListTabState extends State<PaymentListTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    Query query = FirebaseFirestore.instance.collection('payments');
    if (widget.isPending) {
      query = query.where('status', isEqualTo: 'under_review');
    } else {
      query = query.where('status', whereIn: ['verified', 'rejected']);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.softShadow,
            ),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Search name or registration number...",
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.red),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.grey, size: 20),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = "");
                      })
                  : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: SelectableText("Error: ${snapshot.error}", style: const TextStyle(color: AppColors.red)));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSkeletonLoader();
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.isPending ? Icons.fact_check_outlined : Icons.history_rounded, size: 80, color: AppColors.slateLighter),
                      const SizedBox(height: 16),
                      Text(
                        widget.isPending ? "No pending approvals" : "No transaction history",
                        style: const TextStyle(fontSize: 16, color: AppColors.slateLight, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }

              final allDocs = snapshot.data!.docs.toList();
              allDocs.sort((a, b) {
                final aTime = (a.data() as Map<String, dynamic>)['submittedAt'] as Timestamp?;
                final bTime = (b.data() as Map<String, dynamic>)['submittedAt'] as Timestamp?;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

              final filteredDocs = allDocs.where((doc) {
                if (_searchQuery.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>;
                final regNo = (data['studentRegNo'] ?? data['uid'] ?? '').toString().toLowerCase();
                final name = (data['studentName'] ?? '').toString().toLowerCase();
                return regNo.contains(_searchQuery) || name.contains(_searchQuery);
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(child: Text("No matching records found", style: TextStyle(color: AppColors.slateLight)));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  var doc = filteredDocs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  String studentName = data['studentName'] ?? 'Unknown Student';
                  String regNo = data['studentRegNo'] ?? data['uid'] ?? 'No ID';
                  String dept = data['dept'] ?? 'GEN';
                  double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                  String transactionId = data['transactionId'] ?? 'Manual';
                  String feeType = data['feeType'] ?? 'Institutional Fee';
                  String status = data['status'] ?? '';
                  Timestamp? submittedAt = data['submittedAt'] as Timestamp?;
                  String dateStr = submittedAt != null ? DateFormat('dd MMM, hh:mm a').format(submittedAt.toDate()) : 'Recent';

                  Color statusColor = status == 'verified' ? AppColors.success : (status == 'rejected' ? AppColors.red : AppColors.warning);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                         if (widget.isPending) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => VerificationScreen(data: data, docId: doc.id, studentId: data['uid'])));
                         } else {
                            _showRevertDialog(context, doc.id, status);
                         }
                      }, 
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(color: AppColors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                                  child: Center(child: Text(studentName[0].toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.red))),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate)),
                                      const SizedBox(height: 4),
                                      Text("$regNo  •  $dept", style: const TextStyle(fontSize: 12, color: AppColors.slateLight, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: statusColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                                  child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Divider(color: AppColors.slateLighter, height: 1),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(feeType, style: const TextStyle(color: AppColors.slateLight, fontSize: 12, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Text("₹${amount.toStringAsFixed(0)}", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.red)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.grey, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: widget.isPending ? AppColors.info.withOpacity(0.1) : AppColors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            widget.isPending ? "VERIFY" : "REVERT",
                                            style: TextStyle(color: widget.isPending ? AppColors.info : AppColors.red, fontWeight: FontWeight.w900, fontSize: 11),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(widget.isPending ? Icons.chevron_right_rounded : Icons.history_rounded, size: 16, color: widget.isPending ? AppColors.info : AppColors.red),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (transactionId != 'Manual') ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.receipt_long_rounded, size: 14, color: AppColors.slateLight),
                                  const SizedBox(width: 8),
                                  Text(transactionId, style: GoogleFonts.robotoMono(fontSize: 11, color: AppColors.slateLight)),
                                ],
                              ),
                            ],
                            if (status == 'rejected' && data['rejectionReason'] != null)
                              Container(
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.red.withOpacity(0.1))),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.red),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text("Reason: ${data['rejectionReason']}", style: const TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w500))),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOut);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: 4,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }

  void _showRevertDialog(BuildContext context, String docId, String currentStatus) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text("Revert Transaction?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text("This payment is marked as ${currentStatus.toUpperCase()}. Do you want to move it back to 'Under Review' status?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: AppColors.slateLight, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await FeeService().revertPayment(docId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transaction Reverted to Review Status"), backgroundColor: AppColors.slate));
              }
            },
            child: const Text("REVERT TO REVIEW", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}