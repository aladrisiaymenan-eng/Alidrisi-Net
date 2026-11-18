import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GradientCard extends StatelessWidget {
  const GradientCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18),
      this.colors,
      this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final List<Color>? colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = colors?.first ?? Theme.of(context).colorScheme.primary;
    final card = Container(
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      padding: padding,
      child: child,
    );
    return onTap == null
        ? card
        : Material(
            color: Colors.transparent,
            child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: card));
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: AppColors.primary.withValues(alpha: .08),
          highlightColor: AppColors.primary.withValues(alpha: .04),
          child: Padding(padding: padding, child: child),
        ),
      );
}

class AnimatedEntrance extends StatefulWidget {
  const AnimatedEntrance(
      {super.key,
      required this.child,
      this.delay = Duration.zero,
      this.offset = const Offset(0, .04)});
  final Widget child;
  final Duration delay;
  final Offset offset;
  @override
  State<AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final value = Curves.easeOutCubic.transform(_controller.value);
          return Opacity(
              opacity: value,
              child: Transform.translate(
                  offset: Offset(widget.offset.dx * (1 - value) * 60,
                      widget.offset.dy * (1 - value) * 60),
                  child: child));
        },
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
      {super.key, required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800))),
        if (action != null)
          TextButton(
              onPressed: onAction,
              child: Text(action!,
                  style: const TextStyle(fontWeight: FontWeight.w700)))
      ]);
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(9)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) Icon(icon, size: 13, color: color),
        if (icon != null) const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w800))
      ]));
}

class MetricTile extends StatelessWidget {
  const MetricTile(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 21)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))
        ]))
      ]));
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 52, color: AppColors.primary.withValues(alpha: .45)),
            const SizedBox(height: 14),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle,
                style: const TextStyle(color: AppColors.muted),
                textAlign: TextAlign.center)
          ])));
}
