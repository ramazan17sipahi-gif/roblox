import 'dart:typed_data';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../editor_state.dart';

/// Professional layer panel — Photoshop-style layer management with
/// opacity slider, visibility/lock toggles, reorder, and active selection.
class LayerPanel extends StatefulWidget {
  final EditorState editorState;
  final Map<String, Uint8List?>? thumbnails;
  final ValueChanged<String>? onLayerRemoved;
  final VoidCallback? onChanged;

  const LayerPanel({
    super.key,
    required this.editorState,
    this.thumbnails,
    this.onLayerRemoved,
    this.onChanged,
  });

  @override
  State<LayerPanel> createState() => _LayerPanelState();
}

class _LayerPanelState extends State<LayerPanel> {
  @override
  void initState() {
    super.initState();
    widget.editorState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.editorState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _notifyChanged() {
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final layers = widget.editorState.layers;
    final activeId = widget.editorState.activeLayerId;
    final l = AppLocalizations.of(context)!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Icon(Icons.layers, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                l.layerPanelTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${layers.length}',
                style: TextStyle(color: AppColors.outlineVariant, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              IconButton(
                icon: Icon(Icons.add_circle, color: AppColors.primary, size: 22),
                onPressed: _showAddLayerDialog,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: layers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.layers_clear, color: AppColors.outlineVariant, size: 32),
                      SizedBox(height: 8),
                      Text(l.layerNoLayers, style: TextStyle(color: AppColors.outlineVariant, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  itemCount: layers.length,
                  onReorder: (oldIndex, newIndex) {
                    widget.editorState.reorderLayers(oldIndex, newIndex);
                    widget.editorState.pushAction(l.layerPanelReordered);
                    _notifyChanged();
                  },
                  itemBuilder: (context, index) {
                    final layer = layers[index];
                    final isActive = layer.id == activeId;
                    final isBase = layer.id == EditorState.baseLayerId;

                    return Material(
                      key: ValueKey(layer.id),
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          widget.editorState.setActiveLayer(layer.id);
                          _notifyChanged();
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primary.withValues(alpha: 0.45)
                                  : AppColors.outlineVariant.withValues(alpha: 0.2),
                              width: isActive ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  _buildThumbnail(layer, isActive),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                layer.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: layer.isVisible
                                                      ? AppColors.onBackground
                                                      : AppColors.outlineVariant,
                                                  decoration: layer.isVisible ? null : TextDecoration.lineThrough,
                                                ),
                                              ),
                                            ),
                                            if (isActive)
                                              Container(
                                                margin: const EdgeInsets.only(left: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'ACTIVE',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w900,
                                                    color: AppColors.primary,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        Text(
                                          l.layerOpacityBlend(
                                            (layer.opacity * 100).toInt().toString(),
                                            layer.blendMode,
                                          ),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.outlineVariant.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isBase)
                                    GestureDetector(
                                      onTap: () {
                                        widget.editorState.addLayer('${layer.name} Copy', layer.icon);
                                        widget.editorState.pushAction(l.layerPanelDuplicated(layer.name));
                                        _notifyChanged();
                                      },
                                      child: Icon(Icons.copy, size: 14, color: AppColors.outlineVariant),
                                    ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      widget.editorState.toggleLayerLock(index);
                                      _notifyChanged();
                                    },
                                    child: Icon(
                                      layer.isLocked ? Icons.lock : Icons.lock_open,
                                      size: 14,
                                      color: layer.isLocked ? AppColors.primary : AppColors.outlineVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      widget.editorState.toggleLayerVisibility(index);
                                      _notifyChanged();
                                    },
                                    child: Icon(
                                      layer.isVisible ? Icons.visibility : Icons.visibility_off,
                                      size: 14,
                                      color: layer.isVisible ? AppColors.primary : AppColors.outlineVariant,
                                    ),
                                  ),
                                  if (!isBase) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () {
                                        final removedId = widget.editorState.removeLayer(index);
                                        if (removedId != null) {
                                          widget.editorState.pushAction(l.layerPanelRemoved(layer.name));
                                          widget.onLayerRemoved?.call(removedId);
                                          _notifyChanged();
                                        }
                                      },
                                      child: Icon(Icons.close, size: 14, color: AppColors.outlineVariant),
                                    ),
                                  ],
                                  SizedBox(width: 4),
                                  Icon(Icons.drag_handle, size: 14, color: AppColors.outlineVariant),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  const SizedBox(width: 28),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 2,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                        activeTrackColor: AppColors.primary,
                                        inactiveTrackColor: AppColors.outlineVariant.withValues(alpha: 0.12),
                                        thumbColor: AppColors.primary,
                                        overlayShape: SliderComponentShape.noOverlay,
                                      ),
                                      child: Slider(
                                        value: layer.opacity,
                                        onChanged: (v) {
                                          setState(() => layer.opacity = v);
                                          _notifyChanged();
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddLayerDialog() {
    final controller = TextEditingController();
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.layerPanelAddLayerTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: l.layerPanelAddLayerHint),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.commonCancel)),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                widget.editorState.addLayer(name, Icons.auto_awesome);
                widget.editorState.pushAction(l.editorAddedLayer(name));
                _notifyChanged();
              }
              Navigator.pop(ctx);
            },
            child: Text(l.layerPanelAddButton, style: const TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(EditorLayer layer, bool isActive) {
    final thumbData = widget.thumbnails?[layer.id];
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.5)
              : (layer.isVisible
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.outlineVariant.withValues(alpha: 0.15)),
          width: 1.5,
        ),
        color: const Color(0xFF1A1A2E),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: thumbData != null && thumbData.isNotEmpty
            ? Image.memory(
                thumbData,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.08),
                      AppColors.primary.withValues(alpha: 0.02),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    layer.icon,
                    size: 18,
                    color: layer.isVisible
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
      ),
    );
  }
}
