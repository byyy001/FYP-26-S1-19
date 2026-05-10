import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
 
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
 
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
 
  bool _initialised = false;

  // initialise once app starts
  Future<void> init() async {
    if (_initialised) return;
 
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
 
    const initSettings = InitializationSettings(android: androidSettings);
 
    await _plugin.initialize(initSettings);
 
    // Request permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
 
    _initialised = true;
  }

  // core show method
  Future<void> _show({
    required int id,
    required String title,
    required String body,
    bool playSound = true,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'linksentry_channel',
      'LinkSentry Alerts',
      channelDescription: 'Security scan notifications from LinkSentry',
      importance: Importance.high,
      priority: Priority.high,
      playSound: playSound,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
 
    final details = NotificationDetails(android: androidDetails);
 
    await _plugin.show(id, title, body, details);
  }

 // main trigger, called from ResultScreen after scan
  Future<void> triggerScanNotification({
    required String url,
    required int score,
    required String verdict,
    required String threatType,
    required String mlConfidence,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // unregistered users: no notifications
 
    // load saved preferences
    final prefsDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('notification_preferences')
        .get();
 
    final prefs = prefsDoc.data();
    if (prefs == null) return;
 
    final bool allowNotifications = prefs['allowNotifications'] ?? false;
    if (!allowNotifications) return;
 
    final bool scanResultsAlert    = prefs['scanResultsAlert']    ?? false;
    final bool aiRiskLevel         = prefs['aiRiskLevel']         ?? false;
    final bool highRiskOnly        = prefs['highRiskOnly']        ?? false;
    final bool phishingTrendAlerts = prefs['phishingTrendAlerts'] ?? false;
    final bool sound               = prefs['sound']               ?? false;
 
    final String shortUrl = url.length > 40 ? '${url.substring(0, 40)}…' : url;

    // Rule 1: scan results alert
    if (scanResultsAlert) {
      // If highRiskOnly is also on, only fire for score >= 76
      final bool shouldFire = highRiskOnly ? score >= 76 : true;
      if (shouldFire) {
        await _show(
          id: 1001,
          title: 'Scan Complete — $verdict',
          body: '$shortUrl scored $score% risk.',
          playSound: sound,
        );
        return; // one notification per scan
      }
    }
 
    // Rule 2: AI risk level (ML flagged something)
    if (aiRiskLevel && mlConfidence != 'none' && mlConfidence.isNotEmpty) {
      if (!highRiskOnly || score >= 76) {
        await _show(
          id: 1002,
          title: 'AI Risk Detected',
          body: 'ML model flagged $shortUrl as $threatType.',
          playSound: sound,
        );
        return;
      }
    }
 
    // Rule 3: high risk only (standalone, without scanResultsAlert)
    if (highRiskOnly && score >= 76) {
      await _show(
        id: 1003,
        title: 'High Risk Link Detected',
        body: '$shortUrl was flagged as $verdict.',
        playSound: sound,
      );
      return;
    }
 
    // Rule 4: phishing trend alerts (new threat type for this user)
    if (phishingTrendAlerts && threatType != 'benign') {
      final isNew = await _isNewThreatType(user.uid, threatType);
      if (isNew) {
        await _show(
          id: 1004,
          title: 'New Threat Type Detected',
          body: 'You encountered a $threatType for the first time.',
          playSound: sound,
        );
      }
    }
  }

  Future<void> showRescanAlert({
    required int count,
    required String firstUrl,
    bool playSound = true,
  }) async {
    final body = count == 1
      ? '$firstUrl has been flagged as unsafe since your last scan.'
      : '$count previously safe URLs have been flagged as unsafe.';

    await _show(
      id: 2001,
      title: 'Previously Safe URL Now Unsafe',
      body: body,
      playSound: playSound,
    );
  }

  // check if this threat type has appeared in user's history before
  Future<bool> _isNewThreatType(String uid, String threatType) async {
    try {
      final scans = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('scans')
          .where('threat_type', isEqualTo: threatType)
          .limit(2) // if more than 1 exists, it's not new
          .get();
 
      // if only 1 means the current scan just saved, it's new to the user
      return scans.docs.length <= 1;
    } catch (_) {
      return false;
    }
  }
}
 