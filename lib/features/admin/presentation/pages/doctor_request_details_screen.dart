import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digl/features/admin/models/admin_models.dart';
import 'package:digl/features/admin/services/admin_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DoctorRequestDetailsScreen extends StatefulWidget {
  final DoctorRequest request;

  const DoctorRequestDetailsScreen({super.key, required this.request});

  @override
  State<DoctorRequestDetailsScreen> createState() => _DoctorRequestDetailsScreenState();
}

class _DoctorRequestDetailsScreenState extends State<DoctorRequestDetailsScreen> {
  late DoctorRequest _request;
  bool _isLoading = false;
  final _rejectionReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _request = widget.request;
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FF),
      appBar: AppBar(
        title: const Text('تفاصيل طلب الطبيب'),
        backgroundColor: const Color(0xFF3A86FF),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: 'البيانات الشخصية',
              icon: Icons.person_rounded,
              children: [
                _buildInfoRow('الاسم الكامل', _request.fullName),
                _buildInfoRow('البريد الإلكتروني', _request.email),
                _buildInfoRow('رقم الهاتف', _request.phoneNumber),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: 'البيانات المهنية',
              icon: Icons.badge_rounded,
              children: [
                _buildInfoRow('التخصص', _request.specialty),
                _buildInfoRow('سنوات الخبرة', _request.yearsOfExperience),
                _buildInfoRow('اسم العيادة', _request.clinicName),
                _buildInfoRow('عنوان العيادة', _request.clinicAddress),
                if (_request.bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('نبذة تعريفية', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(_request.bio, style: const TextStyle(height: 1.5)),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: 'الوثائق والإثباتات',
              icon: Icons.description_rounded,
              children: [
                if (_request.medicalLicense.isNotEmpty)
                  _buildDocumentItem('رخصة الممارسة الطبية', _request.medicalLicense),
                if (_request.medicalDegree.isNotEmpty)
                  _buildDocumentItem('شهادة التخرج', _request.medicalDegree),
                ..._request.documentUrls.asMap().entries.map(
                      (entry) => _buildDocumentItem('وثيقة إضافية ${entry.key + 1}', entry.value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_request.status == 'pending') _buildActionButtons(),
            if (_request.status != 'pending') _buildReviewInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final statusMeta = _statusMeta(_request.status);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusMeta.color, statusMeta.color.withOpacity(0.78)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: statusMeta.color.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusMeta.icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusMeta.label,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                if (_request.rejectionReason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'سبب الرفض: ${_request.rejectionReason}',
                      style: TextStyle(fontSize: 12.5, color: Colors.white.withOpacity(0.92)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF3A86FF), size: 20),
                ),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentItem(String title, String url) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBE6FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF3A86FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('تم الرفع وجاهز للمراجعة', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF3A86FF)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('سيتم فتح الملف قريباً...')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey)),
          ),
          Expanded(
            flex: 2,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _approveRequest,
          icon: const Icon(Icons.verified_rounded),
          label: const Text('الموافقة على الطلب'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2CB67D),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _showRejectDialog,
          icon: const Icon(Icons.close_rounded),
          label: const Text('رفض الطلب'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE63946),
            side: const BorderSide(color: Color(0xFFE63946)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewInfo() {
    return Card(
      color: const Color(0xFFEFF5FF),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('معلومات المراجعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildInfoRow('المراجع', _request.reviewedBy),
            _buildInfoRow(
              'تاريخ المراجعة',
              '${_request.reviewedAt.day}/${_request.reviewedAt.month}/${_request.reviewedAt.year}',
            ),
          ],
        ),
      ),
    );
  }

  _StatusMeta _statusMeta(String status) {
    switch (status) {
      case 'pending':
        return const _StatusMeta(label: 'قيد الانتظار - بانتظار المراجعة', color: Color(0xFFFFA62B), icon: Icons.hourglass_bottom_rounded);
      case 'approved':
        return const _StatusMeta(label: 'تمت الموافقة على الطلب', color: Color(0xFF2CB67D), icon: Icons.verified_rounded);
      case 'rejected':
        return const _StatusMeta(label: 'تم رفض الطلب', color: Color(0xFFE63946), icon: Icons.cancel_rounded);
      default:
        return const _StatusMeta(label: 'حالة غير معروفة', color: Colors.grey, icon: Icons.help_outline_rounded);
    }
  }

  Future<void> _approveRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الموافقة'),
        content: const Text('هل أنت متأكد من الموافقة على طلب هذا الطبيب؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لا')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('نعم')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final admin = FirebaseAuth.instance.currentUser;
      if (admin == null) throw Exception('لم يتم العثور على المسؤول');

      final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(admin.uid).get();

      final adminName = adminDoc.data()?['fullName'] ?? 'مسؤول';

      await AdminService.approveDoctorRequest(_request.id, admin.uid, adminName);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت الموافقة على الطلب بنجاح'), backgroundColor: Color(0xFF2CB67D)),
      );

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الرجاء إدخال سبب الرفض:'),
            const SizedBox(height: 12),
            TextField(
              controller: _rejectionReasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'اكتب سبب الرفض...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              if (_rejectionReasonController.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(context);
              _rejectRequest();
            },
            child: const Text('رفض'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectRequest() async {
    setState(() => _isLoading = true);

    try {
      final admin = FirebaseAuth.instance.currentUser;
      if (admin == null) throw Exception('لم يتم العثور على المسؤول');

      final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(admin.uid).get();

      final adminName = adminDoc.data()?['fullName'] ?? 'مسؤول';

      await AdminService.rejectDoctorRequest(
        _request.id,
        admin.uid,
        adminName,
        _rejectionReasonController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفض الطلب بنجاح'), backgroundColor: Color(0xFFE63946)),
      );

      _rejectionReasonController.clear();

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _StatusMeta {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusMeta({required this.label, required this.color, required this.icon});
}