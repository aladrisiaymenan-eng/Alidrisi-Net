import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/branding/app_brand.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/ui.dart';

class AboutDeveloperScreen extends StatelessWidget {
  const AboutDeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('عن المطور'),
          leading: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_forward_rounded))),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primary,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Image.asset(AppBrand.iconAsset, width: 58, height: 58),
                        const Spacer(),
                        const Icon(Icons.verified_outlined, color: Colors.white)
                      ]),
                      const SizedBox(height: 24),
                      const Text(AppBrand.shortName,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      const Text(AppBrand.tagline,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              height: 1.2,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      const Text(
                          'هوية ${AppBrand.name} وتجربة التحكم بالاتصال من تطوير ${AppBrand.developerName}.',
                          style: TextStyle(
                              color: Colors.white70,
                              height: 1.5,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle(title: 'صاحب الفكرة والتطوير'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(16)),
                          child: const Center(
                              child: Text('أ',
                                  style: TextStyle(
                                      fontSize: 27,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary)))),
                      const SizedBox(width: 14),
                      const Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(AppBrand.developerName,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16)),
                            SizedBox(height: 5),
                            Text(AppBrand.developerRole,
                                style: TextStyle(
                                    color: AppColors.muted, fontSize: 12))
                          ])),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle(title: 'التواصل'),
              const SizedBox(height: 10),
              _ContactTile(
                  icon: Icons.phone_rounded,
                  color: AppColors.teal,
                  title: 'الهاتف',
                  value: AppBrand.phone,
                  onTap: () =>
                      _copy(context, AppBrand.phone, 'تم نسخ رقم التواصل')),
              const SizedBox(height: 8),
              _ContactTile(
                  icon: Icons.email_rounded,
                  color: AppColors.primary,
                  title: 'البريد الإلكتروني',
                  value: AppBrand.email,
                  onTap: () => _copy(
                      context, AppBrand.email, 'تم نسخ البريد الإلكتروني')),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.warning, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                              'يمنحك التطبيق رؤية أوضح لاستهلاكك وتحكمًا أهدأ في اتصالك. القياسات والصلاحيات التي لا يسمح بها Android تظهر للمستخدم بدل إخفائها خلف بيانات تجريبية.',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: .72),
                                  height: 1.6,
                                  fontSize: 13))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Center(
                  child: Text('الإصدار 1.1.0 • هوية الأدريسي',
                      style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _copy(
      BuildContext context, String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile(
      {required this.icon,
      required this.color,
      required this.title,
      required this.value,
      required this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(11)),
                  child: Icon(icon, color: color, size: 21)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800))
                  ])),
              const Icon(Icons.copy_rounded, size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
