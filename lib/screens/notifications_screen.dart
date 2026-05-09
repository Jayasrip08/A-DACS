import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../widgets/ux_widgets.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final String? _userId;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    NotificationService().clearAppBadge();
  }

  void _enterSelectionMode(String docId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(docId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String docId) {
    setState(() {
      if (_selectedIds.contains(docId)) {
        _selectedIds.remove(docId);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(docId);
      }
    });
  }

  void _selectAll(List<QueryDocumentSnapshot> docs) {
    setState(() => _selectedIds.addAll(docs.map((d) => d.id)));
  }

  void _deselectAll() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelected() async {
    final ids = List<String>.from(_selectedIds);
    _exitSelectionMode();
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.delete(FirebaseFirestore.instance.collection('notifications').doc(id));
    }
    await batch.commit();
    NotificationService().updateAppBadge();
  }

  Future<void> _deleteOne(String docId) async {
    await FirebaseFirestore.instance.collection('notifications').doc(docId).delete();
    NotificationService().updateAppBadge();
  }

  Future<void> _markAllAsRead(String userId) async {
    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
    NotificationService().updateAppBadge();
  }

  Future<void> _deleteAllNotifications(String userId) async {
    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await FirebaseFirestore.instance.collection('notifications').where('userId', isEqualTo: userId).get();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    NotificationService().updateAppBadge();
  }

  Future<void> _confirmDeleteAll(BuildContext context, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text("Clear Inbox?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text("This will permanently remove all institutional notifications from your record."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: AppColors.slateLight, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE ALL", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
    if (confirmed == true) await _deleteAllNotifications(userId);
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return const Scaffold(body: Center(child: Text("Verification Required. Please Sign In.")));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('notifications').where('userId', isEqualTo: _userId).snapshots(),
      builder: (context, snapshot) {
        final rawDocs = snapshot.data?.docs ?? [];
        final docs = List<QueryDocumentSnapshot>.from(rawDocs)
          ..sort((a, b) {
            final aTs = (a.data() as Map)['timestamp'] as Timestamp?;
            final bTs = (b.data() as Map)['timestamp'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });
        final allSelected = docs.isNotEmpty && _selectedIds.length == docs.length;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _isSelectionMode
              ? _buildSelectionAppBar(docs, allSelected, context)
              : AppBar(
                  backgroundColor: AppColors.red,
                  elevation: 0,
                  foregroundColor: Colors.white,
                  title: const Text("Notice Board"),
                  centerTitle: true,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.done_all_rounded, color: Colors.white),
                      onPressed: () => _markAllAsRead(_userId!),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
                      onPressed: () => _confirmDeleteAll(context, _userId!),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
          body: () {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.red));
            if (snapshot.hasError) return FullScreenError(message: "Synchronization Failed", onRetry: () => setState(() {}));
            if (docs.isEmpty) return const EmptyStateWidget(icon: Icons.notifications_none_rounded, title: "Clean Record", subtitle: "No institutional alerts currently active.");

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: docs.length,
              itemBuilder: (context, index) => _buildNotificationTile(docs[index], index),
            );
          }().animate().fadeIn(duration: 400.ms),
        );
      },
    );
  }

  AppBar _buildSelectionAppBar(List<QueryDocumentSnapshot> docs, bool allSelected, BuildContext ctx) {
    return AppBar(
      leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _exitSelectionMode),
      title: Text("${_selectedIds.length} SELECTED", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
      backgroundColor: AppColors.red,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded), onPressed: allSelected ? _deselectAll : () => _selectAll(docs)),
        IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: _selectedIds.isEmpty ? null : () => _deleteSelected()),
      ],
    );
  }

  Widget _buildNotificationTile(QueryDocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>;
    final isRead = data['read'] ?? false;
    final isSelected = _selectedIds.contains(doc.id);
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final timeStr = timestamp != null ? DateFormat('MMM d • h:mm a').format(timestamp) : 'Pending...';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(doc.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 32),
        ),
        onDismissed: (direction) => _deleteOne(doc.id),
        child: InkWell(
          onLongPress: () { if (!_isSelectionMode) _enterSelectionMode(doc.id); },
          onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(doc.id);
          } else if (!isRead) {
            FirebaseFirestore.instance.collection('notifications').doc(doc.id).update({'read': true});
            NotificationService().updateAppBadge();
          }
        },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.red.withOpacity(0.04) : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isSelected ? AppColors.red : (isRead ? Colors.transparent : AppColors.red.withOpacity(0.08))),
            boxShadow: isSelected ? null : AppColors.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isRead ? AppColors.slateLighter.withOpacity(0.5) : AppColors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_getIconForType(data['type']), color: isRead ? AppColors.slateLight : AppColors.red, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(data['title'] ?? 'Registry Update', style: GoogleFonts.outfit(fontWeight: isRead ? FontWeight.w600 : FontWeight.w800, fontSize: 16, color: isRead ? AppColors.slate : AppColors.red)),
                          if (!isRead) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(data['body'] ?? '', style: TextStyle(fontSize: 14, color: isRead ? AppColors.slateLight : AppColors.slate, height: 1.4, fontWeight: isRead ? FontWeight.normal : FontWeight.w500)),
                      const SizedBox(height: 12),
                      Text(timeStr.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.grey, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOut);
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'payment_reminder': return Icons.priority_high_rounded;
      case 'payment_verified': return Icons.verified_rounded;
      case 'payment_rejected': return Icons.report_problem_rounded;
      case 'account_approved': return Icons.face_retouching_natural_rounded;
      case 'new_registration': return Icons.person_add_alt_1_rounded;
      case 'new_payment': return Icons.account_balance_wallet_rounded;
      default: return Icons.notifications_rounded;
    }
  }
}