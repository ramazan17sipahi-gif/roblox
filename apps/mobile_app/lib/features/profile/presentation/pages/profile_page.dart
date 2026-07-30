import 'package:design_system/design_system.dart';

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';



import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:networking/src/supabase_client_provider.dart';



import '../../../editor/data/editor_route_params.dart';

import '../../../editor/data/project_repository.dart';

import '../../../explore/data/community_repository.dart';

import '../../../../config/app_config.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../../l10n/generated/app_localizations.dart';

import '../../../../routing/shell_tab_provider.dart';



class ProfilePage extends ConsumerStatefulWidget {

  const ProfilePage({super.key});



  @override

  ConsumerState<ProfilePage> createState() => _ProfilePageState();

}



class _ProfilePageState extends ConsumerState<ProfilePage> with LazyShellTabLoader {

  @override

  int get shellBranchIndex => 2;



  int _selectedTab = 0;

  final _tabs = ['Library', 'Public', 'Drafts', 'Saved'];

  List<Map<String, dynamic>> _projects = [];

  List<Map<String, dynamic>> _savedDesigns = [];

  bool _loadingProjects = false;

  bool _loadingSaved = false;



  String _displayName = 'Creator';

  String _bio = '';

  String? _avatarUrl;

  bool _loadingProfile = true;



  @override

  void onLazyTabLoad() {

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



  List<Map<String, dynamic>> get _filteredProjects {

    switch (_selectedTab) {

      case 1:

        return _projects.where((p) => p['visibility'] == 'public').toList();

      case 2:

        return _projects.where((p) => p['visibility'] == 'draft').toList();

      default:

        return _projects

            .where((p) => p['visibility'] == 'private' || p['visibility'] == 'public')

            .toList();

    }

  }



  ClothingTemplateType _templateFromDb(String? type) {

    return ClothingTemplateTypeX.fromString(type ?? '') ??

        ClothingTemplateType.blankShirt;

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

          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),

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

                      SnackBar(

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



    return Scaffold(

      backgroundColor: AppColors.background,

      appBar: AppBar(

        backgroundColor: Colors.transparent,

        elevation: 0,

        centerTitle: false,

        title: Row(
          children: [
            const BrandLogo(size: 32, borderRadius: 8),
            SizedBox(width: 8),
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

          SizedBox(width: 8),

        ],

      ),

      body: SingleChildScrollView(

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

            SizedBox(height: 16),

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

            SizedBox(height: 4),

            if (user?.email != null)

              Text(

                user!.email!,

                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.outlineVariant),

              ),

            SizedBox(height: 24),

            OutlinedButton(

              onPressed: _showEditProfile,

              style: OutlinedButton.styleFrom(

                minimumSize: const Size.fromHeight(48),

                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),

                side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.2), width: 2),

              ),

              child: Text(

                AppLocalizations.of(context).profileEditProfile,

                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 14),

              ),

            ),

            SizedBox(height: 32),

            Container(

              padding: const EdgeInsets.all(6),

              decoration: BoxDecoration(

                color: AppColors.surfaceContainerLow.withOpacity(0.2),

                borderRadius: BorderRadius.circular(30),

              ),

              child: Row(

                children: List.generate(

                  _tabs.length,

                  (i) => Expanded(

                    child: GestureDetector(

                      onTap: () => setState(() => _selectedTab = i),

                      child: AnimatedContainer(

                        duration: const Duration(milliseconds: 200),

                        padding: const EdgeInsets.symmetric(vertical: 10),

                        decoration: BoxDecoration(

                          color: _selectedTab == i ? AppColors.surfaceContainerLowest : Colors.transparent,

                          borderRadius: BorderRadius.circular(20),

                          boxShadow: _selectedTab == i

                              ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]

                              : [],

                        ),

                        child: Center(

                          child: Text(

                            _tabs[i],

                            style: TextStyle(

                              fontSize: 12,

                              fontWeight: FontWeight.w800,

                              color: _selectedTab == i ? AppColors.onBackground : AppColors.outlineVariant,

                            ),

                          ),

                        ),

                      ),

                    ),

                  ),

                ),

              ),

            ),

            SizedBox(height: 24),

            if (_selectedTab == 3 ? _loadingSaved : _loadingProjects)

              const Padding(

                padding: EdgeInsets.symmetric(vertical: 48),

                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),

              )

            else if (_selectedTab == 3

                ? _savedDesigns.isEmpty

                : _filteredProjects.isEmpty)

              Container(

                padding: const EdgeInsets.symmetric(vertical: 48),

                child: Column(

                  children: [

                    Icon(Icons.inbox, size: 48, color: AppColors.outlineVariant.withOpacity(0.2)),

                    SizedBox(height: 12),

                    Text(

                      AppLocalizations.of(context).profileNoDesigns,

                      style: TextStyle(color: AppColors.outlineVariant, fontWeight: FontWeight.w600),

                    ),

                  ],

                ),

              )

            else

              GridView.builder(

                shrinkWrap: true,

                physics: const NeverScrollableScrollPhysics(),

                itemCount: _selectedTab == 3 ? _savedDesigns.length : _filteredProjects.length,

                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(

                  crossAxisCount: 2,

                  crossAxisSpacing: 14,

                  mainAxisSpacing: 14,

                  childAspectRatio: 0.82,

                ),

                itemBuilder: (context, index) {

                  if (_selectedTab == 3) {

                    final design = _savedDesigns[index];

                    final thumb = design['thumbnail_url'] as String?;

                    final name = design['name'] as String? ?? 'Design';

                    return GestureDetector(

                      onTap: () => context.push('/design_detail', extra: design),

                      child: Container(

                        decoration: BoxDecoration(

                          color: AppColors.surface,

                          borderRadius: BorderRadius.circular(16),

                          boxShadow: [

                            BoxShadow(

                              color: Colors.black.withOpacity(0.06),

                              blurRadius: 8,

                              offset: const Offset(0, 2),

                            ),

                          ],

                        ),

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.stretch,

                          children: [

                            Expanded(

                              child: ClipRRect(

                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),

                                child: thumb != null

                                    ? Image.network(

                                        thumb,

                                        fit: BoxFit.cover,

                                        errorBuilder: (_, __, ___) => _projectPlaceholder(),

                                      )

                                    : _projectPlaceholder(),

                              ),

                            ),

                            Padding(

                              padding: const EdgeInsets.all(10),

                              child: Text(

                                name,

                                maxLines: 1,

                                overflow: TextOverflow.ellipsis,

                                style: const TextStyle(

                                  fontSize: 12,

                                  fontWeight: FontWeight.w700,

                                ),

                              ),

                            ),

                          ],

                        ),

                      ),

                    );

                  }

                  final p = _filteredProjects[index];

                  final thumb = p['thumbnail_url'] as String?;

                  final name = p['name'] as String? ?? 'Design';

                  return GestureDetector(

                    onTap: () {

                      context.push(

                        '/editor',

                        extra: EditorRouteParams(

                          mode: EditorMode.classicClothingBlankStart,

                          clothingTemplate: _templateFromDb(p['template_type'] as String?),

                          projectId: p['id'] as String,

                        ),

                      );

                    },

                    child: Container(

                      decoration: BoxDecoration(

                        color: AppColors.surface,

                        borderRadius: BorderRadius.circular(16),

                        boxShadow: [

                          BoxShadow(

                            color: Colors.black.withOpacity(0.08),

                            blurRadius: 10,

                            offset: const Offset(0, 4),

                          ),

                        ],

                      ),

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.stretch,

                        children: [

                          Expanded(

                            child: ClipRRect(

                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),

                              child: thumb != null

                                  ? Image.network(

                                      thumb,

                                      fit: BoxFit.cover,

                                      errorBuilder: (_, __, ___) => _projectPlaceholder(),

                                    )

                                  : _projectPlaceholder(),

                            ),

                          ),

                          Padding(

                            padding: const EdgeInsets.all(10),

                            child: Text(

                              name,

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,

                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),

                            ),

                          ),

                        ],

                      ),

                    ),

                  );

                },

              ),

            const SizedBox(height: 120),

          ],

        ),

      ),

      floatingActionButton: Padding(

        padding: const EdgeInsets.only(bottom: 90.0),

        child: GestureDetector(

          onTap: () => context.push('/editor'),

          child: Container(

            width: 56,

            height: 56,

            decoration: BoxDecoration(

              gradient: AppColors.actionGradient,

              shape: BoxShape.circle,

              boxShadow: [

                BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 12)),

              ],

            ),

            child: const Icon(Icons.add, color: Colors.white, size: 28),

          ),

        ),

      ),

    );

  }



  Widget _projectPlaceholder() {

    return Container(

      color: AppColors.primary.withOpacity(0.08),

      child: const Center(

        child: Icon(Icons.checkroom, color: AppColors.primary, size: 36),

      ),

    );

  }

}


