import 'dart:math' as math;
import 'dart:ui';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_config.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../../l10n/generated/app_localizations.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _entranceController;
  late AnimationController _floatController;
  late AnimationController _pulseController;

  late Animation<double> _heroScale;
  late Animation<double> _heroOpacity;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentOpacity;

  static const _totalPages = 3;

  // ── Page Configurations ──
  static const _accentColors = [
    Color(0xFFFF793A), // Vibrant orange
    Color(0xFF9F3B00), // Deep burnt orange
    Color(0xFF06693F), // Emerald green
  ];

  static const _bgGradients = [
    [Color(0xFFFFF5EE), Color(0xFFFFF0E6)], // Warm cream
    [Color(0xFFFAF0EA), Color(0xFFF5E6DA)], // Soft peach
    [Color(0xFFEEF8F3), Color(0xFFE6F4EC)], // Mint cream
  ];

  static const _heroIcons = [
    Icons.auto_awesome_rounded,
    Icons.brush_rounded,
    Icons.rocket_launch_rounded,
  ];

  static const _floatingIcons = [
    [Icons.palette, Icons.star_rounded, Icons.diamond_rounded, Icons.auto_fix_high],
    [Icons.checkroom, Icons.straighten, Icons.crop_portrait, Icons.format_paint],
    [Icons.cloud_upload_rounded, Icons.verified_rounded, Icons.trending_up, Icons.monetization_on],
  ];

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _setupAnimations();
    _entranceController.forward();
  }

  void _setupAnimations() {
    _heroScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _heroOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entranceController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      context.go('/auth/login');
    }
  }

  void _skip() => context.go('/auth/login');

  List<String> _getTitles(AppLocalizations l) => [
        l.onboardingTitle1,
        l.onboardingTitle2,
        l.onboardingTitle3,
      ];

  List<String> _getDescs(AppLocalizations l) => [
        l.onboardingDesc1,
        l.onboardingDesc2,
        l.onboardingDesc3,
      ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final titles = _getTitles(l);
    final descs = _getDescs(l);

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _bgGradients[_currentPage],
          ),
        ),
        child: Stack(
          children: [
            // ── Animated background orbs ──
            ..._buildAnimatedOrbs(),

            // ── Skip button ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 20,
              child: GestureDetector(
                onTap: _skip,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  child: Text(
                    l.onboardingSkip,
                    style: TextStyle(
                      color: AppColors.onBackground.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),

            // ── Logo / branding ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 24,
              child: Row(
                children: [
                  const BrandLogo(size: 32, borderRadius: 8),
                  const SizedBox(width: 8),
                  Text(
                    AppConfig.appNameShort,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            // ── Page content ──
            PageView.builder(
              controller: _pageController,
              itemCount: _totalPages,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
                _entranceController.reset();
                _entranceController.forward();
              },
              itemBuilder: (context, index) => _buildPage(
                context,
                index: index,
                title: titles[index],
                description: descs[index],
                accentColor: _accentColors[index],
                isLastPage: index == _totalPages - 1,
                l: l,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(
    BuildContext context, {
    required int index,
    required String title,
    required String description,
    required Color accentColor,
    required bool isLastPage,
    required AppLocalizations l,
  }) {
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, _) {
        return Column(
          children: [
            // ─── HERO AREA (55%) ───
            Expanded(
              flex: 50,
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 60,
                ),
                child: Opacity(
                  opacity: _heroOpacity.value,
                  child: Transform.scale(
                    scale: _heroScale.value,
                    child: _buildHeroArea(index, accentColor),
                  ),
                ),
              ),
            ),

            // ─── CONTENT CARD (50%) ───
            Expanded(
              flex: 50,
              child: SlideTransition(
                position: _contentSlide,
                child: FadeTransition(
                  opacity: _contentOpacity,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(36)),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.08),
                          blurRadius: 40,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Decorative line
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(height: 24),

                          // Step indicator
                          _buildStepIndicator(index, accentColor),
                          const SizedBox(height: 20),

                          // Title
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                              height: 1.15,
                              letterSpacing: -0.5,
                              color: AppColors.onBackground,
                            ),
                          ),
                          SizedBox(height: 12),

                          // Description
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.onBackground
                                    .withValues(alpha: 0.5),
                                height: 1.6,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (isLastPage) ...[
                            SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                l.robloxDisclaimer,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.onBackground.withValues(alpha: 0.35),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),

                          // Progress dots
                          _buildProgressDots(accentColor),
                          const SizedBox(height: 24),

                          // CTA Button
                          _buildCTAButton(
                            label: isLastPage
                                ? l.onboardingGetStarted
                                : l.onboardingContinue,
                            accentColor: accentColor,
                          ),
                          SizedBox(
                              height:
                                  MediaQuery.of(context).padding.bottom + 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── HERO AREA ───
  Widget _buildHeroArea(int pageIndex, Color accentColor) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Outer pulsing ring
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) {
            final pulse =
                1.0 + (_pulseController.value * 0.08);
            return Transform.scale(
              scale: pulse,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                ),
              ),
            );
          },
        ),

        // Middle ring
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: accentColor.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
        ),

        // Inner glowing circle with icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor,
                accentColor.withValues(alpha: 0.7),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.4),
                blurRadius: 40,
                spreadRadius: 5,
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: 0.15),
                blurRadius: 80,
                spreadRadius: 20,
              ),
            ],
          ),
          child: Icon(
            _heroIcons[pageIndex],
            size: 48,
            color: Colors.white,
          ),
        ),

        // Floating orbit icons
        ..._buildFloatingIcons(pageIndex, accentColor),
      ],
    );
  }

  List<Widget> _buildFloatingIcons(int pageIndex, Color accentColor) {
    final icons = _floatingIcons[pageIndex];
    final angles = [0.0, math.pi / 2, math.pi, 3 * math.pi / 2];
    const radius = 140.0;

    return List.generate(icons.length, (i) {
      return AnimatedBuilder(
        animation: _floatController,
        builder: (_, __) {
          final baseAngle = angles[i];
          final wobble = math.sin(_floatController.value * math.pi * 2 + i) * 0.15;
          final angle = baseAngle + wobble;
          final floatOffset = math.sin(_floatController.value * math.pi + i * 0.8) * 6;

          final x = math.cos(angle) * radius;
          final y = math.sin(angle) * radius + floatOffset;

          return Transform.translate(
            offset: Offset(x, y),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icons[i],
                size: 20,
                color: accentColor,
              ),
            ),
          );
        },
      );
    });
  }

  // ─── Step indicator ───
  Widget _buildStepIndicator(int index, Color accentColor) {
    final labels = ['01', '02', '03'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            labels[index],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: accentColor,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ...List.generate(3, (i) {
          return Container(
            width: i == index ? 20 : 6,
            height: 3,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: i <= index
                  ? accentColor
                  : accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ],
    );
  }

  // ─── CTA Button ───
  Widget _buildCTAButton(
      {required String label, required Color accentColor}) {
    return GestureDetector(
      onTap: _nextPage,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accentColor, accentColor.withValues(alpha: 0.8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Progress Dots ───
  Widget _buildProgressDots(Color accentColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_totalPages, (i) {
        final isActive = i == _currentPage;
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? accentColor
                  : accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  // ─── Animated Background Orbs ───
  List<Widget> _buildAnimatedOrbs() {
    final accent = _accentColors[_currentPage];
    return [
      // Top-left orb
      AnimatedBuilder(
        animation: _floatController,
        builder: (_, __) {
          final offset = _floatController.value * 20;
          return Positioned(
            top: -100 + offset,
            left: -80,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      ),
      // Bottom-right orb
      AnimatedBuilder(
        animation: _floatController,
        builder: (_, __) {
          final offset = _floatController.value * 15;
          return Positioned(
            bottom: 100 - offset,
            right: -60,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      ),
      // Center subtle orb
      AnimatedBuilder(
        animation: _pulseController,
        builder: (_, __) {
          return Positioned(
            top: 200,
            right: 40,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: accent.withValues(
                      alpha: 0.06 + _pulseController.value * 0.04),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      ),
    ];
  }
}
