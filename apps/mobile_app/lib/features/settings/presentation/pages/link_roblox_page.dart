import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../linked_accounts/data/linked_accounts_repository.dart';
import '../../../linked_accounts/data/roblox_oauth_service.dart';

class LinkRobloxPage extends ConsumerStatefulWidget {
  const LinkRobloxPage({super.key});

  @override
  ConsumerState<LinkRobloxPage> createState() => _LinkRobloxPageState();
}

class _LinkRobloxPageState extends ConsumerState<LinkRobloxPage> {
  bool _isLoading = true;
  bool _isLinked = false;
  bool _isSaving = false;
  String? _robloxUsername;

  @override
  void initState() {
    super.initState();
    _checkLinkStatus();
  }

  Future<void> _checkLinkStatus() async {
    try {
      final link = await ref.read(linkedAccountsRepositoryProvider).getActiveRobloxLink();
      if (!mounted) return;
      setState(() {
        _isLinked = link != null;
        _robloxUsername = link?['display_name'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Check linked_accounts error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connectWithOAuth() async {
    setState(() => _isSaving = true);
    try {
      final result = await ref.read(robloxOAuthServiceProvider).connect();
      if (!mounted) return;
      setState(() {
        _isLinked = true;
        _robloxUsername = result.displayName;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.robloxAccountLinkedSuccess(result.displayName)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF06693F),
        ),
      );
    } catch (e) {
      debugPrint('Roblox OAuth error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.connectionError(e.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _unlinkAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.unlinkAccount),
        content: Text(AppLocalizations.of(context)!.unlinkAccountConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.unlink, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(linkedAccountsRepositoryProvider).unlinkRobloxAccount();
      if (!mounted) return;
      setState(() {
        _isLinked = false;
        _robloxUsername = null;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.robloxAccountUnlinked), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorPrefix(e.toString())), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.onBackground),
          onPressed: () => Navigator.pop(context, _isLinked),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(color: Colors.black, borderRadius: BorderRadius.all(Radius.circular(6))),
              child: const Icon(Icons.pentagon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('Roblox', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _isLinked
              ? _buildLinkedView()
              : _buildLinkForm(),
    );
  }

  Widget _buildLinkedView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF06693F).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Color(0xFF06693F), size: 40),
                ),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.accountLinked, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.robloxAccountLinkedDesc,
                  style: TextStyle(color: AppColors.outlineVariant, fontSize: 14),
                ),
              ],
            ),
          ),
          SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF06693F).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.pentagon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${_robloxUsername ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppLocalizations.of(context)!.robloxAccount,
                        style: TextStyle(color: AppColors.outlineVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06693F).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.linkedStatus,
                    style: TextStyle(color: Color(0xFF06693F), fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.activeFeatures, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 16),
                _buildFeatureRow(Icons.verified_user, AppLocalizations.of(context)!.linkRobloxOAuthVerified, AppLocalizations.of(context)!.linkRobloxOAuthVerifiedDesc, true),
                const SizedBox(height: 12),
                _buildFeatureRow(Icons.cloud_upload, AppLocalizations.of(context)!.directUpload, AppLocalizations.of(context)!.directUploadDesc, true),
                const SizedBox(height: 12),
                _buildFeatureRow(Icons.checkroom, AppLocalizations.of(context)!.livePreview, AppLocalizations.of(context)!.livePreviewDesc, true),
              ],
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _isSaving ? null : _unlinkAccount,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error))
                    : Text(AppLocalizations.of(context)!.unlinkAccount, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.linkAccountHeader,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2.0, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.linkRobloxTitle,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.linkRobloxSubtitle,
            style: TextStyle(color: AppColors.outlineVariant, fontSize: 14, height: 1.5),
          ),
          SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildFeatureRow(Icons.verified_user, AppLocalizations.of(context)!.linkRobloxOAuthVerified, AppLocalizations.of(context)!.linkRobloxOAuthVerifiedDesc, false),
                SizedBox(height: 16),
                _buildFeatureRow(Icons.cloud_upload, AppLocalizations.of(context)!.directUpload, AppLocalizations.of(context)!.directUploadDesc, false),
                const SizedBox(height: 16),
                _buildFeatureRow(Icons.checkroom, AppLocalizations.of(context)!.livePreview, AppLocalizations.of(context)!.livePreviewDesc, false),
              ],
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _isSaving ? null : _connectWithOAuth,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.login, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            AppLocalizations.of(context)!.linkRobloxButton,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.linkTerms,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.outlineVariant, fontSize: 10, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle, bool active) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF06693F).withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: active ? const Color(0xFF06693F) : AppColors.primary, size: 20),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text(subtitle, style: TextStyle(color: AppColors.outlineVariant, fontSize: 11)),
            ],
          ),
        ),
        if (active) const Icon(Icons.check_circle, color: Color(0xFF06693F), size: 20),
      ],
    );
  }
}
