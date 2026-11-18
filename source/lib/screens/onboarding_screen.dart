import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/branding/app_brand.dart';
import '../core/theme/app_theme.dart';
import '../providers/app_state.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  late final AnimationController _introController;
  int _page = 0;

  final _pages = const [
    _OnboardingPage(
        image: 'assets/onboarding_network.png',
        eyebrow: 'مرحبًا بك مع الأدريسي نت',
        title: 'افهم اتصالك\nفي لحظته',
        description:
            'قراءات واضحة للسرعة والاستهلاك من الجهاز، مع احترام قيود Android وصلاحياته.',
        color: AppColors.cyan),
    _OnboardingPage(
        image: 'assets/onboarding_control.png',
        eyebrow: 'تحكم دقيق',
        title: 'كل تطبيق\nله سياسة',
        description:
            'راجع التطبيقات المثبتة، اختر التطبيقات المحظورة، واحفظ سياساتك محليًا.',
        color: AppColors.primary),
    _OnboardingPage(
        image: 'assets/onboarding_insights.png',
        eyebrow: 'قرارات أهدأ',
        title: 'حوّل الأرقام\nإلى راحة',
        description:
            'تابع السجل الحقيقي عندما تسمح الصلاحية، وشغّل عداد السرعة في الخلفية بإشعار واضح.',
        color: AppColors.warning),
  ];

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650))
      ..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _introController.dispose();
    super.dispose();
  }

  void _complete() => ref.read(appStateProvider).completeOnboarding();

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    final compact = MediaQuery.sizeOf(context).width < 380;
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(children: [
                    Image.asset(AppBrand.iconAsset, width: 40, height: 40),
                    const SizedBox(width: 10),
                    const Expanded(
                        child: Text(AppBrand.shortName,
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800))),
                    TextButton(onPressed: _complete, child: const Text('تخطي'))
                  ])),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (value) {
                    setState(() => _page = value);
                    _introController.forward(from: 0);
                  },
                  itemBuilder: (context, index) => AnimatedBuilder(
                    animation: _introController,
                    child: _OnboardingContent(
                        page: _pages[index],
                        compact: compact,
                        textColor: textColor),
                    builder: (context, child) {
                      final eased =
                          Curves.easeOutCubic.transform(_introController.value);
                      return Opacity(
                          opacity: .55 + eased * .45,
                          child: Transform.translate(
                              offset: Offset(0, 16 * (1 - eased)),
                              child: child));
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var index = 0; index < _pages.length; index++)
                        AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: index == _page ? 24 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                                color: index == _page
                                    ? page.color
                                    : Theme.of(context).dividerColor,
                                borderRadius: BorderRadius.circular(8)))
                    ]),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (_page == _pages.length - 1) {
                            _complete();
                          } else {
                            _pageController.nextPage(
                                duration: const Duration(milliseconds: 360),
                                curve: Curves.easeOutCubic);
                          }
                        },
                        icon: Icon(_page == _pages.length - 1
                            ? Icons.arrow_forward_rounded
                            : Icons.arrow_back_rounded),
                        label: Text(_page == _pages.length - 1
                            ? 'ابدأ الآن'
                            : 'التالي'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('بيانات محلية، وصلاحيات واضحة، وتحكم قابل للفهم',
                        style: TextStyle(color: AppColors.muted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingContent extends StatelessWidget {
  const _OnboardingContent(
      {required this.page, required this.compact, required this.textColor});
  final _OnboardingPage page;
  final bool compact;
  final Color textColor;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, compact ? 8 : 24, 24, 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: compact ? 6 : 18),
            Container(
              decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: page.color.withValues(alpha: .24))),
              padding: const EdgeInsets.all(6),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Opacity(
                      opacity: .92,
                      child: Image.asset(page.image,
                          height: compact ? 245 : 315,
                          width: double.infinity,
                          fit: BoxFit.cover))),
            ),
            SizedBox(height: compact ? 22 : 28),
            Text(page.eyebrow,
                style: TextStyle(
                    color: page.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(page.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 30,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                    color: textColor)),
            const SizedBox(height: 14),
            ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(page.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: textColor.withValues(alpha: .68),
                        fontSize: 14,
                        height: 1.55,
                        fontWeight: FontWeight.w500))),
          ],
        ),
      );
}

class _OnboardingPage {
  const _OnboardingPage(
      {required this.image,
      required this.eyebrow,
      required this.title,
      required this.description,
      required this.color});
  final String image;
  final String eyebrow;
  final String title;
  final String description;
  final Color color;
}
