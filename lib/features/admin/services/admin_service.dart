import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:digl/features/admin/models/admin_models.dart';

/// خدمة إدارة النظام
class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// تسجيل دخول المسؤول
  static Future<AdminUser?> loginAdmin(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = userCredential.user;
      if (user == null) return null;

      final adminDoc =
      await _firestore.collection('admins').doc(user.uid).get();

      if (!adminDoc.exists) {
        await _auth.signOut();
        throw Exception('هذا الحساب ليس حساب مسؤول');
      }

      return AdminUser.fromFirestore(adminDoc);
    } catch (e) {
      print('Error logging in admin: $e');
      rethrow;
    }
  }

  /// تسجيل خروج المسؤول
  static Future<void> logoutAdmin() async {
    await _auth.signOut();
  }

  /// جلب جميع طلبات الأطباء المعلقة
  static Future<List<DoctorRequest>> getPendingDoctorRequests() async {
    try {
      final snapshot = await _firestore
          .collection('doctor_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      final requests = snapshot.docs
          .map((doc) => DoctorRequest.fromFirestore(doc))
          .toList();

      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    } catch (e) {
      print('Error fetching pending requests: $e');
      return [];
    }
  }

  /// جلب جميع طلبات الأطباء
  static Future<List<DoctorRequest>> getAllDoctorRequests(
      {String? status}) async {
    try {
      Query query = _firestore.collection('doctor_requests');

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();

      final requests = snapshot.docs
          .map((doc) => DoctorRequest.fromFirestore(doc))
          .toList();

      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    } catch (e) {
      print('Error fetching requests: $e');
      return [];
    }
  }

  /// جلب تفاصيل طلب معين
  static Future<DoctorRequest?> getDoctorRequest(String requestId) async {
    try {
      final doc = await _firestore
          .collection('doctor_requests')
          .doc(requestId)
          .get();

      if (!doc.exists) return null;
      return DoctorRequest.fromFirestore(doc);
    } catch (e) {
      print('Error fetching request: $e');
      return null;
    }
  }

  /// الموافقة على طلب الطبيب
  static Future<void> approveDoctorRequest(
      String requestId,
      String adminId,
      String adminName,
      ) async {
    try {
      final requestRef =
      _firestore.collection('doctor_requests').doc(requestId);

      final requestDoc = await requestRef.get();
      if (!requestDoc.exists) {
        throw Exception('الطلب غير موجود');
      }

      final request = DoctorRequest.fromFirestore(requestDoc);

      /// تحديث حالة الطلب (آمن)
      await requestRef.set({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminId,
      }, SetOptions(merge: true));

      /// تحديث حساب الطبيب (آمن حتى لو لم يكن موجود)
      await _firestore.collection('users').doc(request.doctorId).set({
        'isVerified': true,
        'hasLicenseDocuments': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': adminId,
      }, SetOptions(merge: true));

      /// تسجيل في السجل
      await _firestore.collection('admin_logs').add({
        'adminId': adminId,
        'adminName': adminName,
        'action': 'approve_doctor',
        'doctorId': request.doctorId,
        'doctorName': request.fullName,
        'requestId': requestId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error approving request: $e');
      rethrow;
    }
  }

  /// رفض طلب الطبيب
  static Future<void> rejectDoctorRequest(
      String requestId,
      String adminId,
      String adminName,
      String rejectionReason,
      ) async {
    try {
      final requestRef =
      _firestore.collection('doctor_requests').doc(requestId);

      final requestDoc = await requestRef.get();
      if (!requestDoc.exists) {
        throw Exception('الطلب غير موجود');
      }

      final request = DoctorRequest.fromFirestore(requestDoc);

      await requestRef.set({
        'status': 'rejected',
        'rejectionReason': rejectionReason,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminId,
      }, SetOptions(merge: true));

      await _firestore.collection('admin_logs').add({
        'adminId': adminId,
        'adminName': adminName,
        'action': 'reject_doctor',
        'doctorId': request.doctorId,
        'doctorName': request.fullName,
        'requestId': requestId,
        'rejectionReason': rejectionReason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error rejecting request: $e');
      rethrow;
    }
  }

  /// جلب إحصائيات الإدارة
  static Future<AdminStats> getAdminStats() async {
    try {
      final doctors = await _firestore
          .collection('users')
          .where('accountType', isEqualTo: 'doctor')
          .count()
          .get();

      final pending = await _firestore
          .collection('doctor_requests')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      final approved = await _firestore
          .collection('doctor_requests')
          .where('status', isEqualTo: 'approved')
          .count()
          .get();

      final rejected = await _firestore
          .collection('doctor_requests')
          .where('status', isEqualTo: 'rejected')
          .count()
          .get();

      final patients = await _firestore
          .collection('users')
          .where('accountType', isEqualTo: 'patient')
          .count()
          .get();

      final appointments =
      await _firestore.collection('appointments').count().get();

      return AdminStats(
        totalDoctors: doctors.count ?? 0,
        pendingRequests: pending.count ?? 0,
        approvedDoctors: approved.count ?? 0,
        rejectedRequests: rejected.count ?? 0,
        totalPatients: patients.count ?? 0,
        totalAppointments: appointments.count ?? 0,
        averageDoctorRating: 4.5,
        totalConsultations: 0,
      );
    } catch (e) {
      print('Error fetching stats: $e');
      return AdminStats(
        totalDoctors: 0,
        pendingRequests: 0,
        approvedDoctors: 0,
        rejectedRequests: 0,
        totalPatients: 0,
        totalAppointments: 0,
        averageDoctorRating: 0,
        totalConsultations: 0,
      );
    }
  }

  /// سجل الأنشطة
  static Future<List<Map<String, dynamic>>> getAdminLogs(
      {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('admin_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching logs: $e');
      return [];
    }
  }

  /// البحث عن الطلبات
  static Future<List<DoctorRequest>> searchDoctorRequests(String query) async {
    try {
      final snapshot = await _firestore
          .collection('doctor_requests')
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThan: '$query\uf8ff')
          .get();

      return snapshot.docs
          .map((doc) => DoctorRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error searching requests: $e');
      return [];
    }
  }

  /// تحديث ملف المسؤول
  static Future<void> updateAdminProfile(
      String adminId,
      Map<String, dynamic> data,
      ) async {
    try {
      await _firestore
          .collection('admins')
          .doc(adminId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      print('Error updating admin profile: $e');
      rethrow;
    }
  }
}
