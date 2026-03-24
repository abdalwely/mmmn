import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج بيانات المسؤول
class AdminUser {
  final String id;
  final String email;
  final String password; // يتم التعامل معها عبر Firebase Auth
  final String fullName;
  final String role; // super_admin, admin
  final String phoneNumber;
  final String profileImage;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> permissions;

  AdminUser({
    required this.id,
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
    required this.phoneNumber,
    required this.profileImage,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.permissions,
  });

  factory AdminUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminUser(
      id: doc.id,
      email: data['email'] ?? '',
      password: '', // لا نخزن كلمة المرور
      fullName: data['fullName'] ?? '',
      role: data['role'] ?? 'admin',
      phoneNumber: data['phoneNumber'] ?? '',
      profileImage: data['profileImage'] ?? '',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      permissions: List<String>.from(data['permissions'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
      'role': role,
      'phoneNumber': phoneNumber,
      'profileImage': profileImage,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'permissions': permissions,
    };
  }
}

/// نموذج طلب تسجيل الطبيب
class DoctorRequest {
  final String id;
  final String doctorId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String specialty;
  final String medicalLicense; // رابط الملف
  final String medicalDegree; // شهادة التخرج
  final String clinicName;
  final String clinicAddress;
  final List<String> documentUrls; // الوثائق الإضافية
  final String status; // pending, approved, rejected
  final String rejectionReason;
  final DateTime createdAt;
  final DateTime reviewedAt;
  final String reviewedBy;
  final double rating;
  final int reviewCount;
  final String bio;
  final List<String> specialties;
  final String yearsOfExperience;

  DoctorRequest({
    required this.id,
    required this.doctorId,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.specialty,
    required this.medicalLicense,
    required this.medicalDegree,
    required this.clinicName,
    required this.clinicAddress,
    required this.documentUrls,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
    required this.reviewedAt,
    required this.reviewedBy,
    required this.rating,
    required this.reviewCount,
    required this.bio,
    required this.specialties,
    required this.yearsOfExperience,
  });

  factory DoctorRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DoctorRequest(
      id: doc.id,
      doctorId: data['doctorId'] ?? '',
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      specialty: data['specialty'] ?? '',
      medicalLicense: data['medicalLicense'] ?? '',
      medicalDegree: data['medicalDegree'] ?? '',
      clinicName: data['clinicName'] ?? '',
      clinicAddress: data['clinicAddress'] ?? '',
      documentUrls: List<String>.from(data['documentUrls'] ?? []),
      status: data['status'] ?? 'pending',
      rejectionReason: data['rejectionReason'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      reviewedAt: data['reviewedAt'] != null
          ? (data['reviewedAt'] as Timestamp).toDate()
          : DateTime.now(),
      reviewedBy: data['reviewedBy'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      bio: data['bio'] ?? '',
      specialties: List<String>.from(data['specialties'] ?? []),
      yearsOfExperience: data['yearsOfExperience'] ?? '0',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'doctorId': doctorId,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'specialty': specialty,
      'medicalLicense': medicalLicense,
      'medicalDegree': medicalDegree,
      'clinicName': clinicName,
      'clinicAddress': clinicAddress,
      'documentUrls': documentUrls,
      'status': status,
      'rejectionReason': rejectionReason,
      'createdAt': FieldValue.serverTimestamp(),
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': reviewedBy,
      'rating': rating,
      'reviewCount': reviewCount,
      'bio': bio,
      'specialties': specialties,
      'yearsOfExperience': yearsOfExperience,
    };
  }

  DoctorRequest copyWith({
    String? id,
    String? doctorId,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? specialty,
    String? medicalLicense,
    String? medicalDegree,
    String? clinicName,
    String? clinicAddress,
    List<String>? documentUrls,
    String? status,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    double? rating,
    int? reviewCount,
    String? bio,
    List<String>? specialties,
    String? yearsOfExperience,
  }) {
    return DoctorRequest(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      specialty: specialty ?? this.specialty,
      medicalLicense: medicalLicense ?? this.medicalLicense,
      medicalDegree: medicalDegree ?? this.medicalDegree,
      clinicName: clinicName ?? this.clinicName,
      clinicAddress: clinicAddress ?? this.clinicAddress,
      documentUrls: documentUrls ?? this.documentUrls,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      bio: bio ?? this.bio,
      specialties: specialties ?? this.specialties,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
    );
  }
}

/// نموذج لإحصائيات الإدارة
class AdminStats {
  final int totalDoctors;
  final int pendingRequests;
  final int approvedDoctors;
  final int rejectedRequests;
  final int totalPatients;
  final int totalAppointments;
  final double averageDoctorRating;
  final int totalConsultations;

  AdminStats({
    required this.totalDoctors,
    required this.pendingRequests,
    required this.approvedDoctors,
    required this.rejectedRequests,
    required this.totalPatients,
    required this.totalAppointments,
    required this.averageDoctorRating,
    required this.totalConsultations,
  });

  factory AdminStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminStats(
      totalDoctors: data['totalDoctors'] ?? 0,
      pendingRequests: data['pendingRequests'] ?? 0,
      approvedDoctors: data['approvedDoctors'] ?? 0,
      rejectedRequests: data['rejectedRequests'] ?? 0,
      totalPatients: data['totalPatients'] ?? 0,
      totalAppointments: data['totalAppointments'] ?? 0,
      averageDoctorRating: (data['averageDoctorRating'] ?? 0).toDouble(),
      totalConsultations: data['totalConsultations'] ?? 0,
    );
  }
}
