import 'dart:math' as math;
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'drawing_canvas.dart';

/// Floating toolbar shown when a canvas element is selected.
/// Provides Copy, Paste, Flip H/V, Rotate, Delete, and Opacity controls.
class ElementControls extends StatelessWidget {
  final CanvasElement element;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onDelete;
  final VoidCallback onFlipH;
  final VoidCallback onFlipV;
  final VoidCallback onRotateCW;
  final VoidCallback onRotateCCW;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double>? onRotationChanged;
  final ValueChanged<double>? onScaleChanged;
  final VoidCallback? onBringForward;
  final VoidCallback? onSendBack;

  const ElementControls({
    super.key,
    required this.element,
    required this.onCopy,
    required this.onPaste,
    required this.onDelete,
    required this.onFlipH,
    required this.onFlipV,
    required this.onRotateCW,
    required this.onRotateCCW,
    required this.onOpacityChanged,
    this.onRotationChanged,
    this.onScaleChanged,
    this.onBringForward,
    this.onSendBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Action buttons row ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ControlButton(icon: Icons.copy, label: AppLocalizations.of(context)!.elementControlsCopy, onTap: onCopy),
              _ControlButton(icon: Icons.paste, label: AppLocalizations.of(context)!.elementControlsPaste, onTap: onPaste),
              _divider(),
              _ControlButton(icon: Icons.flip, label: AppLocalizations.of(context)!.elementControlsFlipH, onTap: onFlipH),
              _ControlButton(icon: Icons.flip_camera_android, label: AppLocalizations.of(context)!.elementControlsFlipV, onTap: onFlipV),
              _divider(),
              _ControlButton(icon: Icons.rotate_left, label: '-90°', onTap: onRotateCCW),
              _ControlButton(icon: Icons.rotate_right, label: '+90°', onTap: onRotateCW),
              _divider(),
              _ControlButton(
                icon: Icons.delete_outline,
                label: AppLocalizations.of(context)!.elementControlsDelete,
                onTap: onDelete,
                color: const Color(0xFFFF5252),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // ── Opacity slider ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.opacity, size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                '${(element.opacity * 100).toInt()}%',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70),
              ),
              SizedBox(
                width: 160,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: AppColors.primary,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: element.opacity,
                    min: 0.05,
                    max: 1.0,
                    onChanged: onOpacityChanged,
                  ),
                ),
              ),
            ],
          ),
          // ── Rotation slider (free angle) ──
          if (onRotationChanged != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.rotate_right, size: 14, color: Colors.white54),
                const SizedBox(width: 6),
                Text(
                  '${(element.rotation * 180 / math.pi).toInt()}°',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70),
                ),
                SizedBox(
                  width: 160,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: const Color(0xFF66BB6A),
                      inactiveTrackColor: Colors.white12,
                      thumbColor: const Color(0xFF66BB6A),
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: element.rotation,
                      min: -math.pi,
                      max: math.pi,
                      onChanged: onRotationChanged,
                    ),
                  ),
                ),
              ],
            ),
          // ── Scale slider ──
          if (onScaleChanged != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.zoom_in, size: 14, color: Colors.white54),
                const SizedBox(width: 6),
                Text(
                  '${(element.scale * 100).toInt()}%',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70),
                ),
                SizedBox(
                  width: 160,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: const Color(0xFF42A5F5),
                      inactiveTrackColor: Colors.white12,
                      thumbColor: const Color(0xFF42A5F5),
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: element.scale,
                      min: 0.1,
                      max: 5.0,
                      onChanged: onScaleChanged,
                    ),
                  ),
                ),
              ],
            ),
          // ── Z-order buttons ──
          if (onBringForward != null || onSendBack != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onSendBack != null)
                  _ControlButton(
                    icon: Icons.flip_to_back,
                    label: 'Back',
                    onTap: onSendBack!,
                  ),
                if (onBringForward != null)
                  _ControlButton(
                    icon: Icons.flip_to_front,
                    label: 'Front',
                    onTap: onBringForward!,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1, height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white12,
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color ?? Colors.white70),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              fontSize: 8, fontWeight: FontWeight.w600,
              color: color ?? Colors.white54,
            )),
          ],
        ),
      ),
    );
  }
}
