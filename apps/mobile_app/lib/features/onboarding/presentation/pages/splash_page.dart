import 'dart:math' as math;
import 'dart:ui';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../../l10n/generated/app_localizations.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _blobController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _ringRotation;
  late Animation<double> _textSlide;
  late Animation<double> _textOpacity;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _progressWidth;
  late Animation<double> _iconsOpacity;

  @override
  void initState() {
    super.initState();

    // Logo entrance animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Continuous pulse for the logo glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Blob floating motion
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    // Logo scale: starts small, bounces to full size
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
    ]).animate(CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5)));

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
    );

    _ringRotation = Tween<double>(begin: 0.0, end: 12.0 * math.pi / 180).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.1, 0.6, curve: Curves.elasticOut)),
    );

    _textSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.35, 0.65, curve: Curves.easeOutCubic)),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.35, 0.6, curve: Curves.easeOut)),
    );

    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.5, 0.75, curve: Curves.easeOut)),
    );

    _progressWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.6, 1.0, curve: Curves.easeInOut)),
    );

    _iconsOpacity = Tween<double>(begin: 0.0, end: 0.15).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.7, 1.0, curve: Curves.easeOut)),
    );

    _logoController.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (mounted) {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _blobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: Listenable.merge([_logoController, _pulseController, _blobController]),
        builder: (context, _) {
          return Stack(
            children: [
              // Removed paper texture mock

              // Animated Blur Blobs
              _buildAnimatedBlob(
                top: -100 + (_blobController.value * 20),
                left: -100 + (_blobController.value * 15),
                color: AppColors.primaryContainer.withOpacity(0.2),
                size: 300,
              ),
              _buildAnimatedBlob(
                bottom: -100 + (_blobController.value * 25),
                right: -100 + (_blobController.value * 10),
                color: AppColors.outlineVariant.withOpacity(0.2),
                size: 400,
              ),
              _buildAnimatedBlob(
                top: MediaQuery.of(context).size.height * 0.4,
                left: MediaQuery.of(context).size.width * 0.3,
                color: AppColors.primaryContainer.withOpacity(0.2),
                size: 250,
              ),

              // Main Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Logo
                    Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.rotate(
                                angle: _ringRotation.value,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.primaryContainer.withValues(alpha: 0.25),
                                      width: 4,
                                    ),
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.25),
                                      blurRadius: 20 + _pulseController.value * 10,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const BrandLogo(size: 96, borderRadius: 24),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 40),

                    // Brand Name — slides up
                    Transform.translate(
                      offset: Offset(0, _textSlide.value),
                      child: Opacity(
                        opacity: _textOpacity.value,
                        child: Text(
                          AppLocalizations.of(context).splashBrandName,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tagline — fades in
                    Opacity(
                      opacity: _subtitleOpacity.value,
                      child: Text(
                        AppLocalizations.of(context).splashTagline,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4.0,
                          color: AppColors.outlineVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Progress Indicator — animated width
              Positioned(
                bottom: 64,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 48,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progressWidth.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.actionGradient,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Decorative bottom icons — fade in
              Positioned(
                bottom: 32,
                left: 48,
                right: 48,
                child: Opacity(
                  opacity: _iconsOpacity.value,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.auto_awesome, size: 20, color: AppColors.outlineVariant),
                      Icon(Icons.checkroom, size: 20, color: AppColors.outlineVariant),
                      Icon(Icons.brush, size: 20, color: AppColors.outlineVariant),
                      Icon(Icons.storefront, size: 20, color: AppColors.outlineVariant),
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

  Widget _buildAnimatedBlob({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required Color color,
    required double size,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
