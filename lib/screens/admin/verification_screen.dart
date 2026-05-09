import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/fee_service.dart';

class VerificationScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId; 
  final String studentId;

  const VerificationScreen({
    super.key, 
    required this.data, 
    required this.docId, 
    required this.studentId
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _isProcessing = false;
  final _reasonCtrl = TextEditingController();

  Future<void> _verifyPayment() async {
    setState(() => _isProcessing = true);
    try {
      await FeeService().verifyPaymentComponent(widget.docId, true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Institutional verification successful. Confirmation dispatched."), backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Verification Failed: $e"), backgroundColor: AppColors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectPayment() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text("Issue Rejection", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please specify the exact reason for rejecting this transaction. This will be visible to the student."),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "e.g., Transaction ID mismatch or blurred receipt",
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: AppColors.slateLight, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("REJECT", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      await FeeService().verifyPaymentComponent(widget.docId, false, rejectionReason: _reasonCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transaction rejected and applicant notified."), backgroundColor: AppColors.slate));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String receiptUrl = widget.data['proofUrl'] ?? widget.data['receiptUrl'] ?? '';
    final double amount = (widget.data['amount'] as num?)?.toDouble() ?? 0.0;
    final String semester = widget.data['semester'] ?? 'N/A';
    final String studentName = widget.data['studentName'] ?? 'Unknown Applicant';
    final String transactionId = widget.data['transactionId'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(studentName),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: InteractiveViewer(
              child: receiptUrl.isNotEmpty && receiptUrl.startsWith('http') 
                  ? Image.network(
                      receiptUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null, color: Colors.white));
                      },
                      errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white, size: 48)),
                    )
                  : const Center(child: Icon(Icons.link_off_rounded, color: Colors.white70, size: 48)),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("INSTITUTIONAL VERIFICATION", style: GoogleFonts.outfit(color: AppColors.grey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                          const SizedBox(height: 8),
                          Text("₹ ${amount.toStringAsFixed(0)}", style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.red)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                      child: Text((widget.data['paymentMode'] ?? 'UPI').toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.red, letterSpacing: 0.5)),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                _detailTile(Icons.person_outline_rounded, "Applicant", studentName),
                _detailTile(Icons.badge_outlined, "Registration No", widget.data['studentRegNo'] ?? 'N/A'),
                _detailTile(Icons.account_tree_outlined, "Fee Entity", widget.data['feeType'] ?? 'General Fee'),
                _detailTile(Icons.receipt_long_outlined, "Transaction ID", transactionId),
                
                if (widget.data['ocr'] != null) ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: AppColors.slateLighter)),
                  _buildOcrAudit(),
                ],
                
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : _rejectPayment,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red,
                          side: const BorderSide(color: AppColors.red, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("ISSUE REJECTION", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _verifyPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isProcessing 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                          : const Text("APPROVE AS VALID", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.slateLighter.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppColors.slateLight),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.grey, letterSpacing: 0.5)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOcrAudit() {
    final ocr = widget.data['ocr'] as Map<String, dynamic>;
    final original = ocr['original'] as Map<String, dynamic>? ?? {};
    final edited = ocr['edited'] as Map<String, dynamic>? ?? {};
    final ocrVerified = ocr['verified'] == true;
    final ocrRan = ocr['ran'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(ocrVerified ? Icons.verified_rounded : Icons.warning_amber_rounded, size: 18, color: ocrVerified ? AppColors.success : AppColors.red),
            const SizedBox(width: 8),
            Text(
              ocrRan ? (ocrVerified ? "OCR Match Verified" : "Data Discrepancies Detected") : "OCR Audit Skipped",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: ocrVerified ? AppColors.success : AppColors.red),
            ),
          ],
        ),
        if (ocrRan) ...[
          const SizedBox(height: 12),
          _buildOcrRow('transactionId', 'TXN ID', original, edited),
          _buildOcrRow('amount', 'Amount', original, edited),
          _buildOcrRow('regNo', 'ID Match', original, edited),
        ],
      ],
    );
  }

  Widget _buildOcrRow(String field, String label, Map<String, dynamic> original, Map<String, dynamic> edited) {
    final orig = original[field]?.toString();
    final wasEdited = edited[field] == true;
    if (orig == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const SizedBox(width: 26),
          Text("$label: ", style: const TextStyle(fontSize: 12, color: AppColors.slateLight, fontWeight: FontWeight.w500)),
          Text(orig, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: wasEdited ? AppColors.red : AppColors.success)),
          if (wasEdited) ...[
            const SizedBox(width: 8),
            const Icon(Icons.edit_rounded, size: 14, color: AppColors.red),
          ],
        ],
      ),
    );
  }
}