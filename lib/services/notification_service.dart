import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // Import to access messengerKey and navigatorKey
import '../screens/notifications_screen.dart';

/// Top-level function for background message handling
/// This must be a top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message received: ${message.notification?.title}');
  // Handle background message here if needed
}

/// Notification Service for managing FCM notifications
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    try {
      // Request permission for iOS
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted notification permission');

        // Get FCM token
        String? token;
        if (kIsWeb) {
          // VAPID key is required for Web deep linking/push
          // Replace with your actual VAPID key from Firebase Console
          token = await _messaging.getToken(
            vapidKey: "BPEWU6G83xz5r5NZnJ1-XXcyr54bPj7RqknxvIox9JBaR1Dg9T-WsH5j-5QtzJO_vCYkNSMLuZkH3bgvyxnrIcM", // placeholder
          );
        } else {
          token = await _messaging.getToken();
        }

        if (token != null) {
          print('FCM Token: $token');
          await saveFCMToken(token);
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen(saveFCMToken);

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background messages
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // Handle notification tap when app is in background
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Check if app was opened from a notification
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }
      } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('User denied notification permission');
      } else {
        print('Notification permission status: ${settings.authorizationStatus}');
      }
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  /// Save FCM token to Firestore
  Future<void> saveFCMToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('FCM token saved to Firestore');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  /// Handle foreground messages (when app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    // Only handle messages sent by our own backend (have a 'type' field).
    // Firebase's automatic welcome/token-registration messages have empty
    // data payloads — skip those silently.
    final hasOurData = message.data.containsKey('type') ||
        message.data.containsKey('notificationId');
    if (!hasOurData) {
      debugPrint('Skipping system FCM message: ${message.notification?.title}');
      return;
    }

    if (message.notification != null) {
      String title = message.notification!.title ?? 'Notification';
      String body = message.notification!.body ?? 'You have a new message';
      showInAppNotification(title, body);
    }

    // Mark notification as received in Firestore
    _markNotificationAsReceived(message);
  }

  /// Handle notification tap (when user taps notification)
  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');

    // Navigate based on notification type
    final type = message.data['type'];
    
    if (type == 'new_payment' || type == 'payment_reminder' || type == 'payment_verified' || type == 'payment_rejected') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
    } else if (type == 'new_registration') {
      // In a real app, you might navigate to UserApprovalScreen
      // For now, NotificationsScreen is a safe bet to see all details
       navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
    } else {
       navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
    }
  }

  /// Mark notification as received
  Future<void> _markNotificationAsReceived(RemoteMessage message) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && message.data.containsKey('notificationId')) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(message.data['notificationId'])
            .update({'received': true, 'receivedAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      print('Error marking notification as received: $e');
    }
  }

  /// Show a global success message
  static void showSuccess(String message) {
    messengerKey.currentState?.hideCurrentSnackBar();
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(days: 365),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () => messengerKey.currentState?.hideCurrentSnackBar(),
        ),
      ),
    );
  }

  /// Show a global error message
  static void showError(String message) {
    messengerKey.currentState?.hideCurrentSnackBar();
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(days: 365),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () => messengerKey.currentState?.hideCurrentSnackBar(),
        ),
      ),
    );
  }

  /// Show a global informational message
  static void showInfo(String message) {
    messengerKey.currentState?.hideCurrentSnackBar();
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show in-app notification (for foreground messages)
  /// Uses messengerKey to show notification globally
  static void showInAppNotification(
    String title,
    String body,
  ) {
    messengerKey.currentState?.hideCurrentSnackBar();
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(days: 365), // Persistent until dismissed
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.indigo[900],
        margin: const EdgeInsets.all(12),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.amber,
          onPressed: () => messengerKey.currentState?.hideCurrentSnackBar(),
        ),
        content: GestureDetector(
          onTap: () {
            messengerKey.currentState?.hideCurrentSnackBar();
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Text(
                       title,
                       style: const TextStyle(
                         fontWeight: FontWeight.bold,
                         fontSize: 16,
                       ),
                     ),
                   ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get unread notification count
  Future<int> getUnreadNotificationCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: user.uid)
            .where('read', isEqualTo: false)
            .count()
            .get();
        return snapshot.count ?? 0;
      }
    } catch (e) {
      print('Error getting unread count: $e');
    }
    return 0;
  }

  /// Get stream of unread notification count.
  /// Uses authStateChanges so the stream automatically reacts when the
  /// user logs in or out, without needing to be recreated.
  Stream<int> getUnreadCountStream() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(0);
      return FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    });
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true, 'readAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Delete FCM token on logout
  Future<void> deleteFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': FieldValue.delete()});
        await _messaging.deleteToken();
        // token deleted successfully
      }
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }
}
