# دليل استخدام نظام الثيمات الطبي

## مقدمة
تم تطوير نظام ثيمات طبي احترافي يدعم الثيمين Light و Dark مع تصميم جذاب وجميل.

## الاستيراد

```dart
import '../../core/config/medical_theme.dart';
```

## الألوان الرئيسية

### الألوان الطبية الأساسية
```dart
MedicalTheme.primaryMedicalBlue      // أزرق طبي أساسي
MedicalTheme.primaryMedicalBlueDark  // أزرق داكن
MedicalTheme.primaryMedicalBlueLight // أزرق فاتح
MedicalTheme.secondaryMedicalGreen   // أخضر صحة
MedicalTheme.tertiaryMedicalCyan     // أزرق مائي
```

### ألوان الحالات
```dart
MedicalTheme.successGreen     // نجاح
MedicalTheme.warningOrange    // تحذير
MedicalTheme.dangerRed        // خطر
MedicalTheme.infoBlue         // معلومات
MedicalTheme.pendingYellow    // معلق
```

### ألوان خاصة طبية
```dart
MedicalTheme.doctorPurple     // لون الأطباء
MedicalTheme.patientPink      // لون المرضى
MedicalTheme.urgentCrimson    // حالات عاجلة
MedicalTheme.stableGreen      // حالة مستقرة
```

## أمثلة الاستخدام

### 1. الأزرار

#### Elevated Button
```dart
ElevatedButton(
  onPressed: () {},
  child: const Text('موافق'),
),
```

#### Text Button
```dart
TextButton(
  onPressed: () {},
  child: const Text('إلغاء'),
),
```

#### Outlined Button
```dart
OutlinedButton(
  onPressed: () {},
  child: const Text('تحرير'),
),
```

### 2. الرسائل والإشعارات

#### SnackBar للنجاح
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: const Text('تم بنجاح'),
    backgroundColor: MedicalTheme.successGreen,
  ),
);
```

#### SnackBar للخطأ
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: const Text('حدث خطأ'),
    backgroundColor: MedicalTheme.dangerRed,
  ),
);
```

#### SnackBar للتحذير
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: const Text('تحذير'),
    backgroundColor: MedicalTheme.warningOrange,
  ),
);
```

#### SnackBar للمعلومات
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: const Text('معلومة'),
    backgroundColor: MedicalTheme.infoBlue,
  ),
);
```

### 3. الأيقونات ملونة

```dart
// نجاح
Icon(Icons.check_circle, color: MedicalTheme.successGreen)

// خطر
Icon(Icons.error, color: MedicalTheme.dangerRed)

// تحذير
Icon(Icons.warning, color: MedicalTheme.warningOrange)

// معلومة
Icon(Icons.info, color: MedicalTheme.infoBlue)

// معلق
Icon(Icons.schedule, color: MedicalTheme.pendingYellow)
```

### 4. النصوص الملونة

```dart
// نص بلون النجاح
Text(
  'تمت العملية بنجاح',
  style: const TextStyle(color: MedicalTheme.successGreen),
)

// نص بلون الخطر
Text(
  'حدث خطأ',
  style: const TextStyle(color: MedicalTheme.dangerRed),
)
```

### 5. AppBar مخصصة

تم تكوينها تلقائياً في الثيمة، يمكنك ببساطة استخدام:
```dart
AppBar(
  title: const Text('عنوان'),
)
```

سيتم تطبيق الألوان تلقائياً بناءً على الثيم الحالي.

### 6. Cards

```dart
Card(
  child: ListTile(
    leading: const Icon(Icons.person),
    title: const Text('الاسم'),
    subtitle: const Text('الوصف'),
  ),
)
```

### 7. التعامل مع الثيمين (Light و Dark)

#### الطريقة الأولى: استخدام Helper Functions

```dart
final textColor = MedicalTheme.getTextColor(context);
final bgColor = MedicalTheme.getBackgroundColor(context);
final borderColor = MedicalTheme.getBorderColor(context);
```

#### الطريقة الثانية: التحقق من الثيم يدويا

```dart
final isDarkMode = Theme.of(context).brightness == Brightness.dark;

Container(
  color: isDarkMode ? MedicalTheme.darkGray800 : MedicalTheme.pure,
  child: Text(
    'محتوى',
    style: TextStyle(
      color: isDarkMode ? MedicalTheme.lightGray100 : MedicalTheme.darkGray900,
    ),
  ),
)
```

### 8. Input Fields

تم تكوينها تلقائياً في الثيمة:
```dart
TextField(
  decoration: InputDecoration(
    labelText: 'البريد الإلكتروني',
    prefixIcon: const Icon(Icons.email),
  ),
)
```

### 9. Chips

```dart
Chip(
  label: const Text('علامة'),
  backgroundColor: MedicalTheme.lightGray200,
  labelStyle: const TextStyle(color: MedicalTheme.darkGray900),
)
```

### 10. Lists و Status Indicators

```dart
ListTile(
  leading: const Icon(Icons.check_circle, color: MedicalTheme.successGreen),
  title: const Text('موعد مؤكد'),
  trailing: const Icon(Icons.arrow_forward_ios),
)
```

## ألوان الحالات الطبية

### حالات المواعيد
```dart
// معلق / جديد
color: MedicalTheme.pendingYellow

// مؤكد / تم الحضور
color: MedicalTheme.successGreen

// ملغى
color: MedicalTheme.dangerRed
```

### حالات الاستشارات
```dart
// استشارة جديدة / معلقة
color: MedicalTheme.pendingYellow

// استشارة نشطة
color: MedicalTheme.secondaryMedicalGreen

// حالة عاجلة
color: MedicalTheme.urgentCrimson
```

### حالات الأطباء والمرضى
```dart
// طبيب
Icon(Icons.medical_services, color: MedicalTheme.doctorPurple)

// مريض
Icon(Icons.person, color: MedicalTheme.patientPink)
```

## الاستخدام في الملفات الموجودة

### قبل
```dart
import '../../core/config/theme.dart';

const Color primaryBlue = Color(0xFF3A86FF);
const Color alertRed = Color(0xFFFF6B6B);

backgroundColor: Colors.white,
foregroundColor: Colors.blue,
backgroundColor: AppTheme.alertRed,
```

### بعد
```dart
import '../../core/config/medical_theme.dart';

backgroundColor: isDarkMode ? MedicalTheme.darkGray800 : MedicalTheme.pure,
foregroundColor: isDarkMode ? MedicalTheme.lightGray100 : MedicalTheme.primaryMedicalBlue,
backgroundColor: MedicalTheme.dangerRed,
color: MedicalTheme.primaryMedicalBlue,
```

## نصائح مهمة

1. **استخدم دائماً الثيمة**: لا تستخدم الألوان الثابتة مباشرة
2. **دعم الثيمين**: تحقق دائماً من الثيم الحالي عند استخدام الألوان المخصصة
3. **الاتساق**: استخدم نفس الألوان في جميع الملفات
4. **الوصولية**: تأكد من توفر تباين كافي بين الألوان
5. **الاختبار**: اختبر دائماً في الثيمين Light و Dark

## الملفات المحدثة

تم تحديث الملفات التالية:
- `lib/features/doctor/presentation/pages/doctor_dashboard_screen.dart`
- `lib/features/doctor/dashboard/bookings_screen.dart`
- `lib/features/doctor/dashboard/appointments_screen.dart`
- `lib/features/doctor/presentation/pages/doctor_appointments_screen.dart`
- `lib/features/consultations/presentation/pages/instant_consultation_screen.dart`
- `lib/features/consultations/presentation/pages/consultation_screen.dart`
- `lib/features/home/presentation/pages/home_screen.dart`

## للمزيد من المعلومات

راجع الملف `medical_theme.dart` للاطلاع على جميع الألوان والتكوينات المتاحة.
