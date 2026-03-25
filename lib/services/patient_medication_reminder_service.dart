import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'local_in_app_notification_service.dart';

class PatientMedicationReminderService {
  PatientMedicationReminderService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'medication_channel',
    'تنبيهات الأدوية',
    channelDescription: 'تنبيهات لتذكير المريض بتناول الدواء',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    category: AndroidNotificationCategory.alarm,
    fullScreenIntent: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );

  static const DarwinNotificationDetails _iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    await LocalInAppNotificationService.initialize();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamForCurrentUser() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('medications')
        .where('patientId', isEqualTo: currentUserId)
        .snapshots();
  }

  static Future<void> approveMedication({
    required String medicationId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance.collection('medications').doc(medicationId);

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final patientId = data['patientId'] as String?;
      if (patientId != uid) return;

      txn.update(ref, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': uid,
      });
    });

    await scheduleMedicationById(medicationId);

    await LocalInAppNotificationService.showAndStore(
      id: medicationId.hashCode & 0x7fffffff,
      title: 'تم تفعيل تذكيرات الدواء',
      body: 'تمت موافقتك على الدواء وسيعمل المنبه يومياً حسب الأوقات المحددة.',
      type: 'medication',
      channelId: 'medication_channel',
      payload: {'medicationId': medicationId, 'action': 'approved'},
      dedupeKey: 'approve-$medicationId',
    );
  }

  static Future<void> rejectMedication({
    required String medicationId,
  }) async {
    await FirebaseFirestore.instance.collection('medications').doc(medicationId).update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await cancelMedicationReminders(medicationId);

    await LocalInAppNotificationService.storeNotification(
      title: 'تم رفض طلب دواء',
      body: 'تم رفض الدواء ولن يتم تشغيل أي منبهات له.',
      type: 'medication',
      payload: {'medicationId': medicationId, 'action': 'rejected'},
      dedupeKey: 'reject-$medicationId',
      channelId: 'medication_channel',
    );
  }

  static Future<void> rescheduleApprovedForCurrentPatient() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final approved = await FirebaseFirestore.instance
        .collection('medications')
        .where('patientId', isEqualTo: uid)
        .where('status', isEqualTo: 'approved')
        .get();

    for (final doc in approved.docs) {
      await scheduleMedicationById(doc.id);
    }
  }

  static Future<void> scheduleMedicationById(String medicationId) async {
    final doc = await FirebaseFirestore.instance
        .collection('medications')
        .doc(medicationId)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;
    if (data['status'] != 'approved') return;

    final times = (data['times24'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    if (times.isEmpty) return;

    final medicationName = (data['name'] ?? 'دواء').toString();
    final instructions = (data['schedule'] ?? data['dose'] ?? '').toString();

    final oldIds = (data['scheduledNotificationIds'] as List<dynamic>? ?? [])
        .map((e) => e as int)
        .toList();
    for (final id in oldIds) {
      await _notifications.cancel(id);
    }

    final ids = <int>[];
    for (int index = 0; index < times.length; index++) {
      final parts = times[index].split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      final id = _buildReminderId(medicationId, index);
      ids.add(id);

      final now = tz.TZDateTime.now(tz.local);
      var next = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (next.isBefore(now)) {
        next = next.add(const Duration(days: 1));
      }

      await _notifications.zonedSchedule(
        id,
        '⏰ تذكير الدواء',
        'حان الآن موعد $medicationName\n$instructions',
        next,
        const NotificationDetails(android: _androidDetails, iOS: _iosDetails),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: medicationId,
      );
    }

    await doc.reference.update({
      'scheduledNotificationIds': ids,
      'lastScheduledAt': FieldValue.serverTimestamp(),
    });

    await LocalInAppNotificationService.storeNotification(
      title: 'تمت جدولة منبهات الدواء',
      body: 'تمت جدولة ${ids.length} منبه(ات) يومية لدواء $medicationName.',
      type: 'medication_schedule',
      payload: {'medicationId': medicationId, 'times24': times},
      dedupeKey: 'schedule-$medicationId-${times.join('-')}',
      channelId: 'medication_channel',
    );
  }

  static Future<void> cancelMedicationReminders(String medicationId) async {
    final doc = await FirebaseFirestore.instance
        .collection('medications')
        .doc(medicationId)
        .get();

    if (!doc.exists) return;

    final ids = (doc.data()?['scheduledNotificationIds'] as List<dynamic>? ?? [])
        .map((e) => e as int)
        .toList();

    for (final id in ids) {
      await _notifications.cancel(id);
    }

    await doc.reference.update({
      'scheduledNotificationIds': [],
      'lastScheduledAt': FieldValue.serverTimestamp(),
    });

    await LocalInAppNotificationService.storeNotification(
      title: 'تم إيقاف منبهات الدواء',
      body: 'تم إلغاء جميع منبهات الدواء المحدد.',
      type: 'medication_cancel',
      payload: {'medicationId': medicationId},
      dedupeKey: 'cancel-$medicationId',
      channelId: 'medication_channel',
    );
  }

  static int _buildReminderId(String medicationId, int index) {
    return ('$medicationId-$index').hashCode & 0x7fffffff;
  }

  static String formatTime24(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
