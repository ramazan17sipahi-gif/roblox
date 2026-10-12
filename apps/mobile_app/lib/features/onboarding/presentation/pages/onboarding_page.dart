import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:networking/networking.dart';
import '../../../../app/app_providers.dart';
import '../../../../shared/widgets/flow_ui.dart';
import '../../../../l10n/generated/app_localizations.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _totalPages = 3;

  // Collection sets shown on the slides (names are collection titles).
  static const _template091 = 'assets/onboarding/onboarding_template_091.png';
  static const _template064 = 'assets/onboarding/onboarding_template_064.png';
  static const _dressed091 = 'assets/onboarding/onboarding_dressed_091.jpg';
  static const _name091 = 'Turuncu Sağanak';
  static const _name064 = 'Bauhaus Güneşi';

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    await ref.read(onboardingCompletedProvider.notifier).markCompleted();
    if (!mounted) return;
    final session = ref.read(supabaseClientProvider).auth.currentSession;
    context.go(session != null ? '/home' : '/auth/login');
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _skip() => _finishOnboarding();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final titles = [l.onboardingTitle1, l.onboardingTitle2, l.onboardingTitle3];
    final descs = [l.onboardingDesc1, l.onboardingDesc2, l.onboardingDesc3];
    final isLast = _currentPage == _totalPages - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header: step counter + skip ──
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 24, end: 12),
                child: Row(
                  children: [
                    Text(
                      '0${_currentPage + 1} / 0$_totalPages',
                      style: FlowUi.mono(size: 12, tracking: 0.1),
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: isLast ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: isLast,
                        child: TextButton(
                          onPressed: _skip,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textMediumEmphasis,
                            minimumSize: const Size(48, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(
                            l.onboardingSkip,
                            style: FlowUi.mono(size: 12, tracking: 0.1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Slides ──
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _totalPages,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => _Slide(
                  hero: switch (index) {
                    0 => _PatternSheetHero(
                        imageAsset: _template091,
                        setName: _name091,
                        setLabel: '${l.onboardingUvTemplate} · 091',
                      ),
                    1 => _LayersHero(
                        imageAsset: _template064,
                        setName: _name064,
                        layersLabel: l.onboardingLayers,
                        textLabel: l.onboardingLayerText,
                        stickerLabel: l.onboardingLayerSticker,
                        stickerName: l.onboardingStickerCrown,
                        templateLabel: l.onboardingLayerTemplate,
                      ),
                    _ => _ExportHero(
                        imageAsset: _dressed091,
                        setName: _name091,
                        previewLabel: l.onboardingPreview3d,
                        readyLabel: l.onboardingReady,
                      ),
                  },
                  title: titles[index],
                  description: descs[index],
                ),
              ),
            ),

            // ── Footer: progress + CTA ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepBars(current: _currentPage, total: _totalPages),
                  const SizedBox(height: 20),
                  FlowPrimaryButton(
                    label:
                        isLast ? l.onboardingGetStarted : l.onboardingContinue,
                    onPressed: _nextPage,
                    showArrow: true,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: isLast
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              l.robloxDisclaimer,
                              textAlign: TextAlign.center,
                              style: FlowUi.body(size: 11, height: 1.4),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final Widget hero;
  final String title;
  final String description;

  const _Slide({
    required this.hero,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Expanded(child: hero),
          const SizedBox(height: 28),
          Text(title, style: FlowUi.display(size: 30)),
          const SizedBox(height: 12),
          Text(description, style: FlowUi.body(size: 15, height: 1.55)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StepBars extends StatelessWidget {
  final int current;
  final int total;

  const _StepBars({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsetsDirectional.only(end: 6),
          width: i == current ? 28 : 12,
          height: 4,
          decoration: BoxDecoration(
            color: i <= current ? AppColors.onBackground : AppColors.borderSubtle,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

/// White sheet with a fine grid, used behind templates.
class _GridCard extends StatelessWidget {
  final Widget child;

  const _GridCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: FlowGridPainter(color: AppColors.surfaceContainerLow),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.onBackground,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: FlowUi.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: FlowUi.body(
              size: 12,
              weight: FontWeight.w700,
              color: AppColors.background,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Slide 1: template on pattern paper with measurements ───
class _PatternSheetHero extends StatelessWidget {
  final String imageAsset;
  final String setName;
  final String setLabel;

  const _PatternSheetHero({
    required this.imageAsset,
    required this.setName,
    required this.setLabel,
  });

  @override
  Widget build(BuildContext context) {
    return _GridCard(
      child: LayoutBuilder(
        builder: (context, c) {
          const padStart = 52.0, padTop = 50.0, padEnd = 24.0, padBottom = 62.0;
          final areaW = (c.maxWidth - padStart - padEnd).clamp(0.0, 9999.0).toDouble();
          final areaH = (c.maxHeight - padTop - padBottom).clamp(0.0, 9999.0).toDouble();
          var iw = areaW;
          var ih = iw * 559 / 585;
          if (ih > areaH) {
            ih = areaH;
            iw = ih * 585 / 559;
          }
          final left = padStart + (areaW - iw) / 2;
          final top = padTop + (areaH - ih) / 2;
          final ink = AppColors.onBackground;
          final labelBg = AppColors.surfaceContainerLowest;

          return Stack(
            children: [
              // Horizontal dimension (width)
              Positioned(
                left: left,
                top: top - 18,
                width: iw,
                height: 10,
                child: _Dimension(horizontal: true, color: ink),
              ),
              Positioned(
                left: left,
                top: top - 34,
                width: iw,
                child: Center(
                  heightFactor: 1,
                  child: Container(
                    color: labelBg,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('585 px',
                        style: FlowUi.mono(size: 10, color: ink)),
                  ),
                ),
              ),
              // Vertical dimension (height)
              Positioned(
                left: left - 22,
                top: top,
                width: 10,
                height: ih,
                child: _Dimension(horizontal: false, color: ink),
              ),
              Positioned(
                left: left - 44,
                top: top,
                height: ih,
                width: 18,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Container(
                      color: labelBg,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('559 px',
                          style: FlowUi.mono(size: 10, color: ink)),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                width: iw,
                height: ih,
                child: Image.asset(imageAsset, fit: BoxFit.contain),
              ),
              PositionedDirectional(
                start: 16,
                end: 16,
                bottom: 14,
                child: Row(
                  children: [
                    Flexible(child: _Chip(label: setName)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        setLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: FlowUi.mono(size: 10, tracking: 0.06),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Dimension extends StatelessWidget {
  final bool horizontal;
  final Color color;

  const _Dimension({required this.horizontal, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DimensionPainter(horizontal: horizontal, color: color),
    );
  }
}

class _DimensionPainter extends CustomPainter {
  final bool horizontal;
  final Color color;

  _DimensionPainter({required this.horizontal, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    if (horizontal) {
      final y = size.height / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      canvas.drawLine(const Offset(0.75, 0), Offset(0.75, size.height), p);
      canvas.drawLine(Offset(size.width - 0.75, 0),
          Offset(size.width - 0.75, size.height), p);
    } else {
      final x = size.width / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      canvas.drawLine(const Offset(0, 0.75), Offset(size.width, 0.75), p);
      canvas.drawLine(Offset(0, size.height - 0.75),
          Offset(size.width, size.height - 0.75), p);
    }
  }

  @override
  bool shouldRepaint(_DimensionPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.horizontal != horizontal;
}

// ─── Slide 2: template + layers panel ───
class _LayersHero extends StatelessWidget {
  final String imageAsset;
  final String setName;
  final String layersLabel;
  final String textLabel;
  final String stickerLabel;
  final String stickerName;
  final String templateLabel;

  const _LayersHero({
    required this.imageAsset,
    required this.setName,
    required this.layersLabel,
    required this.textLabel,
    required this.stickerLabel,
    required this.stickerName,
    required this.templateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return _GridCard(
      child: LayoutBuilder(
        builder: (context, c) {
          final panelW = (c.maxWidth - 32).clamp(0.0, 252.0).toDouble();
          final imgW = c.maxWidth * 0.66;
          return Stack(
            children: [
              PositionedDirectional(
                start: 18,
                top: 18,
                width: imgW,
                height: imgW * 559 / 585,
                child: Image.asset(imageAsset, fit: BoxFit.contain),
              ),
              PositionedDirectional(
                end: 14,
                bottom: 14,
                width: panelW,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(layersLabel,
                                  style: FlowUi.mono(size: 10, tracking: 0.12)),
                            ),
                            Text('3', style: FlowUi.mono(size: 10)),
                          ],
                        ),
                      ),
                      _LayerRow(
                        selected: true,
                        thumb: Container(
                          color: AppColors.onBackground,
                          alignment: Alignment.center,
                          child: Text(
                            'T',
                            style: FlowUi.display(
                                size: 15, color: AppColors.background),
                          ),
                        ),
                        title: 'KING',
                        subtitle: textLabel,
                        trailing: Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsetsDirectional.only(end: 6),
                          decoration: const BoxDecoration(
                            color: FlowUi.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      _LayerRow(
                        thumb: Container(
                          color: AppColors.surfaceContainerLow,
                          alignment: Alignment.center,
                          child: CustomPaint(
                            size: const Size(18, 18),
                            painter:
                                _CrownPainter(color: AppColors.onBackground),
                          ),
                        ),
                        title: stickerName,
                        subtitle: stickerLabel,
                        trailing: Icon(Icons.visibility_outlined,
                            size: 18, color: AppColors.textMediumEmphasis),
                      ),
                      _LayerRow(
                        thumb: Container(
                          color: AppColors.surfaceContainerLow,
                          padding: const EdgeInsets.all(2),
                          child: Image.asset(imageAsset, fit: BoxFit.contain),
                        ),
                        title: setName,
                        subtitle: templateLabel,
                        trailing: Icon(Icons.lock_outline_rounded,
                            size: 18, color: AppColors.textMediumEmphasis),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  final bool selected;
  final Widget thumb;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _LayerRow({
    this.selected = false,
    required this.thumb,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: selected
            ? FlowUi.orange.withValues(alpha: AppColors.isDark ? 0.18 : 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(width: 34, height: 34, child: thumb),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlowUi.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppColors.onBackground,
                    height: 1.25,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlowUi.body(size: 11, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          trailing,
        ],
      ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  final Color color;

  _CrownPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path()
      ..moveTo(3 * s, 8 * s)
      ..lineTo(7.5 * s, 12 * s)
      ..lineTo(12 * s, 5 * s)
      ..lineTo(16.5 * s, 12 * s)
      ..lineTo(21 * s, 8 * s)
      ..lineTo(19 * s, 19 * s)
      ..lineTo(5 * s, 19 * s)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => oldDelegate.color != color;
}

// ─── Slide 3: dressed avatar + exported file ───
class _ExportHero extends StatelessWidget {
  final String imageAsset;
  final String setName;
  final String previewLabel;
  final String readyLabel;

  const _ExportHero({
    required this.imageAsset,
    required this.setName,
    required this.previewLabel,
    required this.readyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151614),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              imageAsset,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.4),
            ),
          ),
          PositionedDirectional(
            start: 16,
            top: 16,
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                previewLabel,
                style: FlowUi.mono(size: 10, color: Colors.white, tracking: 0.1),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              height: 60,
              padding: const EdgeInsetsDirectional.only(start: 10, end: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: FlowUi.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.download_rounded,
                        color: FlowUi.ink, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          setName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FlowUi.body(
                            size: 14,
                            weight: FontWeight.w700,
                            color: FlowUi.ink,
                            height: 1.25,
                          ),
                        ),
                        Text(
                          '585 × 559 · PNG',
                          style: FlowUi.mono(
                            size: 10,
                            color: const Color(0xFF5A5C5A),
                            tracking: 0.04,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_rounded,
                      size: 18, color: FlowUi.success),
                  const SizedBox(width: 4),
                  Text(
                    readyLabel,
                    style: FlowUi.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: FlowUi.success,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
