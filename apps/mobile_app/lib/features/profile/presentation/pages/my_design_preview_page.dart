import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/my_design_preview_params.dart';

/// My Design Preview Page — mandatory step before editing a user's own design.
///
/// Shows the design with a loading → preview → CTA flow:
/// 1. Loading state while thumbnail/model data resolves
/// 2. 3D/2D preview with metadata
/// 3. Bottom CTA: "Tasarımı düzenle"
///
/// Navigation contract:
/// - Incoming: `context.push('/my-design-preview', extra: MyDesignPreviewParams)`
/// - CTA: `context.push('/editor', extra: EditorRouteParams)` (normal push, not replacement)
/// - Back: standard pop → returns to Library/Profile (scroll state preserved)
class MyDesignPreviewPage extends StatefulWidget {
  final MyDesignPreviewParams design;

  const MyDesignPreviewPage({super.key, required this.design});

  @override
  State<MyDesignPreviewPage> createState() => _MyDesignPreviewPageState();
}

class _MyDesignPreviewPageState extends State<MyDesignPreviewPage>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _loadFailed = false;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _simulateLoad();
  }

  void _simulateLoad() {
    // If we have a thumbnail or model URL, simulate loading time for the preview
    // In production, this would be the actual asset download
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = !widget.design.hasThumbnail && !widget.design.hasModel;
        });
        _fadeController.forward();
      }
    });
  }

  void _retryLoad() {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    _simulateLoad();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTopBar(context),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPreviewArea(context),
                  const SizedBox(height: 24),
                  _buildDesignInfo(context),
                  const SizedBox(height: 16),
                  _buildMetadataCard(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          _buildBottomCTA(context, bottomPad),
        ],
      ),
    );
  }

  // ─── Top Bar ──────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    final statusColor = _statusColor(widget.design.status);
    final statusLabel = widget.design.status.toUpperCase().replaceAll('_', ' ');

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        bottom: 8,
        left: 10,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 22),
          ),
          Expanded(
            child: Text(
              'Tasarım Önizleme',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF4CAF50);
      case 'failed':
        return AppColors.error;
      case 'processing':
      case 'pending':
      case 'queued':
        return AppColors.primary;
      default:
        return AppColors.outlineVariant;
    }
  }

  // ─── Preview Area ─────────────────────────────────────────────────────

  Widget _buildPreviewArea(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final heroHeight = screenWidth * 0.85;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      height: heroHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surfaceContainerLow,
                    const Color(0xFFE8F5E9).withOpacity(0.5),
                    AppColors.surfaceContainerLow,
                  ],
                ),
              ),
            ),
            // Content: loading / preview / error
            if (_isLoading)
              _buildLoadingState()
            else if (_loadFailed)
              _buildErrorState()
            else
              _buildPreviewContent(),
            // Rotation hint (bottom)
            if (!_isLoading && !_loadFailed && widget.design.hasModel)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.threesixty,
                            size: 14, color: AppColors.outlineVariant),
                        SizedBox(width: 4),
                        Text(
                          '3D MODEL',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: AppColors.outlineVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.scale(
                scale: 1.0 + _pulseController.value * 0.08,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.view_in_ar,
                    size: 40,
                    color: AppColors.primary.withOpacity(
                        0.3 + _pulseController.value * 0.2),
                  ),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.surfaceContainerLow,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 3,
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Yükleniyor...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.outlineVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.cloud_off,
              size: 40,
              color: AppColors.error.withOpacity(0.5),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Önizleme yüklenemedi',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Bağlantınızı kontrol edip tekrar deneyin',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.outlineVariant,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _retryLoad,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Tekrar dene',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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

  Widget _buildPreviewContent() {
    return FadeTransition(
      opacity: _fadeController,
      child: widget.design.hasThumbnail
          ? Image.network(
              widget.design.thumbnailUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildIconFallback(),
              loadingBuilder: (_, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
            )
          : _buildIconFallback(),
    );
  }

  Widget _buildIconFallback() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.view_in_ar,
              size: 48,
              color: const Color(0xFF4CAF50).withOpacity(0.5),
            ),
          ),
          SizedBox(height: 12),
          Text(
            '3D Model',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Design Info ──────────────────────────────────────────────────────

  Widget _buildDesignInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.design.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.view_in_ar, size: 14, color: AppColors.outlineVariant),
              SizedBox(width: 4),
              Text(
                widget.design.jobType == 'classic_clothing'
                    ? 'Classic Clothing'
                    : '3D Generated',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.outlineVariant,
                ),
              ),
              if (widget.design.createdAt != null) ...[
                SizedBox(width: 8),
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  _timeAgo(widget.design.createdAt!),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.outlineVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
    if (diff.inHours < 24) return '${diff.inHours}sa önce';
    return '${diff.inDays}g önce';
  }

  // ─── Metadata Card ────────────────────────────────────────────────────

  Widget _buildMetadataCard(BuildContext context) {
    final details = <_DetailRow>[
      _DetailRow('Durum', widget.design.status.toUpperCase().replaceAll('_', ' ')),
      _DetailRow('Tür', widget.design.jobType == 'classic_clothing' ? 'Classic Clothing' : '3D Generation'),
      _DetailRow('Job ID', widget.design.jobId.length > 8 ? '${widget.design.jobId.substring(0, 8)}...' : widget.design.jobId),
      if (widget.design.hasModel) _DetailRow('3D Model', 'GLB'),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.1)),
      ),
      child: Column(
        children: details
            .map(
              (d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(
                      d.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.outlineVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      d.value,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ─── Bottom CTA ───────────────────────────────────────────────────────

  Widget _buildBottomCTA(BuildContext context, double bottomPad) {
    final canEdit = widget.design.hasModel && !_isLoading && !_loadFailed;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad > 0 ? bottomPad : 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: canEdit ? () => _onEditTap(context) : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: canEdit ? 1.0 : 0.5,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: AppColors.actionGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: canEdit
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isLoading ? Icons.hourglass_top : Icons.edit,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  _isLoading ? 'Yükleniyor...' : 'Tasarımı düzenle',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onEditTap(BuildContext context) {
    // Normal push (not replacement) — back from editor returns to this preview
    context.push('/editor', extra: widget.design.toEditorParams());
  }
}

class _DetailRow {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
}
