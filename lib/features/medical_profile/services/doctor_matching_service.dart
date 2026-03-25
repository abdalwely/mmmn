import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digl/features/medical_profile/models/doctor_recommendation_model.dart';
import 'package:digl/features/medical_profile/services/advanced_diagnosis_service.dart';

/// 👨‍⚕️ خدمة اختيار الطبيب المناسب بناءً على احتياجات المريض
/// 
/// تقوم بـ:
/// 1. البحث عن الأطباء ذوي التخصصات المناسبة
/// 2. ترتيبهم بناءً على التقييمات والخبرة والتوفر
/// 3. تقديم توصيات مخصصة لكل حالة
class DoctorMatchingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🎯 الحصول على أفضل الأطباء المناسبين للحالة
  /// 
  /// تأخذ:
  /// - recommendedSpecialties: التخصصات الموصى بها من التحليل الطبي
  /// - symptoms: الأعراض التي يعاني منها المريض
  /// - returnCount: عدد الأطباء المراد إرجاعهم (افتراضياً 3)
  static Future<List<DoctorRecommendation>> findMatchingDoctors({
    required List<SpecialtyRecommendation> recommendedSpecialties,
    required List<String> symptoms,
    int returnCount = 3,
  }) async {
    try {
      print('🔍 جاري البحث عن الأطباء المناسبين...');

      if (recommendedSpecialties.isEmpty) {
        print('⚠️ لا توجد تخصصات موصى بها');
        return [];
      }

      final matchedDoctors = <DoctorRecommendation>[];

      // البحث عن الأطباء لكل تخصص موصى به
      for (final specialty in recommendedSpecialties) {
        final doctors = await _searchDoctorsBySpecialty(
          specialty.name,
          symptoms,
        );
        matchedDoctors.addAll(doctors);
      }

      // ترتيب الأطباء بناءً على درجة التطابق والتقييمات
      matchedDoctors.sort((a, b) {
        // أولاً: نسبة التطابق
        int comparison = b.matchPercentage.compareTo(a.matchPercentage);
        if (comparison != 0) return comparison;

        // ثانياً: التقييم الشامل
        return b.overallScore.compareTo(a.overallScore);
      });

      // إرجاع أفضل N طبيب
      final result = matchedDoctors.take(returnCount).toList();
      if (result.isNotEmpty) {
        print('✅ تم العثور على ${result.length} طبيب(ة) مناسب(ة)');
        return result;
      }

      final fallbackDoctors = await getAllVerifiedDoctors();
      fallbackDoctors.sort((a, b) => b.overallScore.compareTo(a.overallScore));
      final fallbackResult = fallbackDoctors.take(returnCount).toList();
      print('ℹ️ لا يوجد تطابق مباشر، تم إرجاع ${fallbackResult.length} طبيب(ة) موثّق(ة) كبديل');
      return fallbackResult;
    } catch (e) {
      print('❌ خطأ في البحث عن الأطباء: $e');
      rethrow;
    }
  }

  /// 🔎 البحث عن الأطباء حسب التخصص
  static Future<List<DoctorRecommendation>> _searchDoctorsBySpecialty(
    String specialty,
    List<String> symptoms,
  ) async {
    try {
      // البحث في Firestore عن الأطباء المتحققين والمتاحين
      final querySnapshot = await _firestore
          .collection('users')
          .where('accountType', isEqualTo: 'doctor')
          .where('isVerified', isEqualTo: true)
          .where('specialtyName', isEqualTo: specialty)
          .get();

      final doctors = <DoctorRecommendation>[];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();

        // حساب نسبة التطابق بناءً على الأعراض والتخصص
        final matchPercentage = _calculateMatchPercentage(
          specialty,
          symptoms,
          data['specialtyName'] ?? '',
        );

        // الأسباب التي أدت للتوصية
        final reasons = _generateRecommendationReasons(
          specialty,
          matchPercentage,
          data['isOnline'] ?? false,
          data['isAvailable'] ?? false,
        );

        doctors.add(
          DoctorRecommendation.fromFirestore(
            doc,
            matchPercentage: matchPercentage,
            reasons: reasons,
          ),
        );
      }

      return doctors;
    } catch (e) {
      print('⚠️ خطأ في البحث عن الأطباء حسب التخصص: $e');
      return [];
    }
  }

  /// 📊 حساب نسبة التطابق بين احتياجات المريض والطبيب
  static int _calculateMatchPercentage(
    String requiredSpecialty,
    List<String> symptoms,
    String doctorSpecialty,
  ) {
    int matchScore = 0;
    const int maxScore = 100;

    // 1. التخصص الأساسي (50%)
    if (doctorSpecialty.toLowerCase() == requiredSpecialty.toLowerCase()) {
      matchScore += 50;
    } else if (doctorSpecialty.toLowerCase().contains(requiredSpecialty.toLowerCase())) {
      matchScore += 30;
    }

    // 2. التوفر (20%)
    matchScore += 20; // نفترض أن جميع الأطباء متاحون (يمكن تحسينها)

    // 3. التقييمات والخبرة (30%)
    matchScore += 30; // يتم الترتيب منفصل بناءً على التقييم والخبرة

    return matchScore.clamp(0, maxScore);
  }

  /// 💬 توليد أسباب التوصية بالطبيب
  static List<String> _generateRecommendationReasons(
    String specialty,
    int matchPercentage,
    bool isOnline,
    bool isAvailable,
  ) {
    final reasons = <String>[];

    // سبب التخصص
    reasons.add('متخصص في $specialty');

    // سبب التوفر
    if (isAvailable) {
      reasons.add('متاح الآن للاستشارة');
    }

    // سبب التواصل الفوري
    if (isOnline) {
      reasons.add('متصل الآن');
    }

    // سبب نسبة التطابق
    if (matchPercentage >= 80) {
      reasons.add('تطابق عالي جداً مع احتياجاتك');
    } else if (matchPercentage >= 60) {
      reasons.add('تطابق جيد مع احتياجاتك');
    }

    return reasons;
  }

  /// 🏥 الحصول على معلومات تفصيلية عن طبيب معين
  static Future<DoctorRecommendation?> getDoctorDetails(String doctorId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(doctorId)
          .get();

      if (!doc.exists || doc['accountType'] != 'doctor') {
        return null;
      }

      return DoctorRecommendation.fromFirestore(
        doc,
        matchPercentage: 100,
        reasons: ['الملف الشامل'],
      );
    } catch (e) {
      print('❌ خطأ في جلب تفاصيل الطبيب: $e');
      return null;
    }
  }

  /// 📋 الحصول على قائمة بجميع الأطباء المتحققين (اختياري)
  static Future<List<DoctorRecommendation>> getAllVerifiedDoctors() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('accountType', isEqualTo: 'doctor')
          .where('isVerified', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => DoctorRecommendation.fromFirestore(
            doc,
            matchPercentage: 50,
            reasons: ['طبيب متحقق'],
          ))
          .toList();
    } catch (e) {
      print('❌ خطأ في جلب الأطباء: $e');
      return [];
    }
  }

  /// 💾 حفظ التوصية في سجل المريض (اختياري)
  static Future<void> saveDoctorRecommendation(
    String patientId,
    List<DoctorRecommendation> recommendations,
  ) async {
    try {
      await _firestore
          .collection('patients')
          .doc(patientId)
          .collection('doctor_recommendations')
          .add({
        'recommendations': recommendations
            .map((d) => {
          'doctorId': d.doctorId,
          'fullName': d.fullName,
          'specialty': d.specialty,
          'specialtyName': d.specialtyName,
          'matchPercentage': d.matchPercentage,
          'reasonsForRecommendation': d.reasonsForRecommendation,
        })
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ تم حفظ التوصيات بنجاح');
    } catch (e) {
      print('❌ خطأ في حفظ التوصيات: $e');
    }
  }
}
