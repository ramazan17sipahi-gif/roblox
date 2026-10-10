import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:networking/src/supabase_client_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/app_config.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../routing/shell_tab_provider.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../editor/data/editor_route_params.dart';
import '../../../editor/data/project_repository.dart';
import '../../../explore/data/community_repository.dart';
import '../../data/library_refresh.dart';
import '../../../templates/data/catalog_likes_repository.dart';
import '../../../templates/data/template_item_model.dart';
import '../../../templates/presentation/widgets/catalog_like_button.dart';
import '../../../templates/presentation/widgets/worn_character_preview.dart';

enum _LibraryTab { all, drafts, private, published, saved, exports }

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> with LazyShellTabLoader {
  @override
  int get shellBranchIndex => 2;

  _LibraryTab _selectedTab = _LibraryTab.all;
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _savedDesigns = [];
  bool _loadingProjects = false;
  bool _loadingSaved = false;

  String _displayName = 'Creator';
  String _bio = '';
  String? _avatarUrl;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    ref.listenManual(libraryRefreshProvider, (prev, next) {
      if (prev != next) {
        _loadProjects();
        _loadSavedDesigns();
      }
    });
    ref.listenManual(shellBranchIndexProvider, (prev, next) {
      if (next == shellBranchIndex && prev != next) {
        _loadProjects();
        _loadSavedDesigns();
      }
    });
    CatalogLikesController.instance.addListener(_onLikesChanged);
  }

  void _onLikesChanged() {
    if (_selectedTab == _LibraryTab.saved) {
      _loadSavedDesigns();
    }
  }

  @override
  void dispose() {
    CatalogLikesController.instance.removeListener(_onLikesChanged);
    super.dispose();
  }

  @override
  void onLazyTabLoad() {
    CatalogLikesController.instance.ensureLoaded();
    _loadProfile();
    _loadProjects();
    _loadSavedDesigns();
  }

  Future<void> _loadProfile() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingProfile = false);
      return;
    }

    setState(() {
      _displayName = user.userMetadata?['full_name'] as String? ??
          user.email?.split('@').first ??
          'Creator';
    });

    try {
      final profile = await ref
          .read(supabaseClientProvider)
          .from('profiles')
          .select('display_name, bio, username, avatar_path, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null && mounted) {
        final avatarPath = profile['avatar_path'] as String?;
        final avatarUrlField = profile['avatar_url'] as String?;
        String? resolvedAvatar = avatarUrlField ?? user.userMetadata?['avatar_url'] as String?;
        if (resolvedAvatar == null && avatarPath != null && avatarPath.isNotEmpty) {
          if (avatarPath.startsWith('http')) {
            resolvedAvatar = avatarPath;
          }
        }
        setState(() {
          _displayName = profile['display_name'] as String? ??
              profile['username'] as String? ??
              _displayName;
          _bio = profile['bio'] as String? ?? '';
          _avatarUrl = resolvedAvatar;
          _loadingProfile = false;
        });
      } else if (mounted) {
        setState(() => _loadingProfile = false);
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadProjects() async {
    setState(() => _loadingProjects = true);
    final list = await ProjectRepository.listProjects();
    if (mounted) {
      setState(() {
        _projects = list;
        _loadingProjects = false;
      });
    }
  }

  Future<void> _loadSavedDesigns() async {
    setState(() => _loadingSaved = true);
    final list = await CommunityRepository.fetchSavedDesigns();
    if (mounted) {
      setState(() {
        _savedDesigns = list;
        _loadingSaved = false;
      });
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadProfile(), _loadProjects(), _loadSavedDesigns()]);
  }

  String _visibilityOf(Map<String, dynamic> p) =>
      (p['visibility'] as String?) ?? 'draft';

  List<Map<String, dynamic>> get _visibleItems {
    switch (_selectedTab) {
      case _LibraryTab.saved:
        return _savedDesigns;
      case _LibraryTab.drafts:
        return _projects.where((p) => _visibilityOf(p) == 'draft').toList();
      case _LibraryTab.private:
        return _projects.where((p) => _visibilityOf(p) == 'private').toList();
      case _LibraryTab.published:
        return _projects.where((p) => _visibilityOf(p) == 'public').toList();
      case _LibraryTab.exports:
        return _projects.where((p) => p['exported_at'] != null).toList();
      case _LibraryTab.all:
        return _projects;
    }
  }

  bool get _isLoading =>
      _selectedTab == _LibraryTab.saved ? _loadingSaved : _loadingProjects;

  ClothingTemplateType _templateFromDb(String? type) {
    return ClothingTemplateTypeX.fromString(type ?? '') ??
        ClothingTemplateType.blankShirt;
  }

  void _openProject(Map<String, dynamic> p) {
    context.push(
      '/editor',
      extra: EditorRouteParams(
        mode: EditorMode.classicClothingBlankStart,
        clothingTemplate: _templateFromDb(p['template_type'] as String?),
        projectId: p['id'] as String,
      ),
    );
  }

  (String, String) _emptyCopy(AppLocalizations l) {
    switch (_selectedTab) {
      case _LibraryTab.drafts:
        return (l.libraryNoDrafts, l.libraryNoDraftsDesc);
      case _LibraryTab.private:
        return (l.libraryNoPrivate, l.libraryNoPrivateDesc);
      case _LibraryTab.published:
        return (l.libraryNoPublished, l.libraryNoPublishedDesc);
      case _LibraryTab.saved:
        return (l.libraryNoSaved, l.libraryNoSavedDesc);
      case _LibraryTab.exports:
        return (l.libraryNoExports, l.libraryNoExportsDesc);
      case _LibraryTab.all:
        return (l.libraryNoAll, l.libraryNoAllDesc);
    }
  }

  String _tabLabel(AppLocalizations l, _LibraryTab tab) {
    switch (tab) {
      case _LibraryTab.all:
        return l.libraryTabAll;
      case _LibraryTab.drafts:
        return l.libraryTabDrafts;
      case _LibraryTab.private:
        return l.libraryTabPrivate;
      case _LibraryTab.published:
        return l.libraryTabPublished;
      case _LibraryTab.saved:
        return l.libraryTabSaved;
      case _LibraryTab.exports:
        return l.libraryTabExports;
    }
  }

  void _showEditProfile() {
    final nameController = TextEditingController(text: _displayName);
    final bioController = TextEditingController(text: _bio);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).profileEditProfile,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).profileDisplayName,
                hintText: AppLocalizations.of(context).profileEnterName,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bioController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).profileBio,
                hintText: AppLocalizations.of(context).profileBioHint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                final user = ref.read(supabaseClientProvider).auth.currentUser;
                if (user == null) return;

                final name = nameController.text.trim();
                final bio = bioController.text.trim();

                try {
                  await ref.read(supabaseClientProvider).from('profiles').upsert({
                    'id': user.id,
                    'display_name': name.isEmpty ? _displayName : name,
                    'bio': bio,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    setState(() {
                      _displayName = name.isEmpty ? _displayName : name;
                      _bio = bio;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context).profileUpdated),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Profile update error: $e');
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to update profile'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppColors.actionGradient,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context).commonSave,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nameController.dispose();
      bioController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(authSessionProvider);
    final User? user = sessionAsync.value?.user;
    final l = AppLocalizations.of(context);
    final items = _visibleItems;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            const BrandLogo(size: 32, borderRadius: 8),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppConfig.appNameShort,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: Icon(Icons.settings_outlined, color: AppColors.onBackground),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.primaryContainer, AppColors.primary],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 4),
                    color: AppColors.surfaceContainerLowest,
                  ),
                  child: _avatarUrl != null
                      ? ClipOval(
                          child: Image.network(
                            _avatarUrl!,
                            width: 104,
                            height: 104,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.person,
                              size: 48,
                              color: AppColors.outlineVariant,
                            ),
                          ),
                        )
                      : Icon(Icons.person, size: 48, color: AppColors.outlineVariant),
                ),
              ),
              const SizedBox(height: 16),
              if (_loadingProfile)
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                Text(
                  _displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (_bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _bio,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.outlineVariant),
                  ),
                ],
              ],
              const SizedBox(height: 4),
              if (user?.email != null)
                Text(
                  user!.email!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.outlineVariant),
                ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _showEditProfile,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  side: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.2), width: 2),
                ),
                child: Text(
                  AppLocalizations.of(context).profileEditProfile,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _LibraryTab.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final tab = _LibraryTab.values[i];
                    final selected = _selectedTab == tab;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTab = tab),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.surfaceContainerLowest : AppColors.surfaceContainerLow.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: selected
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)]
                              : null,
                        ),
                        child: Text(
                          _tabLabel(l, tab),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: selected ? AppColors.onBackground : AppColors.outlineVariant,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (items.isEmpty)
                _emptyState(l)
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (_selectedTab == _LibraryTab.saved) {
                      return _savedCard(item);
                    }
                    return _projectCard(item, l);
                  },
                ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(AppLocalizations l) {
    final copy = _emptyCopy(l);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 12),
      child: Column(
        children: [
          Icon(Icons.inbox, size: 48, color: AppColors.outlineVariant.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          Text(
            copy.$1,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            copy.$2,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.outlineVariant, fontWeight: FontWeight.w600, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _savedCard(Map<String, dynamic> design) {
    final isCatalog = design['_source'] == 'catalog';
    final name = design['name'] as String? ?? 'Design';
    final templateId = (design['id'] ?? '').toString();
    return ListenableBuilder(
      listenable: CatalogLikesController.instance,
      builder: (context, _) {
        final likes = CatalogLikesController.instance;
        final liked = isCatalog && likes.isLiked(templateId);
        final count = isCatalog
            ? likes.countFor(
                templateId,
                CatalogLikesRepository.parseCount(design['likes_count']),
              )
            : CatalogLikesRepository.parseCount(design['likes_count']);
        return GestureDetector(
          onTap: () {
            if (isCatalog) {
              context.push(
                '/template-preview',
                extra: TemplateItemModel.fromClothingTemplateRow(design),
              );
              return;
            }
            context.push('/design_detail', extra: design);
          },
          child: _cardShell(
            row: design,
            name: name,
            catalogPreview: isCatalog,
            likeId: isCatalog ? templateId : null,
            liked: liked,
            likeCount: count,
          ),
        );
      },
    );
  }

  Widget _projectCard(Map<String, dynamic> p, AppLocalizations l) {
    final name = p['name'] as String? ?? 'Design';
    final visibility = _visibilityOf(p);
    final badge = switch (visibility) {
      'public' => (l.libraryBadgePublished, const Color(0xFF2A9D8F)),
      'private' => (l.libraryBadgePrivate, const Color(0xFF6C757D)),
      _ => (l.libraryBadgeDraft, const Color(0xFF00B4D8)),
    };

    return GestureDetector(
      onTap: () => _openProject(p),
      child: _cardShell(
        row: p,
        name: name,
        badge: badge.$1,
        badgeColor: badge.$2,
      ),
    );
  }

  Widget _cardShell({
    required Map<String, dynamic> row,
    required String name,
    bool catalogPreview = false,
    String? badge,
    Color? badgeColor,
    String? likeId,
    bool liked = false,
    int likeCount = 0,
  }) {
    final hasPreview = catalogPreview ||
        WornCharacterPreview.httpUrl(row['shirt_texture_url']) != null ||
        WornCharacterPreview.httpUrl(row['pants_texture_url']) != null ||
        (row['thumbnail_url'] as String?)?.isNotEmpty == true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: hasPreview
                        ? (catalogPreview
                            ? WornCharacterPreview.fromTemplateRow(row)
                            : WornCharacterPreview.fromLibraryRow(row))
                        : _projectPlaceholder(),
                  ),
                ),
                if (badge != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? AppColors.primary).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                if (likeId != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CatalogLikeButton(
                      liked: liked,
                      onTap: () => handleCatalogLikeTap(
                        context: context,
                        templateId: likeId,
                        knownCount: likeCount,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                if (likeId != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$likeCount',
                    style: const TextStyle(
                      color: Color(0xFF71717A),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _projectPlaceholder() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(Icons.checkroom, color: AppColors.primary, size: 36),
      ),
    );
  }
}
