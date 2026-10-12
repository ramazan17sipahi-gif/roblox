import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared look for the splash → onboarding → auth flow.
///
/// A "pattern workshop" style: flat surfaces, a fine cutting-mat grid,
/// measurement labels in a monospace face and one strong orange action.
class FlowUi {
  FlowUi._();

  /// Brand orange (same as the app icon / native splash background).
  static const Color orange = Color(0xFFFF6A1A);

  /// Near-black used on top of orange (white on orange fails contrast).
  static const Color ink = Color(0xFF1C1D1B);

  static const Color success = Color(0xFF06693F);

  /// Headline face. Plus Jakarta Sans only covers Latin, so Cyrillic
  /// (ru) falls back per glyph to Manrope ExtraBold; Korean and Arabic
  /// fall back to the platform's own system font.
  static TextStyle display({double size = 32, Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.03 * size,
        color: color ?? AppColors.onBackground,
      ).copyWith(fontFamilyFallback: _displayFallback);

  static List<String> get _displayFallback {
    final family = GoogleFonts.manrope(fontWeight: FontWeight.w800).fontFamily;
    return family == null ? const [] : [family];
  }

  static TextStyle body({
    double size = 15,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double height = 1.5,
  }) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color ?? AppColors.textMediumEmphasis,
      );

  static TextStyle mono({
    double size = 11,
    Color? color,
    double tracking = 0.08,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: size * tracking,
        color: color ?? AppColors.textMediumEmphasis,
      );
}

/// Full-width orange call to action with ink text.
class FlowPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool showArrow;

  const FlowPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.showArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: FlowUi.display(size: 17, color: FlowUi.ink)
          .copyWith(letterSpacing: -0.2, height: 1.2),
    );

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: FlowUi.orange,
          foregroundColor: FlowUi.ink,
          disabledBackgroundColor: FlowUi.orange.withValues(alpha: 0.55),
          disabledForegroundColor: FlowUi.ink.withValues(alpha: 0.7),
          elevation: 0,
          padding: const EdgeInsetsDirectional.only(start: 24, end: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: FlowUi.ink,
                ),
              )
            : showArrow
                ? Row(
                    children: [
                      Expanded(child: text),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 22, color: FlowUi.ink),
                    ],
                  )
                : text,
      ),
    );
  }
}

/// Labelled text field used on the auth screens.
class FlowTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailingLabel;
  final String? showPasswordLabel;
  final String? hidePasswordLabel;

  const FlowTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.isPassword = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.trailingLabel,
    this.showPasswordLabel,
    this.hidePasswordLabel,
  });

  @override
  State<FlowTextField> createState() => _FlowTextFieldState();
}

class _FlowTextFieldState extends State<FlowTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: FlowUi.body(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.onBackground,
                ),
              ),
            ),
            if (widget.trailingLabel != null) widget.trailingLabel!,
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          obscureText: widget.isPassword && _obscured,
          enableSuggestions: !widget.isPassword,
          autocorrect: !widget.isPassword,
          keyboardType: widget.keyboardType,
          autofillHints: widget.autofillHints,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          style: FlowUi.body(
            size: 16,
            weight: FontWeight.w600,
            color: AppColors.onBackground,
            height: 1.3,
          ),
          cursorColor: AppColors.onBackground,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: FlowUi.body(
              size: 16,
              color: AppColors.outlineVariant,
              height: 1.3,
            ),
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            isDense: false,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AppColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide:
                  BorderSide(color: AppColors.onBackground, width: 1.5),
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _obscured
                        ? widget.showPasswordLabel
                        : widget.hidePasswordLabel,
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.textMediumEmphasis,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Fine square grid, like a cutting mat / pattern paper.
class FlowGridPainter extends CustomPainter {
  final Color color;
  final double step;
  final double offset;

  const FlowGridPainter({
    required this.color,
    this.step = 19,
    this.offset = 9,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = offset; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = offset; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(FlowGridPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.step != step ||
      oldDelegate.offset != offset;
}
