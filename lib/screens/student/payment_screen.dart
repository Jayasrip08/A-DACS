import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/error_handler.dart';
import '../../services/fee_service.dart';

enum PaymentMode { upi, dd }

class PaymentScreen extends StatefulWidget {
  final String feeType;
  final double amount;
  final String semester;

  const PaymentScreen({
    super.key,
    required this.feeType,
    required this.amount,
    required this.semester,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  Map<String, dynamic>? _paymentDetails;
  bool _isLoadingDetails = true;

  int _currentStep = 0;
  PaymentMode _paymentMode = PaymentMode.upi;
  XFile? _imageFile;

  // ── Shared ─────────────────────────────────────────────────
  late TextEditingController _amountCtrl;
  final _dateCtrl = TextEditingController(); // UPI & DD

  // ── UPI-specific ────────────────────────────────────────────
  final _txnCtrl = TextEditingController();
  final _regNoCtrl = TextEditingController(); // pre-filled from OCR

  // ── DD-specific ─────────────────────────────────────────────
  final _ddNumberCtrl = TextEditingController();
  final _ddBankCtrl = TextEditingController();

  bool _isUploading = false;
  bool _isScanning = false;

  // OCR originals (what the scanner read — for comparison by admin)
  String? _ocrOriginalTxn;
  String? _ocrOriginalAmount;
  String? _ocrOriginalDate;
  String? _ocrOriginalRegNo;
  bool _ocrRan = false; // whether OCR was ever performed
  
  // ── Installment logic ──────────────────────────────────────
  bool _isInstallmentMode = false;
  int _installmentNumber = 1;
  double _paidInFirst = 0.0;
  bool _checkingExisting = true;

  // ── Wallet logic ───────────────────────────────────────────
  double _walletBalance = 0.0;
  double _walletToUse = 0.0;
  bool _isWalletFetching = true;

  @override
  void initState() {
    super.initState();
    _amountCtrl =
        TextEditingController(text: widget.amount.toStringAsFixed(0));
    _checkExistingInstallments();
    _fetchPaymentDetails();
    _fetchWalletBalance();
  }

  Future<void> _fetchWalletBalance() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _walletBalance = (doc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
            _isWalletFetching = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching wallet balance: $e");
    } finally {
      if (mounted) setState(() => _isWalletFetching = false);
    }
  }

  Future<void> _checkExistingInstallments() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      String sanitizedType = widget.feeType.replaceAll(" ", "_");
      String paymentId = "${user.uid}_${widget.semester}_$sanitizedType";
      
      var doc = await FirebaseFirestore.instance.collection('payments').doc(paymentId).get();
      if (doc.exists) {
        var data = doc.data()!;
        if (data['status'] == 'verified' || data['status'] == 'under_review') {
          // Installment 1 exists
          setState(() {
            _paidInFirst = (data['amountPaid'] ?? data['amount'] ?? 0).toDouble();
            _isInstallmentMode = true;
            _installmentNumber = 2;
            _amountCtrl.text = (widget.amount - _paidInFirst).toStringAsFixed(0);
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking existing installments: $e");
    } finally {
      if (mounted) setState(() => _checkingExisting = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    _txnCtrl.dispose();
    _regNoCtrl.dispose();
    _ddNumberCtrl.dispose();
    _ddBankCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPaymentDetails() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('payment_methods')
          .doc(widget.feeType)
          .get();
      if (doc.exists) {
        if (mounted) setState(() => _paymentDetails = doc.data());
      } else {
        var d = await FirebaseFirestore.instance
            .collection('payment_methods')
            .doc("All Fees (Default)")
            .get();
        if (d.exists) {
          if (mounted) setState(() => _paymentDetails = d.data());
        }
      }
    } catch (e) {
      debugPrint("Error fetching payment details: $e");
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  // ── UPI REDIRECT ─────────────────────────────────────────────
  Future<void> _launchUPI() async {
    String pa = _paymentDetails?['upiId'] ?? "collegefees@sbi";
    String pn = _paymentDetails?['accountName'] ?? "APEC";
    if (pa.isEmpty) pa = "collegefees@sbi";
    if (pn.isEmpty) pn = "APEC";
    String upiUrl = "upi://pay?pa=$pa&pn=$pn&cu=INR&tn=${widget.feeType}";
    // Only pre-fill the exact amount if it's a full payment, so installments can be flexible
    if (!_isInstallmentMode) {
      upiUrl += "&am=${_amountCtrl.text.trim()}";
    }

    if (await canLaunchUrl(Uri.parse(upiUrl))) {
      await launchUrl(Uri.parse(upiUrl), mode: LaunchMode.externalApplication);
    } else {
      upiUrl = "upi://pay?pa=$pa&pn=$pn&cu=INR";
      if (await canLaunchUrl(Uri.parse(upiUrl))) {
        await launchUrl(Uri.parse(upiUrl),
            mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("No UPI App found. Please pay manually.")));
        }
      }
    }
  }

  // ── IMAGE PICKER (mobile only) ───────────────────────────────
  Future<void> _pickAndScanImage() async {
    if (kIsWeb) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(children: [
            Icon(Icons.smartphone, color: Colors.orange[700]),
            const SizedBox(width: 10),
            const Text("Mobile Required"),
          ]),
          content: const Text(
            "Receipt scanning (OCR) is not supported on web.\n\n"
            "Please use the mobile app to upload your payment receipt.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK", style: TextStyle(color: Colors.indigo)),
            ),
          ],
        ),
      );
      return;
    }
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (pickedFile != null) {
      setState(() => _imageFile = pickedFile);
      await _performOCR(File(pickedFile.path));
    }
  }

  // ── OCR ──────────────────────────────────────────────────────
  Future<void> _performOCR(File image) async {
    setState(() {
      _isScanning = true;
      _ocrOriginalTxn = null;
      _ocrOriginalAmount = null;
      _ocrOriginalDate = null;
      _ocrOriginalRegNo = null;
      _ocrRan = false;
    });

    try {
      final inputImage = InputImage.fromFile(image);
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      final String text = recognizedText.text;
      textRecognizer.close();
      final String lowerText = text.toLowerCase();
      final List<String> lines = text.split('\n');

      // ── Validate receipt/DD ──────────────────────────────────
      final List<String> keywords = _paymentMode == PaymentMode.dd
          ? [
              'demand draft', 'd.d', 'dd no', 'draft no', 'drawn on',
              'payable at', 'bank', 'branch', 'favour', 'favor', 'issuing'
            ]
          : [
              'payment', 'successful', 'paid', 'pay', 'transaction', 'upi',
              'ref', 'amount', 'date', 'google', 'phonepe', 'paytm', 'bhim',
              'cred'
            ];

      int keywordMatches = 0;
      for (var k in keywords) {
        if (lowerText.contains(k)) keywordMatches++;
      }
      if (text.contains('₹') ||
          lowerText.contains('rs.') ||
          lowerText.contains('inr')) {
        keywordMatches++;
      }

      if (keywordMatches < 2) {
        setState(() {
          _imageFile = null;
          _isScanning = false;
        });
        if (mounted) {
          ErrorHandler.showError(
              context,
              _paymentMode == PaymentMode.dd
                  ? "Invalid DD Image: Does not look like a Demand Draft. "
                      "Please upload a clear photo of your DD."
                  : "Invalid Receipt: Does not look like a payment screenshot. "
                      "Please upload a clear image of your payment.");
        }
        return;
      }

      // ── Date extraction (common) ─────────────────────────────
      String? extractedDate;
      final dateRegexes = [
        RegExp(r'\b(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})\b'),
        RegExp(
            r'\b(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})\b',
            caseSensitive: false),
        RegExp(r'\b(\d{4}[\/\-]\d{2}[\/\-]\d{2})\b'),
      ];
      for (var r in dateRegexes) {
        final m = r.firstMatch(text);
        if (m != null) {
          extractedDate = m.group(1);
          break;
        }
      }

      // ── Amount extraction (common) ────────────────────────────
      final amountRegex = RegExp(
          r'(?:(Rs\.?|INR|₹|Total|Amount|Paid)[:\.\-\s]*)?\s?(\d+(?:,\d{3})*(?:\.\d{2})?)',
          caseSensitive: false);
      String? bestAmount;
      double maxScore = -1;
      for (var m in amountRegex.allMatches(text)) {
        final valStr = m.group(2)?.replaceAll(",", "") ?? "";
        final val = double.tryParse(valStr);
        if (val == null || val < 10 || val > 10000000) continue;
        double score = 0;
        if ((val - widget.amount).abs() < 1) score += 100;
        if (m.group(1) != null) score += 20;
        if (score > maxScore) {
          maxScore = score;
          bestAmount = valStr;
        }
      }

      if (_paymentMode == PaymentMode.dd) {
        // ── DD: DD number + bank ─────────────────────────────────
        String? ddNumber;
        final ddNumRegex = RegExp(
            r'(?:dd\s*no\.?|draft\s*no\.?|d\.d\.?\s*no\.?)[:\s]*(\d{6,12})',
            caseSensitive: false);
        final ddNumFallback = RegExp(r'\b(\d{6,12})\b');
        for (var line in lines) {
          final m = ddNumRegex.firstMatch(line);
          if (m != null) {
            ddNumber = m.group(1);
            break;
          }
        }
        if (ddNumber == null) {
          for (var line in lines) {
            if (line.toLowerCase().contains('dd') ||
                line.toLowerCase().contains('draft') ||
                line.toLowerCase().contains('no')) {
              final m = ddNumFallback.firstMatch(line);
              if (m != null) {
                ddNumber = m.group(1);
                break;
              }
            }
          }
        }

        String? bankName;
        for (var line in lines) {
          if (line.toLowerCase().contains('bank') ||
              line.toLowerCase().contains('drawn on') ||
              line.toLowerCase().contains('payable at')) {
            bankName = line.trim();
            if (bankName.isNotEmpty) break;
          }
        }

        // Pre-fill controllers
        if (ddNumber != null) _ddNumberCtrl.text = ddNumber;
        if (bankName != null) _ddBankCtrl.text = bankName;
        if (extractedDate != null) _dateCtrl.text = extractedDate;
        if (bestAmount != null) _amountCtrl.text = bestAmount;

        _ocrOriginalTxn = ddNumber;
        _ocrOriginalAmount = bestAmount;
        _ocrOriginalDate = extractedDate;
      } else {
        // ── UPI: transaction ID + reg no ──────────────────────────
        String? extractedTxn;
        final gatewayRegex = RegExp(
            r'\b(order_|pay_|txn_)[a-zA-Z0-9]{10,30}\b',
            caseSensitive: false);
        final upiRefRegex = RegExp(r'\b\d{12}\b');
        for (var line in lines) {
          final m = gatewayRegex.firstMatch(line);
          if (m != null) {
            extractedTxn = m.group(0);
            break;
          }
        }
        if (extractedTxn == null) {
          for (var line in lines) {
            if (line.toLowerCase().contains('mobile') ||
                line.toLowerCase().contains('reg')) continue;
            final m = upiRefRegex.firstMatch(line);
            if (m != null) {
              extractedTxn = m.group(0);
              break;
            }
          }
        }

        String? extractedRegNo;
        final regNoRegex = RegExp(
            r'(?:reg(?:ister)?(?:\s?no\.?|:|\s)|roll\s?(?:no\.?|:|\s))?\s?(\d{9,15})\b',
            caseSensitive: false);
        for (var line in lines) {
          if (line.toLowerCase().contains('reg') ||
              line.toLowerCase().contains('roll') ||
              line.toLowerCase().contains('student')) {
            final m = regNoRegex.firstMatch(line);
            if (m != null) {
              extractedRegNo = m.group(1);
              break;
            }
          }
        }

        // Pre-fill controllers
        if (extractedTxn != null) _txnCtrl.text = extractedTxn;
        if (bestAmount != null) _amountCtrl.text = bestAmount;
        if (extractedDate != null) _dateCtrl.text = extractedDate;
        if (extractedRegNo != null) _regNoCtrl.text = extractedRegNo;

        _ocrOriginalTxn = extractedTxn;
        _ocrOriginalAmount = bestAmount;
        _ocrOriginalDate = extractedDate;
        _ocrOriginalRegNo = extractedRegNo;
      }

      setState(() {
        _ocrRan = true;
        _isScanning = false;
      });

      if (mounted) {
        final anyFound = _ocrOriginalTxn != null ||
            _ocrOriginalAmount != null ||
            _ocrOriginalDate != null;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(anyFound
              ? "OCR Complete — details pre-filled in Verify step."
              : "Valid document but no clear details found. Please fill manually."),
          backgroundColor: anyFound ? Colors.green : Colors.orange,
        ));
      }
    } catch (e) {
      debugPrint("OCR Error: $e");
      setState(() => _isScanning = false);
    }
  }

  // ── SUBMIT ───────────────────────────────────────────────────
  Future<void> _submitPayment() async {
    if (_imageFile == null) {
      ErrorHandler.showError(context, 'Please upload a receipt / DD image');
      return;
    }

    // Validate
    String refId;
    if (_paymentMode == PaymentMode.dd) {
      refId = _ddNumberCtrl.text.trim();
      if (refId.isEmpty) {
        ErrorHandler.showError(context, 'Please enter the DD Number');
        return;
      }
      if (_ddBankCtrl.text.trim().isEmpty) {
        ErrorHandler.showError(context, 'Please enter the Bank Name');
        return;
      }
      if (_dateCtrl.text.trim().isEmpty) {
        ErrorHandler.showError(context, 'Please enter the DD Date');
        return;
      }
    } else {
      refId = _txnCtrl.text.trim();
      if (refId.isEmpty) {
        refId = "IMG-${DateTime.now().millisecondsSinceEpoch}";
      } else {
        final txnError = Validators.validateTransactionId(refId);
        if (txnError != null) {
          ErrorHandler.showError(context, txnError);
          return;
        }
      }
    }

    final amountError = Validators.validateAmount(_amountCtrl.text);
    if (amountError != null) {
      ErrorHandler.showError(context, amountError);
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      final isDuplicate = await ErrorHandler.checkDuplicatePayment(
        studentId: user.uid,
        transactionId: refId,
      );
      if (isDuplicate) {
        if (mounted) {
          ErrorHandler.showWarning(
              context, 'A payment with this Transaction ID already exists');
        }
        setState(() => _isUploading = false);
        return;
      }

      final storageRef = FirebaseStorage.instance
          .ref()
          .child(
              'receipts/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(File(_imageFile!.path));
      final downloadUrl = await storageRef.getDownloadURL();

      // Fetch student data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final studentRegNo = (userData['regNo'] ?? '') as String;

      // Detect edits: compare final submitted values against OCR originals
      final finalTxn = _paymentMode == PaymentMode.dd
          ? _ddNumberCtrl.text.trim()
          : _txnCtrl.text.trim();
      final finalAmount = _amountCtrl.text.trim();
      final finalDate = _dateCtrl.text.trim();
      final finalRegNo = _regNoCtrl.text.trim();
      final finalBank =
          _paymentMode == PaymentMode.dd ? _ddBankCtrl.text.trim() : null;

      final txnEdited =
          _ocrOriginalTxn != null && finalTxn != _ocrOriginalTxn;
      final amountEdited =
          _ocrOriginalAmount != null && finalAmount != _ocrOriginalAmount;
      final dateEdited =
          _ocrOriginalDate != null && finalDate != _ocrOriginalDate;
      final regNoEdited =
          _ocrOriginalRegNo != null && finalRegNo != _ocrOriginalRegNo;
      final anyEdited =
          txnEdited || amountEdited || dateEdited || regNoEdited;

      // ocrVerified = OCR ran AND no fields were edited
      final ocrVerified = _ocrRan && !anyEdited;

      // Submit via FeeService
      await FeeService().submitComponentProof(
        uid: user.uid,
        semester: widget.semester,
        feeType: widget.feeType,
        amountExpected: widget.amount, 
        amountPaid: double.parse(finalAmount),
        transactionId: refId,
        proofUrl: downloadUrl,
        ocrVerified: ocrVerified,
        isInstallment: _isInstallmentMode,
        installmentNumber: _installmentNumber,
        walletUsedAmount: _walletToUse,
      );

      // Enrich Firestore document with full audit trail
      String sanitizedType = widget.feeType.replaceAll(" ", "_");
      String suffix = (_isInstallmentMode && _installmentNumber == 2) ? "_inst2" : "";
      String paymentId = "${user.uid}_${widget.semester}_$sanitizedType$suffix";

      final Map<String, dynamic> enrichment = {
        'studentId': user.uid,
        'studentName': userData['name'],
        'studentRegNo': studentRegNo,
        'dept': userData['dept'],
        'quota': userData['quotaCategory'],
        'paymentMode': _paymentMode == PaymentMode.dd ? 'dd' : 'upi',
        'isInstallment': _isInstallmentMode,
        'installmentNumber': _isInstallmentMode ? _installmentNumber : 1,
        'totalInstallments': 2,
        'walletUsedAmount': _walletToUse,
        // Full OCR audit trail ...
        'ocr': {
          'ran': _ocrRan,
          'verified': ocrVerified,
          'anyFieldEdited': anyEdited,
          'platform': 'mobile',
          'scannedAt': FieldValue.serverTimestamp(),

          // Original values extracted from image
          'original': {
            'transactionId': _ocrOriginalTxn,
            'amount': _ocrOriginalAmount,
            'date': _ocrOriginalDate,
            'regNo': _ocrOriginalRegNo,
          },

          // Final values submitted by student (may differ if edited)
          'submitted': {
            'transactionId': finalTxn,
            'amount': finalAmount,
            'date': finalDate,
            'regNo': finalRegNo,
            if (finalBank != null) 'bankName': finalBank,
          },

          // Per-field edit flags (admin can see exactly what was changed)
          'edited': {
            'transactionId': txnEdited,
            'amount': amountEdited,
            'date': dateEdited,
            'regNo': regNoEdited,
          },

          // Ground-truth student reg no from users collection
          'studentRegNoGroundTruth': studentRegNo,
        },
      };

      if (_paymentMode == PaymentMode.dd) {
        enrichment['ddDetails'] = {
          'ddNumber': finalTxn,
          'bankName': finalBank,
          'ddDate': finalDate,
          'amount': finalAmount,
          'submittedAt': FieldValue.serverTimestamp(),
        };
      }

      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .update(enrichment);

      if (mounted) {
        ErrorHandler.showSuccess(
            context,
            _paymentMode == PaymentMode.dd
                ? 'DD details submitted! Please also deliver the physical DD '
                    'to the college accounts office. Admin will verify shortly.'
                : 'Receipt submitted successfully! Admin will review it soon.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, "Submission Failed: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pay & Verify")),
      body: _isLoadingDetails
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep == 0) {
                  setState(() => _currentStep++);
                } else if (_currentStep == 1) {
                  if (_imageFile == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            "Please upload a receipt / DD photo first.")));
                    return;
                  }
                  setState(() => _currentStep++);
                } else {
                  _submitPayment();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) setState(() => _currentStep--);
              },
              controlsBuilder: (BuildContext context, ControlsDetails details) {
                String continueLabel = "Continue";
                if (_currentStep == 0) continueLabel = "Pay or Upload Receipt";
                if (_currentStep == 1) continueLabel = "Verify Details";
                if (_currentStep == 2) continueLabel = "Submit Receipt for Verification";

                return Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(continueLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      if (_currentStep > 0) ...[
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Back'),
                        ),
                      ],
                    ],
                  ),
                );
              },
              steps: [
                // ── Step 1: Payment Method ──────────────────────
                Step(
                  title: const Text("Payment Method"),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_checkingExisting)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_installmentNumber == 1) ...[
                        // Option to choose between Full and Installment
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.indigo.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Payment Plan",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 12),
                              _planOption(
                                title: "Full Payment",
                                subtitle:
                                    "Pay the total amount of ₹${widget.amount.toStringAsFixed(0)}",
                                icon: Icons.account_balance_wallet,
                                selected: !_isInstallmentMode,
                                onTap: () => setState(() {
                                  _isInstallmentMode = false;
                                  _amountCtrl.text =
                                      widget.amount.toStringAsFixed(0);
                                }),
                              ),
                              const SizedBox(height: 10),
                              _planOption(
                                title: "Pay in 2 Installments",
                                subtitle: "Split the payment into two parts.",
                                icon: Icons.splitscreen,
                                selected: _isInstallmentMode,
                                onTap: () => setState(() {
                                  _isInstallmentMode = true;
                                  _amountCtrl.text =
                                      (widget.amount / 2).toStringAsFixed(0);
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        // Installment 2 detected
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.orange),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Installment 2 of 2",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        "You already paid ₹${_paidInFirst.toStringAsFixed(0)} in the first installment.",
                                        style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      ],

                      // ── Wallet Section ──────────────────────────────
                      if (!_isWalletFetching && _walletBalance > 0) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.green.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.account_balance_wallet,
                                          color: Colors.green[700]),
                                      const SizedBox(width: 8),
                                      const Text("Wallet Balance",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Text("₹${_walletBalance.toStringAsFixed(0)}",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700])),
                                ],
                              ),
                              const SizedBox(height: 12),
                              CheckboxListTile(
                                value: _walletToUse > 0,
                                title: const Text("Apply Wallet Balance",
                                    style: TextStyle(fontSize: 14)),
                                subtitle: Text(
                                  _walletToUse > 0
                                      ? "₹${_walletToUse.toStringAsFixed(0)} applied"
                                      : "Use your credit for this payment",
                                  style: const TextStyle(fontSize: 12),
                                ),
                                activeColor: Colors.green,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      double currentTotal = double.tryParse(
                                              _amountCtrl.text) ??
                                          0.0;
                                      _walletToUse =
                                          _walletBalance > currentTotal
                                              ? currentTotal
                                              : _walletBalance;
                                      _amountCtrl.text = (currentTotal -
                                              _walletToUse)
                                          .toStringAsFixed(0);
                                    } else {
                                      double currentTotal = double.tryParse(
                                              _amountCtrl.text) ??
                                          0.0;
                                      _amountCtrl.text = (currentTotal +
                                              _walletToUse)
                                          .toStringAsFixed(0);
                                      _walletToUse = 0.0;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      const Text("Choose your preferred method",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      // Mode toggle
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            _modeTab("UPI / Online", Icons.phone_android,
                                PaymentMode.upi),
                            _modeTab("Demand Draft", Icons.account_balance,
                                PaymentMode.dd),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (_paymentMode == PaymentMode.dd) ...[
                        // DD instructions
                        _infoBanner(
                          color: Colors.blue,
                          icon: Icons.info_outline,
                          title: "Demand Draft Instructions",
                          body: "• Get a DD payable to \"APEC College of Engineering\" from any bank\n"
                              "• Take a clear photo of the DD in the next step\n"
                              "• Also submit the physical DD to the college accounts office",
                        ),
                      ] else ...[
                        // UPI payment details
                        if (_paymentDetails == null)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                              "No specific bank details found. Please verify with admin.",
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        if (_paymentDetails != null &&
                            _paymentDetails!['qrCodeUrl'] != null)
                          Center(
                            child: Column(children: [
                              Text("Scan to Pay",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo[900])),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.all(4),
                                child: Image.network(
                                  _paymentDetails!['qrCodeUrl'],
                                  height: 180,
                                  width: 180,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (ctx, child, progress) =>
                                      progress == null
                                          ? child
                                          : const SizedBox(
                                              height: 180,
                                              width: 180,
                                              child: Center(
                                                  child:
                                                      CircularProgressIndicator())),
                                  errorBuilder: (ctx, err, stack) =>
                                      const SizedBox(
                                          height: 180,
                                          width: 180,
                                          child: Center(
                                              child: Icon(Icons.broken_image,
                                                  size: 50,
                                                  color: Colors.grey))),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ]),
                          ),
                        Card(
                          elevation: 2,
                          color: Colors.indigo[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow("Pay To",
                                    _paymentDetails?['accountName'] ??
                                        "APEC College"),
                                if (_paymentDetails?['bankName'] != null)
                                  _buildDetailRow(
                                      "Bank", _paymentDetails!['bankName']),
                                if (_paymentDetails?['accountNumber'] != null)
                                  _buildDetailRow("Account No",
                                      _paymentDetails!['accountNumber']),
                                if (_paymentDetails?['ifsc'] != null)
                                  _buildDetailRow(
                                      "IFSC", _paymentDetails!['ifsc']),
                                Divider(color: Colors.indigo[100]),
                                _buildDetailRow("UPI ID",
                                    _paymentDetails?['upiId'] ??
                                        "collegefees@sbi"),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _launchUPI,
                            icon: const Icon(Icons.payment),
                            label: const Text("Open UPI App"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  isActive: _currentStep >= 0,
                ),

                // ── Step 2: Upload ──────────────────────────────
                Step(
                  title: Text(_paymentMode == PaymentMode.dd
                      ? "Upload DD Photo"
                      : "Upload Screenshot"),
                  content: Column(
                    children: [
                      if (kIsWeb)
                        _infoBanner(
                          color: Colors.orange,
                          icon: Icons.smartphone,
                          title: "Mobile Required",
                          body:
                              "Receipt scanning is not available on web. Please use the mobile app.",
                        ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          _imageFile != null
                              ? Image.file(File(_imageFile!.path), height: 160)
                              : Container(
                                  height: 100,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                      child: Text(
                                    _paymentMode == PaymentMode.dd
                                        ? "No DD Photo"
                                        : "No Screenshot",
                                    style: const TextStyle(color: Colors.grey),
                                  ))),
                          if (_isScanning)
                            Container(
                              height: 160,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Center(
                                  child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                      color: Colors.white),
                                  SizedBox(height: 8),
                                  Text("Scanning...",
                                      style: TextStyle(color: Colors.white)),
                                ],
                              )),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        icon: Icon(_paymentMode == PaymentMode.dd
                            ? Icons.document_scanner
                            : Icons.camera_alt),
                        label: Text(kIsWeb
                            ? "Upload Not Available on Web"
                            : _paymentMode == PaymentMode.dd
                                ? "Take / Select DD Photo"
                                : "Select Screenshot"),
                        onPressed: _pickAndScanImage,
                        style: kIsWeb
                            ? TextButton.styleFrom(
                                foregroundColor: Colors.grey)
                            : null,
                      ),
                      if (_ocrRan && !_isScanning)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "OCR complete — check & edit details in the next step",
                            style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 12,
                                fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                  isActive: _currentStep >= 1,
                ),

                // ── Step 3: Verify Details ──────────────────────
                Step(
                  title: const Text("Verify Details"),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_ocrRan)
                        _infoBanner(
                          color: Colors.green,
                          icon: Icons.auto_fix_high,
                          title: "OCR Pre-filled",
                          body:
                              "Details were extracted from your image. Please review and correct if needed.",
                        ),

                      const SizedBox(height: 8),

                      // ── UPI fields ────────────────────────────
                      if (_paymentMode == PaymentMode.upi) ...[
                        _labeledField(
                          label: "Transaction ID",
                          hint: "Enter UPI Transaction / Ref ID",
                          controller: _txnCtrl,
                          icon: Icons.receipt_long,
                          ocrValue: _ocrOriginalTxn,
                        ),
                        const SizedBox(height: 14),
                        _labeledField(
                          label: "Amount Paid (₹)",
                          hint: "Enter amount",
                          controller: _amountCtrl,
                          icon: Icons.currency_rupee,
                          keyboardType: TextInputType.number,
                          ocrValue: _ocrOriginalAmount,
                        ),
                        if (_isInstallmentMode) ...[
                          const SizedBox(height: 8),
                          _balanceInfo(),
                        ],
                        const SizedBox(height: 14),
                        _labeledField(
                          label: "Payment Date",
                          hint: "e.g. 23/02/2025",
                          controller: _dateCtrl,
                          icon: Icons.calendar_today,
                          ocrValue: _ocrOriginalDate,
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 14),
                        _labeledField(
                          label: "Register / Roll Number (from receipt)",
                          hint: "If shown on receipt",
                          controller: _regNoCtrl,
                          icon: Icons.badge,
                          ocrValue: _ocrOriginalRegNo,
                        ),
                      ],

                      // ── DD fields ─────────────────────────────
                      if (_paymentMode == PaymentMode.dd) ...[
                        _labeledField(
                          label: "DD Number",
                          hint: "Enter DD Number",
                          controller: _ddNumberCtrl,
                          icon: Icons.confirmation_number,
                          keyboardType: TextInputType.number,
                          ocrValue: _ocrOriginalTxn,
                        ),
                        const SizedBox(height: 14),
                        _labeledField(
                          label: "Bank Name",
                          hint: "e.g. State Bank of India, Chennai",
                          controller: _ddBankCtrl,
                          icon: Icons.account_balance,
                          ocrValue: null,
                        ),
                        const SizedBox(height: 14),
                        _labeledField(
                          label: "DD Date",
                          hint: "Select DD Date",
                          controller: _dateCtrl,
                          icon: Icons.calendar_today,
                          ocrValue: _ocrOriginalDate,
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 14),
                        _labeledField(
                          label: "Amount (₹)",
                          hint: "Enter DD Amount",
                          controller: _amountCtrl,
                          icon: Icons.currency_rupee,
                          keyboardType: TextInputType.number,
                          ocrValue: _ocrOriginalAmount,
                        ),
                        if (_isInstallmentMode) ...[
                          const SizedBox(height: 8),
                          _balanceInfo(),
                        ],
                        const SizedBox(height: 14),
                        _labeledField(
                          label: "Register / Roll Number (from receipt)",
                          hint: "If shown on receipt",
                          controller: _regNoCtrl,
                          icon: Icons.badge,
                          ocrValue: _ocrOriginalRegNo,
                        ),
                        const SizedBox(height: 12),
                        _infoBanner(
                          color: Colors.amber,
                          icon: Icons.warning_amber,
                          title: "Important",
                          body:
                              "Remember to also submit the physical DD to the college accounts office.",
                        ),
                      ],

                      if (_isUploading) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                  isActive: _currentStep >= 2,
                ),
              ],
            ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dateCtrl.text =
          "${picked.day.toString().padLeft(2, '0')}/"
          "${picked.month.toString().padLeft(2, '0')}/"
          "${picked.year}";
    }
  }

  Widget _modeTab(String label, IconData icon, PaymentMode mode) {
    final selected = _paymentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.indigo : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: selected ? Colors.white : Colors.grey[600], size: 18),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : Colors.grey[600],
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBanner({
    required MaterialColor color,
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color[50],
        border: Border.all(color: color[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color[700], size: 18),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color[800])),
          ]),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(fontSize: 12, height: 1.7)),
          ],
        ],
      ),
    );
  }

  /// A labeled text field that optionally shows a small "OCR: original value"
  /// hint below when the user has edited the field.
  Widget _labeledField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    String? ocrValue,
    TextInputType? keyboardType,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: onTap != null,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            prefixIcon: Icon(icon),
            // Show a small OCR chip if value was originally extracted
            suffixIcon: ocrValue != null
                ? Tooltip(
                    message: "OCR extracted: $ocrValue",
                    child: const Icon(Icons.document_scanner,
                        size: 18, color: Colors.green),
                  )
                : null,
          ),
        ),
        // Show the original OCR value as helper text when field is edited
        if (ocrValue != null && controller.text != ocrValue)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              "Original (OCR): $ocrValue",
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange[800],
                  fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: TextStyle(
                      color: Colors.indigo[700],
                      fontWeight: FontWeight.bold))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
          if (label == 'Account No' || label == 'UPI ID' || label == 'IFSC')
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Copied $value"),
                    duration: const Duration(seconds: 1)));
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.copy, size: 16, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _planOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? Colors.indigo : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: selected ? Colors.indigo : Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.indigo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: selected ? Colors.white : Colors.indigo[900],
                          fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: TextStyle(
                          color: selected ? Colors.white70 : Colors.grey[600],
                          fontSize: 12)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _balanceInfo() {
    double entered = double.tryParse(_amountCtrl.text) ?? 0.0;
    double total = widget.amount;
    double alreadyPaid = _installmentNumber == 2 ? _paidInFirst : 0.0;
    double remaining = total - alreadyPaid - entered;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: remaining < 0
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            remaining <= 0 ? "Full balance cleared" : "Remaining balance:",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          Text(
            "₹${remaining.toStringAsFixed(0)}",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: remaining < 0 ? Colors.red : Colors.green[800],
            ),
          ),
        ],
      ),
    );
  }
}
