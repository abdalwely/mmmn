import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:digl/services/user_role_service.dart';
import 'package:digl/services/patient_medication_reminder_service.dart';

import 'medication_form.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  String? userId;
  bool isLoading = true;
  bool canAddMedications = false;

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    final user = FirebaseAuth.instance.currentUser;
    final canAdd = await UserRoleService.canAddMedication();

    setState(() {
      userId = user?.uid;
      canAddMedications = canAdd;
      isLoading = false;
    });
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
      await PatientMedicationReminderService.cancelMedicationReminders(docId);
      await FirebaseFirestore.instance.collection('medications').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الدواء')));
    }
  }

  Future<void> _approveMedication(String medicationId) async {
    await PatientMedicationReminderService.approveMedication(medicationId: medicationId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تمت الموافقة وتمت جدولة المنبهات يوميًا')),
    );
  }

  Future<void> _rejectMedication(String medicationId) async {
    await PatientMedicationReminderService.rejectMedication(medicationId: medicationId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم رفض طلب الدواء')),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'approved':
        return 'موافق عليه';
      case 'rejected':
        return 'مرفوض';
      case 'pending':
      default:
        return 'بانتظار موافقة المريض';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
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

    Query medicationsQuery = FirebaseFirestore.instance.collection('medications');
    medicationsQuery = canAddMedications
        ? medicationsQuery.where('userId', isEqualTo: userId)
        : medicationsQuery.where('patientId', isEqualTo: userId);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        foregroundColor: Colors.blue,
        elevation: 2,
        title: Text(canAddMedications ? 'إدارة الأدوية (الطبيب)' : 'أدويتي'),
        centerTitle: true,
        actions: [
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
        stream: medicationsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('حدث خطأ في تحميل البيانات'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          docs.sort((a, b) {
            final aCreatedAt = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bCreatedAt = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            return (bCreatedAt?.toDate() ?? DateTime(1970))
                .compareTo(aCreatedAt?.toDate() ?? DateTime(1970));
          });

          if (docs.isEmpty) {
            return Center(
              child: Text(canAddMedications
                  ? 'لا توجد أدوية مضافة بعد.'
                  : 'لا توجد وصفات أدوية واردة من الطبيب حالياً.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final times = (data['times'] as List<dynamic>? ?? []).cast<String>();
              final status = (data['status'] ?? 'pending').toString();
              final createdAt = data['createdAt'] as Timestamp?;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: ExpansionTile(
                  title: Text(
                    data['name'] ?? '',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${data['dose'] ?? ''} • ${data['schedule'] ?? ''}'),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusText(status),
                          style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: canAddMedications
                      ? IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _deleteMedication(doc.id),
                        )
                      : null,
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('النوع: ${data['type'] ?? ''}'),
                        Text('المدة: ${data['duration'] ?? ''}'),
                        Text('ملاحظات: ${data['notes'] ?? ''}'),
                        if (createdAt != null)
                          Text('تم الإنشاء: ${DateFormat('yyyy/MM/dd hh:mm a').format(createdAt.toDate())}'),
                        const SizedBox(height: 8),
                        if (times.isNotEmpty)
                          const Text('الأوقات اليومية:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Wrap(
                          spacing: 8,
                          children: times.map((t) => Chip(label: Text(t))).toList(),
                        ),
                        const SizedBox(height: 8),
                        if (!canAddMedications && status == 'pending')
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _approveMedication(doc.id),
                                  icon: const Icon(Icons.check),
                                  label: const Text('موافقة'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _rejectMedication(doc.id),
                                  icon: const Icon(Icons.close),
                                  label: const Text('رفض'),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (canAddMedications)
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
