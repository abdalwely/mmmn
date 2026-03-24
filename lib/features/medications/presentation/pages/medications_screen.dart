import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:digl/services/user_role_service.dart';
import 'package:digl/core/config/theme.dart';

import 'medication_form.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  String? userId;
  bool isLoading = true;
  // ✅ متغير للتحقق من أن المستخدم دكتور وله صلاحية إضافة أدوية
  bool canAddMedications = false;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initUser();
    _initializeNotifications();
  }

  Future<void> _initUser() async {
    final user = FirebaseAuth.instance.currentUser;

    // ✅ التحقق من صلاحية إضافة الأدوية
    final canAdd = await UserRoleService.canAddMedication();

    setState(() {
      userId = user?.uid;
      canAddMedications = canAdd;
      isLoading = false;
    });
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      'medication_channel',
      'تنبيهات الأدوية',
      description: 'تنبيهات لتذكير المريض بتناول الدواء',
      importance: Importance.high,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> scheduleDailyNotification({
    required int index,
    required String uniqueKey,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    final int id = (uniqueKey.hashCode + index) & 0x7FFFFFFF;

    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    ).isBefore(now)
        ? tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, time.hour, time.minute)
        : tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_channel',
          'تنبيهات الأدوية',
          channelDescription: 'تنبيهات لتذكير المريض بتناول دوائه',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> _deleteMedication(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content:
        const Text('هل أنت متأكد أنك تريد حذف هذا الدواء؟ لا يمكن التراجع بعد الحذف.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('medications').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الدواء')));
    }
  }

  String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'غير محدد';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      return DateFormat('dd/MM/yyyy hh:mm a').format(dt);
    }
    if (timestamp is String) return timestamp;
    return timestamp.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (userId == null) {
      return const Scaffold(body: Center(child: Text('الرجاء تسجيل الدخول.')));
    }
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        foregroundColor: Colors.blue,
        elevation: 2,
        title: const Text('إدارة الأدوية'),
        centerTitle: true,
        actions: [
          // ✅ زر الإخطارات متاح للجميع
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.blue),
            onPressed: () async {
              final snapshot = await FirebaseFirestore.instance
                  .collection('medications')
                  .where('userId', isEqualTo: userId)
                  .get();

              for (final doc in snapshot.docs) {
                final data = doc.data();
                final name = data['name'] ?? 'دواء';
                final schedule = data['schedule'] ?? '';
                final times = (data['times'] as List<dynamic>? ?? []).map((t) {
                  final date = DateFormat('hh:mm a').parse(t as String);
                  return TimeOfDay(hour: date.hour, minute: date.minute);
                }).toList();

                for (int i = 0; i < times.length; i++) {
                  await scheduleDailyNotification(
                    index: i,
                    uniqueKey: '${doc.id}-$i',
                    title: 'موعد تناول الدواء: $name',
                    body: 'الرجاء تناول $schedule',
                    time: times[i],
                  );
                }
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم جدولة جميع التنبيهات')),
              );
            },
          ),
          // ✅ زر الإضافة يظهر فقط للأطباء
          if (canAddMedications)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MedicationFormScreen(userId: userId!),
                  ),
                );
                if (updated == true) setState(() {});
              },
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('medications')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('حدث خطأ في تحميل البيانات'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ترتيب الأدوية محلياً
          var docs = snapshot.data!.docs;
          docs.sort((a, b) {
            final aCreatedAt = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bCreatedAt = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            return (bCreatedAt?.toDate() ?? DateTime(1970)).compareTo(aCreatedAt?.toDate() ?? DateTime(1970));
          });

          // ✅ إذا كانت قائمة الأدوية فارغة
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.medication_liquid,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text('لا توجد أدوية مضافة بعد.'),
                  const SizedBox(height: 8),
                  // ✅ رسالة مختلفة للمرضى والأطباء
                  if (!canAddMedications)
                    Text(
                      'فقط الأطباء يمكنهم إضافة الأدوية',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final times = (data['times'] as List<dynamic>? ?? []).cast<String>();

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: ExpansionTile(
                  title: Text(
                    data['name'] ?? '',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${data['dose']} • ${data['schedule']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _deleteMedication(doc.id),
                  ),
                  childrenPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('النوع: ${data['type'] ?? ''}'),
                        Text('المدة: ${data['duration'] ?? ''}'),
                        Text('ملاحظات: ${data['notes'] ?? ''}'),
                        const SizedBox(height: 8),
                        if (times.isNotEmpty)
                          const Text('الأوقات المحددة:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Wrap(
                          spacing: 8,
                          children: times.map((t) {
                            final date = DateFormat('hh:mm a').parse(t);
                            final timeOfDay = TimeOfDay(hour: date.hour, minute: date.minute);
                            return Chip(label: Text(timeOfDay.format(context)));
                          }).toList(),
                        ),
                      ],
                    ),
                    ButtonBar(
                      alignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () async {
                            final updated = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MedicationFormScreen(userId: userId!, doc: doc),
                              ),
                            );
                            if (updated == true) setState(() {});
                          },
                          child: const Text('تعديل'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
