import 'package:flutter/foundation.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:billing/billing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../config/app_config.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../data/export_publish_repository.dart';
import '../../data/project_repository.dart';
import '../../../explore/data/community_repository.dart';
import '../../../linked_accounts/data/linked_accounts_repository.dart';

class PublishSheet extends ConsumerStatefulWidget {
  final String designId; // Use designId instead of just name
  final String designName;

  const PublishSheet({super.key, required this.designId, this.designName = 'New Design'});

  @override
  ConsumerState<PublishSheet> createState() => _PublishSheetState();
}

class _PublishSheetState extends ConsumerState<PublishSheet> {

  void _showLoadingThenSuccess(BuildContext context, String title, String message, {Duration? duration, VoidCallback? onDone}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future.delayed(duration ?? const Duration(milliseconds: 1500), () {
          if (ctx.mounted) Navigator.pop(ctx);
          if (context.mounted) {
            Navigator.pop(context);
            onDone?.call();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
          }
        });
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 16),
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 24),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.onBackground)),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context)!.publishPleaseWait, style: TextStyle(color: AppColors.outlineVariant, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  void _showErrorWithRedirect(String title, String message, IconData icon, Color color, {String? actionLabel, VoidCallback? onAction}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.outlineVariant, height: 1.4)),
            const SizedBox(height: 20),
            if (onAction != null)
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // close publish sheet
                  onAction();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                  child: Center(child: Text(actionLabel ?? 'Continue', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                ),
              ),
            if (onAction != null) const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  color: onAction != null ? Colors.transparent : color,
                  borderRadius: BorderRadius.circular(20),
                  border: onAction != null ? Border.all(color: color.withOpacity(0.2)) : null,
                ),
                child: Center(child: Text(onAction != null ? 'Cancel' : 'OK', style: TextStyle(color: onAction != null ? color : Colors.white, fontWeight: FontWeight.w700))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(message, style: TextStyle(color: AppColors.outlineVariant, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.commonCancel)),
          TextButton(onPressed: () { Navigator.pop(ctx); onConfirm(); },
            child: Text(AppLocalizations.of(context)!.publishConfirm, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 28),
                  width: 48, height: 4,
                  decoration: BoxDecoration(color: AppColors.surfaceContainerLow.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)!.publishFinishTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.onBackground)),
                    const SizedBox(height: 4),
                    Text(AppLocalizations.of(context)!.publishFinishSubtitle, style: TextStyle(fontSize: 13, color: AppColors.outlineVariant)),
                    const SizedBox(height: 28),

                    // 1. Publish to marketplace (Pro-gated)
                    _buildPrimaryAction(
                      icon: Icons.storefront,
                      label: AppLocalizations.of(context)!.publishToMarketplace,
                      subtitle: AppLocalizations.of(context)!.publishToMarketplaceSub,
                      onTap: () {
                        // Pro gate: marketplace publish requires entitlement
                        final canAccess = ref.read(canAccessProProvider);
                        if (!canAccess) {
                          debugPrint('[pro_gate_blocked] feature=marketplace_publish screen=PublishSheet');
                          _showErrorWithRedirect(
                            AppLocalizations.of(context)!.publishProRequired,
                            AppLocalizations.of(context)!.publishProRequiredDesc,
                            Icons.workspace_premium,
                            const Color(0xFFFF6B35),
                            actionLabel: AppLocalizations.of(context)!.publishUpgradeToPro,
                            onAction: () => context.push('/paywall'),
                          );
                          return;
                        }
                        _showConfirmDialog(
                          '${AppLocalizations.of(context)!.publishToMarketplace}?',
                          AppLocalizations.of(context)!.publishToMarketplaceConfirm,
                          () async {
                            Navigator.pop(context); // Close sheet
                            try {
                              final meta = await Supabase.instance.client
                                  .from('user_projects')
                                  .select('template_type, thumbnail_url')
                                  .eq('id', widget.designId)
                                  .maybeSingle();

                              final ok = await CommunityRepository.publishProject(
                                projectId: widget.designId,
                                name: widget.designName,
                                templateType: meta?['template_type'] as String? ?? 'classic_shirt',
                                thumbnailUrl: meta?['thumbnail_url'] as String?,
                              );

                              if (!ok) throw Exception('Publish failed');

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✅ ${AppLocalizations.of(context)!.editorPublishSuccess}'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString()),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // 2. Upload to Roblox
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: ref.watch(linkedAccountsRepositoryProvider).streamLinkedAccounts(),
                      builder: (context, snapshot) {
                        final linkedAccounts = snapshot.data ?? [];
                        final hasRoblox = linkedAccounts.any((acc) => acc['platform_code'] == 'roblox');

                        return _buildAction(Icons.cloud_upload, AppLocalizations.of(context)!.publishUploadToRoblox, AppLocalizations.of(context)!.publishUploadToRobloxSub, () async {
                          if (!hasRoblox) {
                            _showErrorWithRedirect(
                              AppLocalizations.of(context)!.publishAccountNotLinked,
                              AppLocalizations.of(context)!.publishAccountNotLinkedDesc,
                              Icons.link_off,
                              const Color(0xFF448AFF),
                              actionLabel: AppLocalizations.of(context)!.publishLinkAccount,
                              onAction: () => context.push('/link-roblox'),
                            );
                            return;
                          }

                          final canAccess = ref.read(canAccessProProvider);
                          if (!canAccess) {
                            _showErrorWithRedirect(
                              AppLocalizations.of(context)!.publishProRequired,
                              AppLocalizations.of(context)!.publishProRequiredDesc,
                              Icons.workspace_premium,
                              const Color(0xFFFF6B35),
                              actionLabel: AppLocalizations.of(context)!.publishUpgradeToPro,
                              onAction: () => context.push('/paywall'),
                            );
                            return;
                          }

                          Navigator.pop(context);
                          try {
                            final repo = ref.read(exportPublishRepositoryProvider);
                            await repo.createExportJob(widget.designId, 'upload_to_roblox');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ ${AppLocalizations.of(context)!.publishExportJobCreated}'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        });
                      }
                    ),
                    const SizedBox(height: 12),

                    // ── Copy Link ──
                    _buildAction(Icons.link, AppLocalizations.of(context)!.publishCopyLink, AppLocalizations.of(context)!.publishCopyLinkSub, () async {
                      final link = AppConfig.designShareUrl(widget.designId);
                      await Clipboard.setData(ClipboardData(text: link));
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('✅ ${AppLocalizations.of(context)!.publishLinkCopied}'),
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    }),
                    const SizedBox(height: 12),

                    // ── Download ──
                    _buildAction(Icons.download, AppLocalizations.of(context)!.publishDownload, AppLocalizations.of(context)!.publishDownloadSub, () async {
                      Navigator.pop(context);
                      try {
                        await ref.read(exportPublishRepositoryProvider).createExportJob(widget.designId, 'download_package');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('✅ ${AppLocalizations.of(context)!.publishDownloadSuccess}'),
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      }
                    }),
                    const SizedBox(height: 12),

                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, color: AppColors.primary.withOpacity(0.2), size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.publishExportNote,
                        style: TextStyle(fontSize: 10, color: AppColors.outlineVariant, fontStyle: FontStyle.italic, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 16 : 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryAction({required IconData icon, required String label, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppColors.actionGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFFFF6A1A).withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(IconData icon, String label, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, shape: BoxShape.circle, border: Border.all(color: AppColors.surfaceContainerLow.withOpacity(0.2))),
              child: Icon(icon, color: AppColors.onBackground),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: AppColors.onBackground, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: AppColors.outlineVariant, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.outlineVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLow.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Icon(icon, color: AppColors.onBackground, size: 22),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.onBackground)),
          ],
        ),
      ),
    );
  }
}
