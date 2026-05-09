import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ux_widgets.dart';

class AcademicYearScreen extends StatefulWidget {
  final Widget? drawer;
  const AcademicYearScreen({super.key, this.drawer});

  @override
State<AcademicYearScreen> createState() => _AcademicYearScreenState();
}

class _AcademicYearScreenState extends State<AcademicYearScreen> {
  // Academic Year Creation
  Future<void> _createAcademicYear() async {
    final nameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text("Initialize Batch", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: "Batch Name",
            hintText: "e.g. 2024 - 2028",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: AppColors.slateLight))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("CREATE"),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('academic_years').doc(nameController.text).set({
          'name': nameController.text,
          'isActive': false,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': FirebaseAuth.instance.currentUser!.uid,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Institutional Batch Record Initialized."), backgroundColor: AppColors.success));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Initialization Failed: $e"), backgroundColor: AppColors.red));
        }
      }
    }
  }

  Future<void> _toggleAcademicYear(String docId, bool currentStatus) async {
    final newStatus = !currentStatus;
    try {
      await FirebaseFirestore.instance.collection('academic_years').doc(docId).update({'isActive': newStatus});
      final semSnapshot = await FirebaseFirestore.instance.collection('semesters').where('academicYear', isEqualTo: docId).get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in semSnapshot.docs) batch.update(doc.reference, {'isActive': newStatus});
      await batch.commit();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Status Synchronization Error: $e"), backgroundColor: AppColors.red));
    }
  }

  Future<void> _deleteAcademicYear(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text("Decommission Batch?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text("This action will permanently remove this batch and all associated semester configurations from the registry."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: AppColors.slateLight))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE PERMANENTLY"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final semesters = await FirebaseFirestore.instance.collection('semesters').where('academicYear', isEqualTo: docId).get();
        for (var doc in semesters.docs) await doc.reference.delete();
        await FirebaseFirestore.instance.collection('academic_years').doc(docId).delete();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Batch decommissioned with all sub-entities."), backgroundColor: AppColors.slate));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Operation Failed: $e"), backgroundColor: AppColors.red));
      }
    }
  }

  Future<void> _createSemester({String? preSelectedBatchId}) async {
    String? selectedBatchId = preSelectedBatchId;
    int? selectedSemesterNumber;
    DateTime? startDate;
    DateTime? endDate;

    final activeBatchesSnapshot = await FirebaseFirestore.instance.collection('academic_years').where('isActive', isEqualTo: true).get();
    final activeBatches = activeBatchesSnapshot.docs.map((doc) => {'id': doc.id, 'name': doc['name'] as String}).toList();

    if (activeBatches.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Activation Required: No active batches in registry."), backgroundColor: AppColors.warning));
      return;
    }

    if (selectedBatchId != null && !activeBatches.any((b) => b['id'] == selectedBatchId)) selectedBatchId = null;
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text("Configure Semester", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedBatchId,
                  decoration: const InputDecoration(labelText: "Registry Batch", border: OutlineInputBorder()),
                  items: activeBatches.map((b) => DropdownMenuItem(value: b['id'], child: Text(b['name']!))).toList(),
                  onChanged: (v) => setDialogState(() => selectedBatchId = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedSemesterNumber,
                  decoration: const InputDecoration(labelText: "Term Number", border: OutlineInputBorder()),
                  items: List.generate(8, (i) => i + 1).map((n) => DropdownMenuItem(value: n, child: Text("Semester $n"))).toList(),
                  onChanged: (v) => setDialogState(() => selectedSemesterNumber = v),
                ),
                const SizedBox(height: 16),
                _buildDialogDatePicker("START DATE", startDate, (p) => setDialogState(() => startDate = p)),
                const SizedBox(height: 12),
                _buildDialogDatePicker("END DATE", endDate, (p) => setDialogState(() => endDate = p)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: AppColors.slateLight))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white, elevation: 0),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("INITIALIZE"),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedBatchId != null && selectedSemesterNumber != null && startDate != null && endDate != null) {
      try {
        await FirebaseFirestore.instance.collection('semesters').add({
          'academicYear': selectedBatchId,
          'semesterNumber': selectedSemesterNumber,
          'startDate': Timestamp.fromDate(startDate!),
          'endDate': Timestamp.fromDate(endDate!),
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': FirebaseAuth.instance.currentUser!.uid,
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Institutional Semester Record Created."), backgroundColor: AppColors.success));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Synchronization Failed: $e"), backgroundColor: AppColors.red));
      }
    }
  }

  Future<void> _editSemester(String docId, Map<String, dynamic> currentData) async {
    int? selectedSemesterNumber = currentData['semesterNumber'];
    DateTime? startDate = (currentData['startDate'] as Timestamp?)?.toDate();
    DateTime? endDate = (currentData['endDate'] as Timestamp?)?.toDate();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text("Modify Semester", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedSemesterNumber,
                decoration: const InputDecoration(labelText: "Term Number", border: OutlineInputBorder()),
                items: List.generate(8, (i) => i + 1).map((n) => DropdownMenuItem(value: n, child: Text("Semester $n"))).toList(),
                onChanged: (v) => setDialogState(() => selectedSemesterNumber = v),
              ),
              const SizedBox(height: 16),
              _buildDialogDatePicker("START DATE", startDate, (p) => setDialogState(() => startDate = p)),
              const SizedBox(height: 12),
              _buildDialogDatePicker("END DATE", endDate, (p) => setDialogState(() => endDate = p)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: AppColors.slateLight))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white, elevation: 0),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("SAVE CHANGES"),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedSemesterNumber != null && startDate != null && endDate != null) {
      try {
        await FirebaseFirestore.instance.collection('semesters').doc(docId).update({
          'semesterNumber': selectedSemesterNumber,
          'startDate': Timestamp.fromDate(startDate!),
          'endDate': Timestamp.fromDate(endDate!),
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Semester credentials modernized."), backgroundColor: AppColors.success));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update Failed: $e"), backgroundColor: AppColors.red));
      }
    }
  }

  Future<void> _deleteSemester(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text("Remove Semester?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text("This module will be removed from the batch timeline. Verify data integrity before proceeding."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: AppColors.slateLight))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("CONFIRM REMOVAL"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('semesters').doc(docId).delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Semester removed from registry."), backgroundColor: AppColors.slate));
    }
  }

  Widget _buildDialogDatePicker(String label, DateTime? value, Function(DateTime) onPicked) {
    return InkWell(
      onTap: () async {
        final p = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (p != null) onPicked(p);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.grey)),
                Text(value != null ? DateFormat('dd/MM/yyyy').format(value) : "Select Date", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.red),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Academic Registry", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: widget.drawer,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('academic_years').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return FullScreenError(message: "Synchronization Error", onRetry: () => setState(() {}));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.red));

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(color: AppColors.red.withOpacity(0.05), shape: BoxShape.circle),
                    child: const Icon(Icons.history_edu_rounded, size: 64, color: AppColors.red),
                  ),
                  const SizedBox(height: 24),
                  Text("Registry Empty", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.slate)),
                  const SizedBox(height: 8),
                  Text("Initialize your first institutional batch to begin.", style: TextStyle(color: AppColors.grey)),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _createAcademicYear,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text("INITIALIZE REGISTRY"),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            itemCount: snapshot.data!.docs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24, top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("INSTITUTIONAL CYCLES", style: GoogleFonts.outfit(color: AppColors.grey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                          Text("Manage Batches", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate)),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.red, size: 28), onPressed: _createAcademicYear),
                          IconButton(icon: const Icon(Icons.library_add_rounded, color: AppColors.red, size: 28), onPressed: () => _createSemester()),
                        ],
                      ),
                    ],
                  ),
                );
              }

              final doc = snapshot.data!.docs[index - 1];
              final data = doc.data() as Map<String, dynamic>;
              final isActive = data['isActive'] ?? false;
              final academicYearId = doc.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), boxShadow: AppColors.softShadow, border: isActive ? Border.all(color: AppColors.red.withOpacity(0.1)) : null),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: (isActive ? AppColors.success : AppColors.slateLight).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                            child: Icon(isActive ? Icons.event_available_rounded : Icons.event_busy_rounded, color: isActive ? AppColors.success : AppColors.slateLight, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['name'], style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate)),
                                Text(isActive ? "CURRENTLY ACTIVE" : "INACTIVE SESSION", style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: isActive ? AppColors.success : AppColors.grey, letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                          Switch(value: isActive, activeColor: AppColors.red, onChanged: (v) => _toggleAcademicYear(academicYearId, isActive)),
                          IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 22), onPressed: () => _deleteAcademicYear(academicYearId)),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.slateLighter),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.slateLighter.withOpacity(0.2), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text("CONFIGURED SEMESTERS", style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slateLight, letterSpacing: 0.8)),
                              const Spacer(),
                              InkWell(onTap: () => _createSemester(preSelectedBatchId: academicYearId), child: const Text("+ ADD", style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('semesters').where('academicYear', isEqualTo: academicYearId).snapshots(),
                            builder: (context, semSnapshot) {
                              if (semSnapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator(color: AppColors.red);
                              if (!semSnapshot.hasData || semSnapshot.data!.docs.isEmpty) return Center(child: Text("No timelines configured for this batch.", style: TextStyle(color: AppColors.grey, fontSize: 12, fontStyle: FontStyle.italic)));

                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: semSnapshot.data!.docs.length,
                                itemBuilder: (context, i) {
                                  final semDoc = semSnapshot.data!.docs[i];
                                  final semData = semDoc.data() as Map<String, dynamic>;
                                  final semIsActive = semData['isActive'] ?? false;
                                  final startDate = (semData['startDate'] as Timestamp?)?.toDate();
                                  final endDate = (semData['endDate'] as Timestamp?)?.toDate();

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: semIsActive ? AppColors.red.withOpacity(0.05) : Colors.transparent)),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(color: AppColors.red.withOpacity(0.05), shape: BoxShape.circle),
                                          child: Center(child: Text("${semData['semesterNumber']}", style: GoogleFonts.outfit(color: AppColors.red, fontWeight: FontWeight.w900))),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("Term ${semData['semesterNumber']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate)),
                                              Text(startDate != null && endDate != null ? "${DateFormat('MMM yyyy').format(startDate)} - ${DateFormat('MMM yyyy').format(endDate)}" : "Dates Not Set", style: TextStyle(fontSize: 11, color: AppColors.grey)),
                                            ],
                                          ),
                                        ),
                                        IconButton(icon: const Icon(Icons.edit_note_rounded, color: AppColors.slateLight, size: 20), onPressed: () => _editSemester(semDoc.id, semData)),
                                        IconButton(icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.red, size: 20), onPressed: () => _deleteSemester(semDoc.id)),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}