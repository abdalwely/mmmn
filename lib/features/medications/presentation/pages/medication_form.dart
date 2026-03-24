import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:digl/services/advanced_medication_reminder_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MedicationFormScreen extends StatefulWidget {
  final String userId;
  final String? patientId; // المريض المرتبط بالدواء
  final String? consultationId; // الاستشارة المرتبطة
  final DocumentSnapshot? doc;

  const MedicationFormScreen({
    super.key,
    required this.userId,
    this.patientId,
    this.consultationId,
    this.doc,
  });

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController doseController;
  late TextEditingController scheduleController;
  late TextEditingController notesController;
  late TextEditingController durationController;
  late TextEditingController typeController;

  List<TimeOfDay> selectedTimes = [];
  String? selectedPatientId;
  String? selectedConsultationId;
  bool enableReminders = true;

  @override
  void initState() {
    super.initState();
    final data = widget.doc?.data() as Map<String, dynamic>?;

    nameController = TextEditingController(text: data?['name'] ?? '');
    doseController = TextEditingController(text: data?['dose'] ?? '');
    scheduleController = TextEditingController(text: data?['schedule'] ?? '');
    notesController = TextEditingController(text: data?['notes'] ?? '');
    durationController = TextEditingController(text: data?['duration'] ?? '');
    typeController = TextEditingController(text: data?['type'] ?? '');

    selectedTimes = data?['times'] != null
        ? List<String>.from(data!['times']).map((t) {
      final date = DateFormat('hh:mm a').parse(t);
      return TimeOfDay(hour: date.hour, minute: date.minute);
    }).toList()
        : [];

    // تحميل البيانات المرتبطة
    selectedPatientId = widget.patientId ?? (data?['patientId'] ?? '');
    selectedConsultationId = widget.consultationId ?? (data?['consultationId'] ?? '');
    enableReminders = data?['enableReminders'] as bool? ?? true;
  }

  String formatTimeOfDayTo12Hour(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        selectedTimes.add(time);
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    doseController.dispose();
    scheduleController.dispose();
    notesController.dispose();
    durationController.dispose();
    typeController.dispose();
    super.dispose();
  }

  Future<void> _saveMedication() async {
    if (!_formKey.currentState!.validate()) return;

    final medicationName = nameController.text.trim();
    final medicationTimes = selectedTimes.map((t) => formatTimeOfDayTo12Hour(t)).toList();

    final medicationData = {
      'name': medicationName,
      'dose': doseController.text.trim(),
      'schedule': scheduleController.text.trim(),
      'userId': widget.userId, // الطبيب الذي أضاف الدواء
      'patientId': selectedPatientId, // المريض المرتبط
      'consultationId': selectedConsultationId, // الاستشارة المرتبطة
      'createdAt': FieldValue.serverTimestamp(),
      'notes': notesController.text.trim(),
      'duration': durationController.text.trim(),
      'type': typeController.text.trim(),
      'times': medicationTimes,
      'enableReminders': enableReminders,
      'history': widget.doc?.get('history') ?? [],
    };

    try {
      String medicationId;

      if (widget.doc != null) {
        // تحديث الدواء
        await widget.doc!.reference.update(medicationData);
        medicationId = widget.doc!.id;
      } else {
        // إضافة دواء جديد
        final docRef = await FirebaseFirestore.instance
            .collection('medications')
            .add(medicationData);
        medicationId = docRef.id;
      }

      // ✅ تفعيل الإشعارات إذا كانت مفعلة
      if (enableReminders && medicationTimes.isNotEmpty && selectedPatientId != null) {
        await _scheduleReminderNotifications(
          medicationId: medicationId,
          medicationName: medicationName,
          patientId: selectedPatientId!,
          times: medicationTimes,
          durationDays: int.tryParse(durationController.text) ?? 30,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حفظ الدواء بنجاح'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في حفظ الدواء: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// جدولة إشعارات الأدوية
  Future<void> _scheduleReminderNotifications({
    required String medicationId,
    required String medicationName,
    required String patientId,
    required List<String> times,
    required int durationDays,
  }) async {
    try {
      await AdvancedMedicationReminderService.scheduleMedicationReminders(
        medicationId: medicationId,
        medicationName: medicationName,
        times: times,
        durationDays: durationDays,
      );

      debugPrint('✅ تم جدولة إشعارات الدواء بنجاح للمريض: $patientId');
    } catch (e) {
      debugPrint('⚠️ خطأ في جدولة الإشعارات: $e');
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.doc != null;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        foregroundColor: Colors.blue,
        elevation: 2,
        title: Text(isEditing ? 'تعديل الدواء' : 'إضافة دواء جديد'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // معلومات الدواء الأساسية
              _buildSectionHeader('معلومات الدواء'),
              _buildInputField(
                controller: nameController,
                label: 'اسم الدواء',
                icon: Icons.medical_services,
                validator: (v) => v == null || v.isEmpty ? 'يرجى إدخال اسم الدواء' : null,
              ),
              _buildInputField(
                controller: doseController,
                label: 'الجرعة',
                icon: Icons.local_pharmacy,
              ),
              _buildInputField(
                controller: scheduleController,
                label: 'جدول الجرعات',
                icon: Icons.schedule,
              ),
              _buildInputField(
                controller: durationController,
                label: 'مدة العلاج (أيام)',
                icon: Icons.timelapse,
              ),
              _buildInputField(
                controller: typeController,
                label: 'نوع الدواء',
                icon: Icons.category,
              ),
              _buildInputField(
                controller: notesController,
                label: 'ملاحظات الطبيب',
                icon: Icons.note_alt,
              ),

              const SizedBox(height: 24),

              // أوقات الجرعات
              _buildSectionHeader('أوقات تناول الدواء'),
              const Text('اختر أوقات تناول الدواء:'),
              Wrap(
                spacing: 8,
                children: selectedTimes.map((time) {
                  return Chip(
                    label: Text(time.format(context)),
                    onDeleted: () {
                      setState(() {
                        selectedTimes.remove(time);
                      });
                    },
                  );
                }).toList(),
              ),
              TextButton.icon(
                icon: const Icon(Icons.access_time),
                label: const Text('إضافة وقت'),
                onPressed: _selectTime,
              ),

              const SizedBox(height: 24),

              // ربط المريض والاستشارة
              _buildSectionHeader('ربط الدواء'),
              _buildPatientSelector(),
              const SizedBox(height: 16),
              _buildConsultationSelector(),

              const SizedBox(height: 24),

              // خيار الإشعارات
              _buildSectionHeader('الإشعارات'),
              CheckboxListTile(
                title: const Text('تفعيل إشعارات التذكير'),
                subtitle: const Text('تذكيرات يومية في أوقات الجرعات'),
                value: enableReminders,
                onChanged: (value) {
                  setState(() {
                    enableReminders = value ?? true;
                  });
                },
                controlAffinity: ListTileControlAffinity.trailing,
              ),

              const SizedBox(height: 32),

              // أزرار الحفظ والإلغاء
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: _saveMedication,
                    child: const Text('حفظ'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// رأس القسم
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2E5CB8),
        ),
      ),
    );
  }

  /// اختيار المريض
  Widget _buildPatientSelector() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .where('accountType', isEqualTo: 'patient')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final patients = snapshot.data?.docs ?? [];

        return DropdownButtonFormField<String>(
          value: selectedPatientId?.isNotEmpty == true ? selectedPatientId : null,
          hint: const Text('اختر المريض'),
          items: patients.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem(
              value: doc.id,
              child: Text(data['fullName'] ?? 'مريض بدون اسم'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedPatientId = value;
            });
          },
          decoration: InputDecoration(
            labelText: 'المريض',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }

  /// اختيار الاستشارة
  Widget _buildConsultationSelector() {
    if (selectedPatientId == null || selectedPatientId!.isEmpty) {
      return const Text(
        'اختر المريض أولاً لتتمكن من ربط الاستشارة',
        style: TextStyle(color: Colors.orange, fontSize: 12),
      );
    }

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('consultations')
          .where('patientId', isEqualTo: selectedPatientId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final consultations = snapshot.data?.docs ?? [];

        if (consultations.isEmpty) {
          return const Text(
            'لا توجد استشارات لهذا المريض',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          );
        }

        return DropdownButtonFormField<String>(
          value: selectedConsultationId?.isNotEmpty == true ? selectedConsultationId : null,
          hint: const Text('اختر الاستشارة (اختياري)'),
          items: consultations.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final doctorName = data['doctorName'] ?? 'طبيب';
            final date = data['createdAt']?.toDate().toString().split(' ')[0] ?? 'تاريخ';
            return DropdownMenuItem(
              value: doc.id,
              child: Text('$doctorName - $date'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedConsultationId = value;
            });
          },
          decoration: InputDecoration(
            labelText: 'الاستشارة (اختياري)',
            prefixIcon: const Icon(Icons.medical_information),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }
}
