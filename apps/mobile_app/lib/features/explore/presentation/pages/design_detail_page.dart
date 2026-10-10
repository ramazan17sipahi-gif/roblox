import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/app_config.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../editor/data/editor_route_params.dart';
import '../../data/community_repository.dart';

class DesignDetailPage extends StatefulWidget {
  final Map<String, dynamic>? design;

  const DesignDetailPage({super.key, this.design});

  @override
  State<DesignDetailPage> createState() => _DesignDetailPageState();
}

class _DesignDetailPageState extends State<DesignDetailPage> {
  bool _isSaved = false;
  bool _isLiked = false;
  int _likesCount = 0;
  bool _loadingState = true;
  bool _busy = false;

  Map<String, dynamic>? get _design => widget.design;

  String? get _designId => _design?['id'] as String?;
  bool get _isCommunityDesign => _design?['_source'] != 'templates';

  String get _name => _design?['name'] as String? ?? 'Untitled';
  String? get _thumbnailUrl => _design?['thumbnail_url'] as String?;

  String get _authorName {
    final profile = _design?['profiles'];
    if (profile is Map) {
      return profile['display_name'] as String? ??
          profile['username'] as String? ??
          'Unknown';
    }
    return 'Unknown';
  }

  String? get _authorAvatarUrl {
    final profile = _design?['profiles'];
    if (profile is Map) {
      final path = profile['avatar_path'] as String?;
      if (path != null && path.startsWith('http')) return path;
      return profile['avatar_url'] as String?;
    }
    return null;
  }

  String get _category => _design?['category'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _likesCount = _design?['likes_count'] as int? ?? 0;
    _loadInteractionState();
  }

  Future<void> _loadInteractionState() async {
    if (!_isCommunityDesign || _designId == null) {
      if (mounted) setState(() => _loadingState = false);
      return;
    }
    final liked = await CommunityRepository.isLiked(_designId!);
    final saved = await CommunityRepository.isSaved(_designId!);
    if (mounted) {
      setState(() {
        _isLiked = liked;
        _isSaved = saved;
        _loadingState = false;
      });
    }
  }

  Future<void> _openEditor({bool remix = false}) async {
    if (_design == null) return;

    if (!_isCommunityDesign) {
      context.push(
        '/editor',
        extra: EditorRouteParams(
          mode: EditorMode.classicClothingBlankStart,
          clothingTemplate: CommunityRepository.templateTypeFromDesign(_design!),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      String? projectId;
      if (remix || _design!['design_data'] != null) {
        projectId = await CommunityRepository.forkDesignToNewProject(_design!);
      }

      if (!mounted) return;

      if (projectId != null) {
        context.push(
          '/editor',
          extra: EditorRouteParams(
            mode: EditorMode.classicClothingBlankStart,
            clothingTemplate: CommunityRepository.templateTypeFromDesign(_design!),
            projectId: projectId,
          ),
        );
      } else {
        context.push(
          '/editor',
          extra: EditorRouteParams(
            mode: EditorMode.classicClothingBlankStart,
            clothingTemplate: CommunityRepository.templateTypeFromDesign(_design!),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleLike() async {
    if (!_isCommunityDesign || _designId == null) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to like designs'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final newState = await CommunityRepository.toggleLike(_designId!);
    if (newState == null || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update like'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() {
      _isLiked = newState;
      _likesCount += newState ? 1 : -1;
      if (_likesCount < 0) _likesCount = 0;
      _design?['likes_count'] = _likesCount;
    });
  }

  Future<void> _toggleSave() async {
    if (!_isCommunityDesign || _designId == null) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save designs'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final newState = await CommunityRepository.toggleSave(_designId!);
    if (newState == null || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update save'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isSaved = newState);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newState
              ? AppLocalizations.of(context)!.designDetailSavedToLibrary
              : AppLocalizations.of(context)!.designDetailRemovedFromLibrary,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copyShareLink() {
    if (_designId == null) return;
    final link = AppConfig.designShareUrl(_designId!);
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.designDetailLinkCopied),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareDesign() {
    if (_designId == null) return;
    Share.share(
      'Check out "$_name" on ${AppConfig.appName}: ${AppConfig.designShareUrl(_designId!)}',
      subject: _name,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_design == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Text(
            'No design selected',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.outlineVariant),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.width,
                  color: AppColors.surfaceContainerLowest,
                  child: _thumbnailUrl != null
                      ? Image.network(
                          _thumbnailUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.checkroom,
                            size: 80,
                            color: AppColors.outlineVariant,
                          ),
                        )
                      : Icon(Icons.checkroom, size: 80, color: AppColors.outlineVariant),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      _name,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.surfaceContainerLow,
                          backgroundImage: _authorAvatarUrl != null ? NetworkImage(_authorAvatarUrl!) : null,
                          child: _authorAvatarUrl == null
                              ? Text(
                                  _authorName.isNotEmpty ? _authorName[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _authorName,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.secondary),
                        ),
                      ],
                    ),
                    if (_category.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildTag(_category.toUpperCase()),
                          const SizedBox(width: 8),
                          _buildTag('$_likesCount LIKES'),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    DSButton(
                      label: AppLocalizations.of(context)!.templateUseDesign,
                      icon: Icons.bolt,
                      onPressed: _busy ? null : () => _openEditor(remix: false),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionBtn(
                            Icons.auto_fix_high,
                            'REMIX',
                            _busy ? null : () => _openEditor(remix: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionBtn(
                            _isSaved ? Icons.bookmark : Icons.bookmark_border,
                            _isSaved ? 'SAVED' : 'SAVE',
                            _isCommunityDesign && !_loadingState ? _toggleSave : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionBtn(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            _isLiked ? 'LIKED' : 'LIKE',
                            _isCommunityDesign && !_loadingState ? _toggleLike : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircleBtn(Icons.arrow_back, () => Navigator.of(context).pop()),
                Row(
                  children: [
                    _buildCircleBtn(Icons.share, _shareDesign),
                    const SizedBox(width: 12),
                    _buildCircleBtn(Icons.link, _copyShareLink),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest.withOpacity(0.2),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Icon(icon, color: AppColors.onSurface),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: AppColors.outlineVariant,
        ),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: label == 'LIKED'
                    ? AppColors.error
                    : (label == 'SAVED' ? AppColors.primary : AppColors.secondary),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
