import 'dart:math';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../config/app_config.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Referral page — users generate a unique code, share it,
/// earn credits when friends sign up using their code.
class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  String? _referralCode;
  int _usesCount = 0;
  int _credits = 0;
  bool _isLoading = true;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _loadError = false;
    });

    try {
      // Get or create referral code
      final existing = await Supabase.instance.client
          .from('referral_codes')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing != null) {
        setState(() {
          _referralCode = existing['code'] as String;
          _usesCount = existing['uses_count'] as int? ?? 0;
        });
      } else {
        // Generate new code
        final code = _generateCode(user.id);
        await Supabase.instance.client.from('referral_codes').insert({
          'user_id': user.id,
          'code': code,
        });
        setState(() => _referralCode = code);
      }

      // Get credits
      _credits = (user.userMetadata?['credits'] as int?) ?? 0;
    } catch (e) {
      debugPrint('[referral_page] load error: $e');
      setState(() {
        _referralCode = null;
        _usesCount = 0;
        _credits = 0;
        _loadError = true;
      });
    }

    setState(() => _isLoading = false);
  }

  String _generateCode(String seed) {
    final chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random(seed.hashCode);
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Invite & Earn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _loadError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppColors.outlineVariant),
                      SizedBox(height: 16),
                      Text(
                        'Could not load referral data',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.outlineVariant),
                      ),
                      SizedBox(height: 16),
                      TextButton(
                        onPressed: _loadReferralData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Hero card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF6A1A), Color(0xFFFF3D00)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFFF6A1A).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.card_giftcard, size: 48, color: Colors.white),
                        const SizedBox(height: 12),
                        const Text('Give 3, Get 5', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 6),
                        Text(
                          'Your friend gets 3 credits, you get 5 credits\nfor every friend who signs up!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Referral code card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        Text('Your Referral Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.outlineVariant)),
                        SizedBox(height: 10),
                        // Code display
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _referralCode ?? '--------',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4, color: AppColors.onSurface),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: _referralCode ?? ''));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(AppLocalizations.of(context)!.referralCodeCopied), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.copy, size: 18, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Share button
                        GestureDetector(
                          onTap: () {
                            Share.share(
                              'Join ${AppConfig.appNameShort} and get 3 FREE credits! Use my code: ${_referralCode ?? ''}\n\nDownload: ${AppConfig.webBaseUrl}/invite/${_referralCode ?? ''}',
                              subject: 'Join ${AppConfig.appNameShort} — Free Credits!',
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: AppColors.actionGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.share, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text('Share Invite Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats
                  Row(
                    children: [
                      Expanded(child: _statCard(Icons.people, '$_usesCount', 'Friends Invited', const Color(0xFF2196F3))),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard(Icons.stars, '$_credits', 'Credits Earned', const Color(0xFFFF6A1A))),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // How it works
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('How It Works', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 14),
                        _stepRow(1, 'Share your unique code with friends', Icons.send),
                        _stepRow(2, 'Friend signs up with your code', Icons.person_add),
                        _stepRow(3, 'Both of you earn free credits!', Icons.celebration),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.outlineVariant.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _stepRow(int step, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text('$step', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: AppColors.onSurface))),
          Icon(icon, size: 18, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
        ],
      ),
    );
  }
}
