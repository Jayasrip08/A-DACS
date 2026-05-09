import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_colors.dart';
import '../../services/fee_service.dart';

class FeesLedgerScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const FeesLedgerScreen({super.key, required this.userData});

  @override
  State<FeesLedgerScreen> createState() => _FeesLedgerScreenState();
}

class _FeesLedgerScreenState extends State<FeesLedgerScreen> {
  final User _user = FirebaseAuth.instance.currentUser!;

  Future<Map<String, double>> _calculateOverallTotals() async {
    double totalExpected = 0;
    final String dept = widget.userData['dept'] ?? '';
    final String quota = widget.userData['quotaCategory'] ?? '';
    final String batch = widget.userData['batch'] ?? '';
    final String studentType = widget.userData['studentType'] ?? 'day_scholar';

    // Calculation logic preserved for accuracy
    for (int i = 1; i <= 8; i++) {
       final structure = await FeeService().getFeeComponents(dept, quota, batch, "Semester $i");
       if (structure != null) {
          totalExpected += (structure['examFee'] as num?)?.toDouble() ?? 0.0;
          Map<String, dynamic> components = structure['components'] ?? {};
          for (var entry in components.entries) {
            String type = entry.key;
            var val = entry.value;
            if (type.toLowerCase().contains('hostel') && studentType != 'hosteller') continue;
            if (type.toLowerCase().contains('bus') && studentType != 'bus_user') continue;
            if (val is num) totalExpected += val.toDouble();
            else if (val is Map) {
              String? busPlace = widget.userData['busPlace'];
              if (busPlace != null && val.containsKey(busPlace)) {
                totalExpected += (val[busPlace] as num).toDouble();
              }
            }
          }
       }
    }

    double walletBalance = 0;
    try {
      final wDoc = await FirebaseFirestore.instance.collection('wallets').doc(_user.uid).get();
      if (wDoc.exists) {
        walletBalance = (wDoc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (_) {}

    return {
      'totalExpected': totalExpected,
      'walletBalance': walletBalance,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, double>>(
      future: _calculateOverallTotals(),
      builder: (context, totalsSnapshot) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Degree Ledger'),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('payments')
                .where('studentId', isEqualTo: _user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting || !totalsSnapshot.hasData) {
                return _buildSkeletonLoader();
              }

              final docs = snapshot.data?.docs ?? [];
              double totalPaid = 0;
              double totalPendingVerification = 0;

              List<Map<String, dynamic>> transactions = [];
              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'unknown';
                final amt = (data['amountPaid'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0.0;
                
                if (status == 'verified') {
                  totalPaid += amt;
                } else if (status == 'pending' || status == 'under_review') {
                  totalPendingVerification += amt;
                }
                transactions.add({'id': doc.id, ...data});
              }

              transactions.sort((a, b) {
                Timestamp? tA = a['submittedAt'] as Timestamp?;
                Timestamp? tB = b['submittedAt'] as Timestamp?;
                if (tA == null && tB == null) return 0;
                if (tA == null) return 1;
                if (tB == null) return -1;
                return tB.compareTo(tA);
              });

              final expected = totalsSnapshot.data!['totalExpected'] ?? 0.0;
              final wallet = totalsSnapshot.data!['walletBalance'] ?? 0.0;
              final outstanding = expected - (totalPaid + wallet);

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                children: [
                  _buildLedgerSummary(totalPaid, totalPendingVerification, expected, outstanding, wallet),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, color: AppColors.slate, size: 20),
                      const SizedBox(width: 8),
                      Text('PAYMENT HISTORY', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate, letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (transactions.isEmpty) 
                    _buildEmptyState()
                  else
                    ...transactions.map((tx) => _buildTransactionCard(tx)),
                ],
              );
            },
          ),
        );
      }
    );
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          Container(width: double.infinity, height: 280, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
          const SizedBox(height: 32),
          Container(width: 150, height: 20, color: Colors.white),
          const SizedBox(height: 16),
          ...List.generate(3, (index) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          )),
        ],
      ),
    );
  }

  Widget _buildLedgerSummary(double verified, double pending, double totalDegree, double outstanding, double wallet) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.premiumShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              gradient: AppColors.redGradient,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("DEGREE FINANCIAL SUMMARY", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    Icon(Icons.account_balance_rounded, color: Colors.white.withOpacity(0.3), size: 20),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Outstanding", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text("₹${outstanding.toStringAsFixed(0)}", style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    _summaryBadge("Paid", "₹${verified.toStringAsFixed(0)}"),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _ledgerRow("Total Course Fee (8 Sems)", "₹${totalDegree.toStringAsFixed(0)}"),
                const SizedBox(height: 16),
                _ledgerRow("Wallet Credit Available", "₹${wallet.toStringAsFixed(0)}", color: AppColors.success, isHighlight: true),
                const SizedBox(height: 16),
                _ledgerRow("Verification in Progress", "₹${pending.toStringAsFixed(0)}", color: AppColors.warning),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1, end: 0, curve: Curves.easeOut);
  }

  Widget _summaryBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _ledgerRow(String label, String value, {Color? color, bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.slateLight, fontSize: 13, fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(color: color ?? AppColors.slate, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final status = tx['status'] ?? 'unknown';
    final amt = (tx['amountPaid'] as num?)?.toDouble() ?? (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final feeType = tx['feeType'] ?? tx['id'].split('_').last ?? 'Fee';
    final semester = tx['semester'] ?? 'N/A';
    
    String dateStr = '—';
    if (tx['submittedAt'] != null) {
      dateStr = DateFormat('dd MMM yyyy, hh:mm a').format((tx['submittedAt'] as Timestamp).toDate());
    }

    Color sColor = AppColors.grey;
    IconData sIcon = Icons.help_outline_rounded;
    if (status == 'verified') { sColor = AppColors.success; sIcon = Icons.check_circle_rounded; }
    else if (status == 'under_review' || status == 'pending') { sColor = AppColors.warning; sIcon = Icons.hourglass_top_rounded; }
    else if (status == 'rejected') { sColor = AppColors.red; sIcon = Icons.error_outline_rounded; }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: sColor.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                  child: Icon(sIcon, color: sColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(feeType.toString().replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate)),
                      const SizedBox(height: 4),
                      Text("Semester $semester", style: const TextStyle(color: AppColors.slateLight, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("₹${amt.toStringAsFixed(0)}", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.slate)),
                    const SizedBox(height: 4),
                    Text(status.toUpperCase(), style: TextStyle(color: sColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ],
                ),
              ],
            ),
            const Divider(height: 32, color: AppColors.slateLighter),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dateStr, style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                if (status == 'verified')
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download_rounded, size: 14, color: AppColors.red),
                    label: const Text("Digital Receipt", style: TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0, curve: Curves.easeOut);
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 64),
        Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.slateLighter),
        const SizedBox(height: 20),
        const Text("No transactions recorded", style: TextStyle(color: AppColors.slateLight, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
