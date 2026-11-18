# ملاحظات التحديث — الأدريسي نت

## التعديلات المنفذة

تم ربط وضع `backgroundBlocked` الموجود في الواجهة فعليًا مع Android عبر MethodChannel وIntent جديد باسم `backgroundBlockedPackages`. أصبحت الخدمة تحفظ قائمة مستقلة لحجب الخلفية، مع الحفاظ على قوائم الحجب اليدوي والحجب التلقائي دون دمجها في سياسة واحدة غير قابلة للتمييز.

تقرأ خدمة VPN آخر أحداث `UsageStatsManager` لتحديد الحزمة الظاهرة حاليًا. عندما يكون التطبيق صاحب سياسة حجب الخلفية في المقدمة، لا يُمرر عبر نفق الإسقاط؛ وعند انتقاله إلى الخلفية، يُضاف إلى قائمة التطبيقات المسموح لها بدخول نفق الإسقاط، فتُسقط حزم IPv4 وIPv6 الخاصة به. لا تستخدم الخدمة `addAllowedApplication` و`addDisallowedApplication` معًا، وتعيد بناء النفق فقط عندما تتغير المجموعة الفعالة.

تم تعديل دورة قراءة استهلاك اليوم في Flutter إلى كل ثانيتين، كما عُدلت قراءة الاستخدام اليومية داخل `InternetSpeedService` إلى كل ثانيتين. بقيت آليات منع التداخل (`_currentUsageRefreshing` و`usageRefreshing`) فعالة حتى لا تبدأ قراءة جديدة قبل انتهاء السابقة.

## الملفات المعدلة

- `lib/core/native/native_connector.dart`
- `lib/providers/app_state.dart`
- `android/app/src/main/kotlin/com/example/internet_manager_app/MainActivity.kt`
- `android/app/src/main/kotlin/com/example/internet_manager_app/InternetManagerVpnService.kt`
- `android/app/src/main/kotlin/com/example/internet_manager_app/InternetSpeedService.kt`

## التحقق

تم تشغيل اختبارات Flutter الموجودة في المشروع، والنتيجة: **All tests passed — 10 اختبارات ناجحة**.

تم بناء APK release بنجاح بعد تجهيز Flutter SDK وAndroid SDK وJDK. الناتج هو:

`build/app/outputs/flutter-apk/app-release.apk`

حجم APK: نحو 57.7 MB.

لم يتم إجراء اختبار شبكي على جهاز Android فعلي داخل هذه البيئة؛ لذلك يجب اختبار الانتقال بين التطبيق المستهدف وتطبيق آخر، وWi‑Fi وبيانات الجوال، ووجود VPN آخر، وإعادة تشغيل الهاتف قبل الاعتماد الإنتاجي. حجب الخلفية يعتمد على Usage Access وعلى جدولة Android، وبالتالي قد يوجد تأخير عملي قريب من دورة الفحص البالغة ثانيتين.
