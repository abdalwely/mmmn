import 'package:digl/features/profile/presentation/pages/supportScreen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:digl/features/settings/presentation/pages/settings_screen.dart';

import '../../../appointments/presentation/pages/appointments_list_screen.dart';
import '../../../medications/presentation/pages/medication_form.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? userId;
  bool isLoading = true;

  String fullName = '';
  String email = '';
  String phone = '';
  String gender = '';
  int? age;
  String workPlace = '';
  String? profileImageUrl;
  bool isDoctor = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    userId = user.uid;
    email = user.email ?? '';

    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) {
      setState(() => isLoading = false);
      return;
    }

    final data = doc.data()!;
    setState(() {
      fullName = data['fullName'] ?? '';
      phone = data['phone'] ?? '';
      gender = data['gender'] ?? '';
      age = int.tryParse(data['age']?.toString() ?? '');
      workPlace = data['workPlace'] ?? '';
      profileImageUrl = data['photoURL'];
      isDoctor = data['accountType'] == 'doctor';
      isLoading = false;
    });
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openSupport() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SupportScreen()),
    );
  }

  Future<void> _launchSupportEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@digl.com',
      queryParameters: {
        'subject': 'طلب دعم فني - $fullName',
        'body': 'السلام عليكم،\n\nأحتاج إلى مساعدة بخصوص...',
      },
    );

    if (await canLaunch(emailLaunchUri.toString())) {
      await launch(emailLaunchUri.toString());
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن فتح تطبيق البريد')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.35),
              colorScheme.surface,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 8),
                    Text('الملف الشخصي', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton.filled(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => EditProfileScreen(userId: userId!)),
                        ).then((_) => _loadUserProfile());
                      },
                      icon: const Icon(Icons.edit_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: colorScheme.primaryContainer,
                          backgroundImage: profileImageUrl?.isNotEmpty == true
                              ? NetworkImage(profileImageUrl!)
                              : null,
                          child: profileImageUrl?.isNotEmpty == true
                              ? null
                              : Icon(Icons.person_rounded, size: 42, color: colorScheme.primary),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          fullName,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(email, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _statChip(context, Icons.phone_rounded, phone.isNotEmpty ? phone : 'غير محدد'),
                            _statChip(context, Icons.person_outline_rounded, gender.isNotEmpty ? gender : 'غير محدد'),
                            _statChip(context, Icons.cake_outlined, age != null ? '$age سنة' : 'غير محدد'),
                            if (isDoctor) _statChip(context, Icons.work_outline_rounded, workPlace.isNotEmpty ? workPlace : 'غير محدد'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('الخدمات', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _modernOptionTile(
                  context,
                  icon: Icons.calendar_month_rounded,
                  title: 'سجل المواعيد',
                  subtitle: 'جميع المواعيد الحالية والسابقة',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AppointmentsListScreen()),
                  ),
                ),
                if (isDoctor && userId != null)
                  _modernOptionTile(
                    context,
                    icon: Icons.medication_rounded,
                    title: 'إضافة دواء للمريض',
                    subtitle: 'إنشاء وصفة دوائية جديدة وإرسالها للمريض',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MedicationFormScreen(userId: userId!),
                      ),
                    ),
                  ),
                _modernOptionTile(
                  context,
                  icon: Icons.support_agent_rounded,
                  title: 'الدعم الفني',
                  subtitle: 'تواصل مباشر أو عبر البريد الإلكتروني',
                  onTap: _openSupport,
                  trailing: IconButton(
                    onPressed: _launchSupportEmail,
                    icon: const Icon(Icons.email_outlined),
                  ),
                ),
                _modernOptionTile(
                  context,
                  icon: Icons.settings_rounded,
                  title: 'الإعدادات',
                  subtitle: 'الثيم، الإشعارات، والخيارات العامة',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  ),
                ),
                _modernOptionTile(
                  context,
                  icon: Icons.logout_rounded,
                  title: 'تسجيل الخروج',
                  subtitle: 'إنهاء الجلسة الحالية بأمان',
                  onTap: _logout,
                  danger: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statChip(BuildContext context, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.primaryContainer.withOpacity(0.45),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _modernOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = danger ? colorScheme.error : colorScheme.primary;
    final bgColor = danger
        ? colorScheme.errorContainer.withOpacity(0.4)
        : colorScheme.primaryContainer.withOpacity(0.35);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: trailing ?? Icon(Icons.arrow_forward_ios_rounded, size: 16, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
