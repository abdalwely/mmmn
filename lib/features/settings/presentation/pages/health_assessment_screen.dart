import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digl/core/config/medical_theme.dart';
import 'package:digl/core/config/theme_helper.dart';
import 'package:digl/features/medical_profile/presentation/pages/ai_symptom_questions_screen.dart';
import 'package:digl/features/medical_profile/models/health_profile_model.dart';
import 'package:digl/features/medical_profile/models/doctor_recommendation_model.dart';
import 'package:digl/features/medical_profile/services/advanced_diagnosis_service.dart';
import 'package:digl/features/medical_profile/services/doctor_matching_service.dart';
import 'package:digl/features/medical_profile/services/patient_symptoms_service.dart';

/// 🏥 صفحة تقييم الصحة - قسم متقدم في الإعدادات
/// 
/// تتضمن:
/// - أسئلة الذكاء الاصطناعي عن حالة المريض
/// - تحليل الأعراض وتشخيص أولي
/// - اختيار الطبيب المناسب للحالة
class HealthAssessmentScreen extends StatefulWidget {
  const HealthAssessmentScreen({Key? key}) : super(key: key);

  @override
  State<HealthAssessmentScreen> createState() => _HealthAssessmentScreenState();
}

class _HealthAssessmentScreenState extends State<HealthAssessmentScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // متغيرات الحالة
  bool _isLoading = false;
  bool _hasCompletedAssessment = false;
  late TabController _tabController;

  // بيانات التحليل والنتائج
  MedicalAnalysisResult? _lastAnalysisResult;
  List<DoctorRecommendation> _recommendedDoctors = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAssessmentData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// تحميل بيانات التقييم السابق
  Future<void> _loadAssessmentData() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // جلب آخر نتائج التحليل
      final analysisSnapshot = await _firestore
          .collection('patients')
          .doc(user.uid)
          .collection('medical_analysis')
          .orderBy('analysisDate', descending: true)
          .limit(1)
          .get();

      if (analysisSnapshot.docs.isNotEmpty) {
        final analysisData = analysisSnapshot.docs.first.data();

        // إعادة بناء النتائج من Firestore
        final medicines = (analysisData['recommendedMedicines'] as List<dynamic>?)
            ?.map((m) => MedicineRecommendation(
          name: m['name'] ?? '',
          activeIngredient: m['activeIngredient'] ?? '',
          dose: m['dose'] ?? '',
          category: m['category'] ?? '',
          sideEffects: (m['sideEffects'] as List<dynamic>?)?.cast<String>() ?? [],
          warnings: (m['warnings'] as List<dynamic>?)?.cast<String>() ?? [],
          matchPercentage: m['matchPercentage'] ?? 0,
        ))
            .toList() ??
            [];

        final specialties = (analysisData['recommendedSpecialties'] as List<dynamic>?)
            ?.map((s) => SpecialtyRecommendation(
          name: s['name'] ?? '',
          description: s['description'] ?? '',
          matchPercentage: s['matchPercentage'] ?? 0,
        ))
            .toList() ??
            [];

        _lastAnalysisResult = MedicalAnalysisResult(
          severity: analysisData['severity'] ?? 'low',
          matchedSymptoms: (analysisData['matchedSymptoms'] as List<dynamic>?)?.cast<String>() ?? [],
          recommendedMedicines: medicines,
          recommendedSpecialties: specialties,
          immediateActions: (analysisData['immediateActions'] as List<dynamic>?)?.cast<String>() ?? [],
          analysisDate: (analysisData['analysisDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          detailedAnalysis: analysisData['detailedAnalysis'] ?? '', recommendedDoctors: [],
        );

        _hasCompletedAssessment = true;

        // جلب الأطباء الموصى بهم
        if (_lastAnalysisResult != null) {
          _recommendedDoctors = await DoctorMatchingService.findMatchingDoctors(
            recommendedSpecialties: _lastAnalysisResult!.recommendedSpecialties,
            symptoms: _lastAnalysisResult!.matchedSymptoms,
          );
        }
      }
    } catch (e) {
      print('❌ خطأ في تحميل بيانات التقييم: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// بدء اختبار جديد
  Future<void> _startNewAssessment() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AiSymptomQuestionsScreen(),
      ),
    );

    if (result == true && mounted) {
      await _loadAssessmentData();
      ThemeHelper.showSuccessSnackBar(context, '✅ تم إكمال التقييم بنجاح');
      _tabController.animateTo(1); // الذهاب لتبويب النتائج
    }
  }

  /// تحليل الأعراض الجديدة
  Future<void> _analyzeSymptoms() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // جلب آخر الأعراض المسجلة
      final symptomsSnapshot = await _firestore
          .collection('patients')
          .doc(user.uid)
          .collection('patient_symptoms')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (symptomsSnapshot.docs.isEmpty) {
        if (mounted) {
          ThemeHelper.showErrorSnackBar(context, 'لا توجد بيانات أعراض محفوظة');
        }
        return;
      }

      final symptomsData = symptomsSnapshot.docs.first.data();

      // بناء نموذج HealthProfile من البيانات
      final users = _auth.currentUser!;
      final userData = await _firestore.collection('users').doc(users.uid).get();
      final data = userData.data() as Map<String, dynamic>;

      final healthProfile = HealthProfile(
        id: users.uid,
        patientId: users.uid,
        age: int.tryParse(data['age']?.toString() ?? '0') ?? 0,
        gender: data['gender'] ?? 'male',
        hasChronicDisease: data['hasChronicDisease'] ?? false,
        chronicDiseaseDetails: data['chronicDiseaseDetails'],
        symptoms: symptomsData['mainSymptom'] ?? '',
        symptomStartDate: symptomsData['symptomStartDate'] ?? '',
        painLevel: 5, // قيمة افتراضية
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // تحليل البيانات
      final analysisResult = await AdvancedDiagnosisService.analyzeHealthProfile(
        healthProfile,
      );

      // حفظ النتائج
      await AdvancedDiagnosisService.saveMedicalAnalysis(users.uid, analysisResult);

      // الحصول على الأطباء الموصى بهم
      final doctors = await DoctorMatchingService.findMatchingDoctors(
        recommendedSpecialties: analysisResult.recommendedSpecialties,
        symptoms: analysisResult.matchedSymptoms,
      );

      setState(() {
        _lastAnalysisResult = analysisResult;
        _recommendedDoctors = doctors;
        _hasCompletedAssessment = true;
      });

      if (mounted) {
        ThemeHelper.showSuccessSnackBar(context, '✅ تم التحليل بنجاح');
        _tabController.animateTo(1); // الذهاب لتبويب النتائج
      }
    } catch (e) {
      print('❌ خطأ في التحليل: $e');
      if (mounted) {
        ThemeHelper.showErrorSnackBar(context, 'حدث خطأ في التحليل');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقييم الصحة'),
        elevation: 0,
        backgroundColor: MedicalTheme.primaryMedicalBlue,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'البداية', icon: Icon(Icons.home)),
            Tab(text: 'النتائج', icon: Icon(Icons.assessment)),
            Tab(text: 'الأطباء', icon: Icon(Icons.person_4)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildStartTab(),
          _buildResultsTab(),
          _buildDoctorsTab(),
        ],
      ),
    );
  }

  /// تبويب البداية
  Widget _buildStartTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // بطاقة الترحيب
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '👋 أهلاً بك!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'نرحب بك في خدمة تقييم الصحة الذكية. هذه الخدمة تساعدك على:',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(
                    '🤖',
                    'أسئلة ذكية',
                    'أجب على أسئلة عن أعراضك وحالتك الصحية',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    '🔍',
                    'تحليل ذكي',
                    'نحصل على تقييم أولي لحالتك الصحية',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    '👨‍⚕️',
                    'اختيار الطبيب',
                    'نوصيك بأفضل طبيب متخصص لحالتك',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // الأزرار الرئيسية
          if (!_hasCompletedAssessment)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _startNewAssessment,
                icon: const Icon(Icons.quiz, size: 24),
                label: const Text(
                  'ابدأ التقييم الآن',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MedicalTheme.primaryMedicalBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _analyzeSymptoms,
                    icon: const Icon(Icons.refresh, size: 24),
                    label: const Text(
                      'تحليل جديد',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MedicalTheme.primaryMedicalBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _startNewAssessment,
                    icon: const Icon(Icons.quiz, size: 24),
                    label: const Text(
                      'إعادة الاختبار',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 32),

          // معلومات تحذيرية
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MedicalTheme.pendingYellow.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: MedicalTheme.pendingYellow,
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info,
                  color: MedicalTheme.pendingYellow,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ملاحظة: هذا التقييم استرشادي فقط ولا يغني عن استشارة الطبيب المتخصص',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// تبويب النتائج
  Widget _buildResultsTab() {
    if (!_hasCompletedAssessment || _lastAnalysisResult == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assessment,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد نتائج بعد',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'قم ببدء التقييم لرؤية النتائج',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // درجة الخطورة
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تقييم الحالة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 16),
                  _buildSeverityBadge(_lastAnalysisResult!.severity),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // التخصصات الموصى بها
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'التخصصات الموصى بها',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 16),
                  ..._lastAnalysisResult!.recommendedSpecialties.map((specialty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.star,
                            color: MedicalTheme.primaryMedicalBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  specialty.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  specialty.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // الإجراءات الفورية
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الإجراءات الموصى بها',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 16),
                  ..._lastAnalysisResult!.immediateActions.map((action) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              action,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// تبويب الأطباء
  Widget _buildDoctorsTab() {
    if (_recommendedDoctors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد توصيات بعد',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أكمل التقييم لرؤية الأطباء الموصى بهم',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._recommendedDoctors.asMap().entries.map((entry) {
          final index = entry.key;
          final doctor = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildDoctorCard(doctor, index + 1),
          );
        }).toList(),
        const SizedBox(height: 32),
      ],
    );
  }

  /// بطاقة الطبيب
  Widget _buildDoctorCard(DoctorRecommendation doctor, int rank) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الترتيب والاسم
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MedicalTheme.primaryMedicalBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        doctor.specialtyName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // التقييم والخبرة
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'التقييم',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${doctor.rating.toStringAsFixed(1)} / 5',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الاستشارات',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${doctor.consultationCount} استشارة',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'التطابق',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${doctor.matchPercentage}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: MedicalTheme.primaryMedicalBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // الحالة (متاح/متصل)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (doctor.isOnline)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.green, size: 8),
                        SizedBox(width: 4),
                        Text(
                          'متصل الآن',
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                if (doctor.isAvailable)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: MedicalTheme.primaryMedicalBlue.withOpacity(0.1),
                      border: Border.all(color: MedicalTheme.primaryMedicalBlue),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: MedicalTheme.primaryMedicalBlue, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'متاح للاستشارة',
                          style: TextStyle(
                            fontSize: 12,
                            color: MedicalTheme.primaryMedicalBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // أسباب التوصية
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'أسباب التوصية:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...doctor.reasonsForRecommendation.map((reason) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '• $reason',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // زر الاستشارة
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  ThemeHelper.showSuccessSnackBar(
                    context,
                    'سيتم تطوير ميزة الاستشارة المباشرة قريباً',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MedicalTheme.primaryMedicalBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('استشارة الآن'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بناء شارة درجة الخطورة
  Widget _buildSeverityBadge(String severity) {
    final (color, icon, label) = switch (severity) {
      'high' => (
      MedicalTheme.dangerRed,
      Icons.warning,
      'حالة خطيرة - يُنصح بزيارة فورية'
      ),
      'medium' => (
      MedicalTheme.pendingYellow,
      Icons.info,
      'حالة متوسطة - يُنصح بزيارة خلال أيام'
      ),
      _ => (
      Colors.green,
      Icons.check_circle,
      'حالة طبيعية - المراقبة والعناية المنزلية'
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء عنصر ميزة
  Widget _buildFeatureItem(String emoji, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
