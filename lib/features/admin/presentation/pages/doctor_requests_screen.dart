import 'package:digl/features/admin/models/admin_models.dart';
import 'package:digl/features/admin/presentation/pages/doctor_request_details_screen.dart';
import 'package:digl/features/admin/services/admin_service.dart';
import 'package:flutter/material.dart';

class DoctorRequestsScreen extends StatefulWidget {
  const DoctorRequestsScreen({super.key});

  @override
  State<DoctorRequestsScreen> createState() => _DoctorRequestsScreenState();
}

class _DoctorRequestsScreenState extends State<DoctorRequestsScreen> {
  String _selectedFilter = 'pending';
  late Future<List<DoctorRequest>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() {
    _requestsFuture = _selectedFilter == 'all'
        ? AdminService.getAllDoctorRequests()
        : AdminService.getAllDoctorRequests(status: _selectedFilter);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F7FF),
      child: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<List<DoctorRequest>>(
              future: _requestsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        const Text('حدث خطأ في تحميل البيانات'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => setState(_loadRequests),
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }

                final requests = snapshot.data ?? [];

                if (requests.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(_loadRequests);
                    await _requestsFuture;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) => _buildRequestCard(requests[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterButton('قيد الانتظار', 'pending', Icons.pending_actions_rounded),
            const SizedBox(width: 8),
            _buildFilterButton('موافق عليها', 'approved', Icons.verified_rounded),
            const SizedBox(width: 8),
            _buildFilterButton('مرفوضة', 'rejected', Icons.cancel_rounded),
            const SizedBox(width: 8),
            _buildFilterButton('الكل', 'all', Icons.list_alt_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF3A86FF)),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
          _loadRequests();
        });
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF3A86FF),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF294060),
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF3A86FF) : const Color(0xFFD8E3F5),
      ),
    );
  }

  Widget _buildRequestCard(DoctorRequest request) {
    final statusMeta = _statusMeta(request.status);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFFDFEFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (statusMeta.color).withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: (statusMeta.color).withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DoctorRequestDetailsScreen(request: request)),
          );

          if (mounted) {
            setState(_loadRequests);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: statusMeta.color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.medical_information_rounded, color: statusMeta.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(request.specialty, style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusMeta.color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusMeta.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.schedule_rounded, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatDate(request.createdAt),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF3A86FF)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDCE6F8)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_rounded, size: 74, color: Colors.grey[400]),
              const SizedBox(height: 14),
              Text(
                'لا توجد طلبات ${_getFilterLabel()}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'سيتم عرض الطلبات هنا فور وصولها.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatusMeta _statusMeta(String status) {
    switch (status) {
      case 'pending':
        return const _StatusMeta(label: 'قيد الانتظار', color: Color(0xFFFFA62B));
      case 'approved':
        return const _StatusMeta(label: 'موافق عليها', color: Color(0xFF2CB67D));
      case 'rejected':
        return const _StatusMeta(label: 'مرفوضة', color: Color(0xFFE63946));
      default:
        return const _StatusMeta(label: 'غير معروف', color: Colors.grey);
    }
  }

  String _getFilterLabel() {
    switch (_selectedFilter) {
      case 'pending':
        return 'قيد الانتظار';
      case 'approved':
        return 'الموافق عليها';
      case 'rejected':
        return 'المرفوضة';
      default:
        return '';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'قبل ${difference.inMinutes} دقيقة';
      }
      return 'قبل ${difference.inHours} ساعة';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'قبل ${difference.inDays} أيام';
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatusMeta {
  final String label;
  final Color color;

  const _StatusMeta({required this.label, required this.color});
}