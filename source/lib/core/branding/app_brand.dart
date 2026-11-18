import 'package:flutter/material.dart';

/// الهوية الرسمية لتطبيق Internet Manager.
/// تم وضع النصوص في ملف واحد حتى لا تتكرر أو تختلف بين الشاشات.
class AppBrand {
  static const name = 'الأدريسي نت';
  static const shortName = 'الأدريسي نت';
  static const tagline = 'إدارة أذكى. اتصال أكثر أمانًا.';
  static const developerName = 'أيمن شايف الإدريسي';
  static const developerRole = 'مطور تطبيقات وحلول رقمية';
  static const phone = '716031727';
  // تم تصحيح الامتداد الذي كُتب cim إلى com ليكون البريد قابلاً للاستخدام.
  static const email = 'aladriaiaymen@gmail.com';
  static const iconAsset = 'assets/alidrisi_app_icon.png';

  static const gradient = LinearGradient(
    colors: [Color(0xFF071A3A), Color(0xFF0B4FA2), Color(0xFF16C7E8)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const accentGradient = LinearGradient(
    colors: [Color(0xFF16C7E8), Color(0xFF3F78FF), Color(0xFFFFC857)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}
