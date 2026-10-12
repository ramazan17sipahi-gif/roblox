import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:networking/networking.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../../shared/widgets/flow_ui.dart';
import '../../../../l10n/generated/app_localizations.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _textOpacity;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOutCubic),
      ),
    );
    _textOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.4, curve: Curves.easeOut),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
    );
    _controller.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    try {
      final session = ref.read(supabaseClientProvider).auth.currentSession;
      if (session != null) {
        context.go('/home');
        return;
      }

      var onboardingDone = false;
      try {
        final prefs = await SharedPreferences.getInstance()
            .timeout(const Duration(seconds: 2));
        onboardingDone = prefs.getBool('onboarding_completed') ?? false;
      } catch (e) {
        debugPrint('[splash] prefs failed: $e');
      }
      if (!mounted) return;
      context.go(onboardingDone ? '/auth/login' : '/onboarding');
    } catch (e, st) {
      debugPrint('[splash] navigate failed: $e\n$st');
      if (!mounted) return;
      // Last-resort escape so the user is never stuck on splash.
      context.go('/auth/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: FlowUi.orange,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: FlowUi.orange,
        body: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: FlowGridPainter(
                  color: FlowUi.ink.withValues(alpha: 0.07),
                  step: 26,
                  offset: 0,
                ),
              ),
            ),

            // Crop marks + measurement labels.
            _CropMark(top: topInset + 16, left: 24),
            _CropMark(top: topInset + 16, right: 24),
            _CropMark(bottom: bottomInset + 24, left: 24),
            _CropMark(bottom: bottomInset + 24, right: 24),
            Positioned(
              top: topInset + 22,
              left: 52,
              child: Text('585 × 559',
                  style: FlowUi.mono(color: FlowUi.ink)),
            ),
            Positioned(
              top: topInset + 22,
              right: 52,
              child: Text('PNG', style: FlowUi.mono(color: FlowUi.ink)),
            ),

            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _logoOpacity,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: FlowUi.ink, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: FlowUi.ink,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const BrandLogo(size: 108, borderRadius: 26),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FadeTransition(
                      opacity: _textOpacity,
                      child: Column(
                        children: [
                          Text(
                            l.splashBrandName,
                            textAlign: TextAlign.center,
                            style: FlowUi.display(size: 30, color: FlowUi.ink)
                                .copyWith(height: 1.05),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l.splashTagline,
                            textAlign: TextAlign.center,
                            style: FlowUi.mono(
                              size: 12,
                              color: FlowUi.ink,
                              tracking: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset + 72,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    width: 132,
                    height: 4,
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (context, _) => LinearProgressIndicator(
                        value: _progress.value,
                        minHeight: 4,
                        backgroundColor: FlowUi.ink.withValues(alpha: 0.18),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(FlowUi.ink),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropMark extends StatelessWidget {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  const _CropMark({this.top, this.left, this.right, this.bottom});

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: FlowUi.ink, width: 2);
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            border: Border(
              top: top != null ? side : BorderSide.none,
              bottom: bottom != null ? side : BorderSide.none,
              left: left != null ? side : BorderSide.none,
              right: right != null ? side : BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}
