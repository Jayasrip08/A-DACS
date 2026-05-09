import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/fee_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';

class FeeSetupScreen extends StatefulWidget {
  final Widget? drawer;
  const FeeSetupScreen({super.key, this.drawer});

  @override
  State<FeeSetupScreen> createState() => _FeeSetupScreenState();
}

class _FeeSetupScreenState extends State<FeeSetupScreen> {
  // Config
  String _batch = '';
  String _dept = 'All';
  String _quota = 'All';
  String _semester = '1';
  DateTime? _deadline;
  DateTime? _examDeadline;

  // State
  bool _isLoading = false;
  List<String> _activeBatches = [];
  bool _loadingBatches = true;
  
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, TextEditingController> _busFeePlaces = {};
  final TextEditingController _examFeeCtrl = TextEditingController();
  
  final List<String> _commonFees = [
    'Tuition Fee', 'Hostel Fee', 'Library Fee', 'Association Fee', 'Training Fee', 'Book Fee'
  ];

  bool _isEditing = false;
  List<String> _activeSemesters = [];
  List<String> _activeDepts = ['All'];
  List<String> _activeQuotas = ['All'];
  bool _isLoadingMetaData = true;

  @override
  void initState() {
    super.initState();
    _loadActiveBatches();
    _loadDeptsAndQuotas();
    _resetControllers();
  }

  Future<void> _loadDeptsAndQuotas() async {
    try {
      final deptSnapshot = await FirebaseFirestore.instance.collection('departments').orderBy('name').get();
      final quotaSnapshot = await FirebaseFirestore.instance.collection('quotas').orderBy('name').get();

      if (mounted) {
        setState(() {
          _activeDepts = ['All', ...deptSnapshot.docs.map((d) => d['name'].toString())];
          _activeQuotas = ['All', ...quotaSnapshot.docs.map((d) => d['name'].toString())];
          _isLoadingMetaData = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMetaData = false);
    }
  }

  Future<void> _loadActiveSemesters() async {
    if (_batch.isEmpty) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('semesters')
          .where('academicYear', isEqualTo: _batch)
          .where('isActive', isEqualTo: true)
          .get();

      if (mounted) {
        setState(() {
          final semNumbers = <String>{};
          for (var d in snapshot.docs) semNumbers.add(d['semesterNumber'].toString());
          _activeSemesters = semNumbers.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
          if (_activeSemesters.isNotEmpty) {
             if (!_activeSemesters.contains(_semester)) _semester = _activeSemesters.first;
          } else {
             _semester = '';
          }
        });
        _loadExistingStructure();
      }
    } catch (e) {}
  }

  Future<void> _loadActiveBatches() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('academic_years').where('isActive', isEqualTo: true).get();
      if (mounted) {
        setState(() {
          _activeBatches = snapshot.docs.map((doc) => doc['name'] as String).toList();
          if (_activeBatches.isNotEmpty) {
            _batch = _activeBatches.first;
            _loadActiveSemesters();
          }
          _loadingBatches = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingBatches = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Synchronization Error: $e'), backgroundColor: AppColors.red));
      }
    }
  }

  Future<void> _loadExistingStructure() async {
    if (_batch.isEmpty) return;
    if (mounted) setState(() => _isLoading = true);
    
    String sanitizedDept = _dept.replaceAll(" ", "_");
    String sanitizedQuota = _quota.replaceAll(" ", "_");
    String docId = "${_batch}_${sanitizedDept}_${sanitizedQuota}_$_semester";
    
    try {
      final doc = await FirebaseFirestore.instance.collection('fee_structures').doc(docId).get();
      if (doc.exists && (doc.data()?['isActive'] ?? false)) {
        final data = doc.data()!;
        final components = data['components'] as Map<String, dynamic>? ?? {};
        final deadline = data['deadline'] as Timestamp?;
        final examFee = data['examFee'] as num?;
        final examDeadline = data['examDeadline'] as Timestamp?;

        if (mounted) {
          setState(() {
            _isEditing = true;
            _controllers.clear();
            _busFeePlaces.clear();
            _deadline = deadline?.toDate();
            _examDeadline = examDeadline?.toDate();
            _examFeeCtrl.text = examFee?.toString() ?? '';

            components.forEach((key, value) {
              if (key == 'Bus Fee' && value is Map) {
                value.forEach((place, amt) {
                  _busFeePlaces[place] = TextEditingController(text: amt.toString());
                });
              } else if (value is num) {
                _controllers[key] = TextEditingController(text: value.toString());
              }
            });
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isEditing = false;
            _resetControllers();
            _deadline = null;
            _examDeadline = null;
            _examFeeCtrl.clear();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetControllers() {
    _controllers.clear();
    _busFeePlaces.clear();
    _addFeeComponent("Tuition Fee");
    _addBusFeePlace("City Center");
  }

  void _addBusFeePlace(String placeName) {
    if (!_busFeePlaces.containsKey(placeName)) {
      setState(() => _busFeePlaces[placeName] = TextEditingController());
    }
  }

  void _removeBusFeePlace(String placeName) => setState(() => _busFeePlaces.remove(placeName));

  void _addFeeComponent(String name) {
    if (!_controllers.containsKey(name)) {
      setState(() => _controllers[name] = TextEditingController());
    }
  }

  void _removeComponent(String name) => setState(() => _controllers.remove(name));

  void _saveFeeStructure() async {
    if (mounted) setState(() => _isLoading = true);
    Map<String, dynamic> components = {};
    _controllers.forEach((key, ctrl) {
      if (ctrl.text.isNotEmpty) components[key] = double.tryParse(ctrl.text.replaceAll(',', '')) ?? 0.0;
    });

    if (_busFeePlaces.isNotEmpty) {
      Map<String, double> busFeeMap = {};
      _busFeePlaces.forEach((place, ctrl) {
        if (ctrl.text.isNotEmpty) busFeeMap[place] = double.tryParse(ctrl.text.replaceAll(',', '')) ?? 0.0;
      });
      if (busFeeMap.isNotEmpty) components['Bus Fee'] = busFeeMap;
    }

    if (components.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action Required: Add at least one fee entity."), backgroundColor: AppColors.red));
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    double total = 0;
    components.forEach((key, value) {
      if (value is Map) {
        for (var amt in value.values) total += (amt as num).toDouble();
      } else {
        total += (value as num).toDouble();
      }
    });

    double examFee = double.tryParse(_examFeeCtrl.text.replaceAll(',', '')) ?? 0.0;
    total += examFee;

    try {
      await FeeService().setFeeComponents(
        academicYear: _batch,
        dept: _dept,
        quotaCategory: _quota,
        semester: _semester,
        components: components,
        totalAmount: total,
        deadline: _deadline,
        examFee: examFee,
        examDeadline: _examDeadline,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Institutional fee structure updated and synced."), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Configuration Failed: $e"), backgroundColor: AppColors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Fee Configuration", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: widget.drawer,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("STRUCTURE STATUS", style: GoogleFonts.outfit(color: AppColors.grey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Text(_isEditing ? "Overwriting Active" : "Initializing New", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: _isEditing ? AppColors.warning : AppColors.success)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: (_isEditing ? AppColors.warning : AppColors.success).withOpacity(0.08), shape: BoxShape.circle),
                  child: Icon(_isEditing ? Icons.edit_calendar_rounded : Icons.add_chart_rounded, color: _isEditing ? AppColors.warning : AppColors.success, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), boxShadow: AppColors.softShadow),
              child: Column(
                children: [
                  _buildDropdownRow(
                    "ACADEMIC YEAR", _activeBatches, _batch, _loadingBatches, (v) { setState(() => _batch = v!); _loadActiveSemesters(); },
                    "DEPARTMENT", _activeDepts, _dept, _isLoadingMetaData, (v) { setState(() => _dept = v!); _loadExistingStructure(); }
                  ),
                  const SizedBox(height: 20),
                  _buildDropdownRow(
                    "QUOTA CATEGORY", _activeQuotas, _quota, _isLoadingMetaData, (v) { setState(() => _quota = v!); _loadExistingStructure(); },
                    "SEMESTER", _activeSemesters, _semester, _activeSemesters.isEmpty, (v) { setState(() => _semester = v!); _loadExistingStructure(); }
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1, color: AppColors.slateLighter)),
                  _buildDatePickerTile(
                    Icons.calendar_today_rounded, 
                    "PAYMENT DEADLINE", 
                    _deadline == null ? "Select Date" : DateFormat('dd MMM yyyy').format(_deadline!),
                    () async {
                      final picked = await showDatePicker(context: context, initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (picked != null) setState(() => _deadline = picked);
                    }
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            Text("Breakdown Details", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate)),
            const SizedBox(height: 16),
            
            ..._controllers.keys.map((key) => _buildComponentCard(key, _controllers[key]!, () => _removeComponent(key))),
            
            const SizedBox(height: 16),
            _buildSectionHeader("Bus Route Configurator", Icons.directions_bus_filled_rounded, () async {
              final ctrl = TextEditingController();
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: Text("Add Route", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: "Route/Place Name", hintText: "e.g. City Hub")),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("ADD")),
                  ],
                ),
              );
              if (ok == true && ctrl.text.isNotEmpty) _addBusFeePlace(ctrl.text);
            }),
            const SizedBox(height: 12),
            if (_busFeePlaces.isEmpty) 
               Center(child: Text("No specific routes configured", style: TextStyle(color: AppColors.grey, fontSize: 13, fontStyle: FontStyle.italic)))
            else
               ..._busFeePlaces.keys.map((place) => _buildComponentCard(place, _busFeePlaces[place]!, () => _removeBusFeePlace(place), isRoute: true)),

            const SizedBox(height: 24),
            _buildSectionHeader("Examination Fee", Icons.assignment_turned_in_rounded, null),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), boxShadow: AppColors.softShadow),
              child: Column(
                children: [
                  TextField(
                    controller: _examFeeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Exam Fee Amount", prefixText: "₹ ", hintText: "0.00"),
                  ),
                  const SizedBox(height: 12),
                  _buildDatePickerTile(
                    Icons.event_available_rounded, 
                    "EXAM DEADLINE", 
                    _examDeadline == null ? "Not Set" : DateFormat('dd MMM yyyy').format(_examDeadline!),
                    () async {
                      final picked = await showDatePicker(context: context, initialDate: _examDeadline ?? DateTime.now().add(const Duration(days: 45)), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (picked != null) setState(() => _examDeadline = picked);
                    }
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            Center(
              child: PopupMenuButton<String>(
                onSelected: _addFeeComponent,
                itemBuilder: (ctx) => _commonFees.map((f) => PopupMenuItem(value: f, child: Text(f))).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(color: AppColors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_circle_outline_rounded, color: AppColors.red, size: 20),
                      const SizedBox(width: 8),
                      Text("ADD COMPONENT", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppColors.red, fontSize: 13, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveFeeStructure,
                style: ElevatedButton.styleFrom(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : Text("DEPLOY STRUCTURE", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownRow(String l1, List<String> i1, String v1, bool ld1, Function(String?) c1, String l2, List<String> i2, String v2, bool ld2, Function(String?) c2) {
    return Row(
      children: [
        Expanded(child: _buildFieldColumn(l1, i1, v1, ld1, c1)),
        const SizedBox(width: 16),
        Expanded(child: _buildFieldColumn(l2, i2, v2, ld2, c2)),
      ],
    );
  }

  Widget _buildFieldColumn(String label, List<String> items, String val, bool isLoading, Function(String?) onChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.grey, letterSpacing: 1)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: items.contains(val) ? val : (items.isNotEmpty ? items.first : null),
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.slateLighter)),
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
          onChanged: isLoading ? null : onChange,
        ),
      ],
    );
  }

  Widget _buildDatePickerTile(IconData icon, String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.red),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.grey, letterSpacing: 1)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded, color: AppColors.slateLighter),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, VoidCallback? onAdd) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.slate),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate)),
        const Spacer(),
        if (onAdd != null) IconButton(icon: const Icon(Icons.add_box_rounded, color: AppColors.red), onPressed: onAdd),
      ],
    );
  }

  Widget _buildComponentCard(String name, TextEditingController ctrl, VoidCallback onRemove, {bool isRoute = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.softShadow),
      child: Row(
        children: [
          Icon(isRoute ? Icons.location_on_rounded : Icons.account_balance_wallet_rounded, size: 20, color: AppColors.slateLighter),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate))),
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Amount", prefixText: "₹ ", isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.red, size: 22), onPressed: onRemove),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0, curve: Curves.easeOut);
  }
}