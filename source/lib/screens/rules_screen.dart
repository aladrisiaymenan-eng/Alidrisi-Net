import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/ui.dart';
import '../data/models/app_models.dart';
import '../providers/app_state.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('الأتمتة',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('قواعد محفوظة تطبق عندما تتوافر شروطها.',
                        style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                  onPressed: () => _createRule(context, ref),
                  tooltip: 'إضافة قاعدة',
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: AppColors.primary, size: 28)),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            color: AppColors.teal,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: <Widget>[
                  Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.rule_rounded,
                          color: Colors.white, size: 24)),
                  const SizedBox(width: 13),
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                        Text('تحكم هادئ وواضح',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 5),
                        Text(
                            'سيظهر ما يحتاج صلاحية أو خدمة Android بدل تنفيذ صامت غير حقيقي.',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                height: 1.4))
                      ])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionTitle(
              title: 'القواعد المحفوظة',
              action: 'إضافة قاعدة',
              onAction: () => _createRule(context, ref)),
          const SizedBox(height: 10),
          for (final rule in state.rules)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RuleCard(
                    rule: rule,
                    onChanged: (_) =>
                        ref.read(appStateProvider).toggleRule(rule.id))),
          const SizedBox(height: 14),
          const SectionTitle(title: 'الملفات الشخصية'),
          const SizedBox(height: 10),
          for (final profile in state.profiles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProfileCard(
                profile: profile,
                onTap: () async {
                  await ref.read(appStateProvider).activateProfile(profile.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'تم تفعيل سياسة ${profile.name} على التطبيقات الحالية')));
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  void _createRule(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _CreateRuleSheet(
        onSave: (title, description) async {
          await ref
              .read(appStateProvider)
              .addCustomRule(title: title, description: description);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule, required this.onChanged});
  final SmartRule rule;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: <Widget>[
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: rule.color.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(rule.icon, color: rule.color)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                    Text(rule.title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(rule.description,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted, height: 1.35))
                  ])),
              Switch.adaptive(
                  value: rule.enabled,
                  activeTrackColor: AppColors.teal,
                  onChanged: onChanged),
            ],
          ),
        ),
      );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onTap});
  final AppProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            child: Row(
              children: <Widget>[
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: profile.color.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(profile.icon, color: profile.color)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(children: <Widget>[
                        Flexible(
                            child: Text(profile.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800))),
                        if (profile.active)
                          const Padding(
                              padding: EdgeInsets.only(right: 7),
                              child: Pill(
                                  label: 'نشط',
                                  color: AppColors.teal,
                                  icon: Icons.check_rounded))
                      ]),
                      const SizedBox(height: 4),
                      Text(profile.description,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                              height: 1.35)),
                    ],
                  ),
                ),
                if (profile.appCount > 0)
                  Text('${profile.appCount} تطبيق',
                      style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                const SizedBox(width: 5),
                const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
              ],
            ),
          ),
        ),
      );
}

class _CreateRuleSheet extends StatefulWidget {
  const _CreateRuleSheet({required this.onSave});
  final Future<void> Function(String title, String description) onSave;

  @override
  State<_CreateRuleSheet> createState() => _CreateRuleSheetState();
}

class _CreateRuleSheetState extends State<_CreateRuleSheet> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  String trigger = 'عند تجاوز تطبيق لحده';
  String action = 'أعرض تنبيهًا';

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('قاعدة جديدة',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                      labelText: 'اسم القاعدة',
                      hintText: 'مثال: تنبيه عند ارتفاع الاستهلاك')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: trigger,
                decoration: const InputDecoration(labelText: 'المشغل'),
                items: const [
                  'عند تجاوز تطبيق لحده',
                  'عند تحديث بيانات الاستخدام'
                ]
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => trigger = value ?? trigger),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: action,
                decoration: const InputDecoration(labelText: 'الإجراء'),
                items: const ['أعرض تنبيهًا', 'فعّل سياسة الحظر الحالية']
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => action = value ?? action),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'وصف اختياري')),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('اكتب اسم القاعدة أولًا')));
                      return;
                    }
                    final description =
                        descriptionController.text.trim().isEmpty
                            ? '$trigger — $action'
                            : descriptionController.text.trim();
                    await widget.onSave(title, description);
                  },
                  child: const Text('حفظ القاعدة'),
                ),
              ),
            ],
          ),
        ),
      );
}
