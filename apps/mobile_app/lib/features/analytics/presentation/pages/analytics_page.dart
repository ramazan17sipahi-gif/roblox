import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// Creator analytics — project and community stats from Supabase.
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int _totalProjects = 0;
  int _publicProjects = 0;
  int _publishedDesigns = 0;
  int _totalLikes = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final projects = await Supabase.instance.client
          .from('user_projects')
          .select('visibility')
          .eq('user_id', userId);

      final published = await Supabase.instance.client
          .from('published_designs')
          .select('likes_count')
          .eq('user_id', userId);

      final projectRows = List<Map<String, dynamic>>.from(projects);
      final publishedRows = List<Map<String, dynamic>>.from(published);

      if (mounted) {
        setState(() {
          _totalProjects = projectRows.length;
          _publicProjects = projectRows.where((p) => p['visibility'] == 'public').length;
          _publishedDesigns = publishedRows.length;
          _totalLikes = publishedRows.fold<int>(
            0,
            (sum, row) => sum + ((row['likes_count'] as int?) ?? 0),
          );
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[analytics_page] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppLocalizations.of(context)!.analyticsTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _statCard('Total Projects', '$_totalProjects', Icons.folder_outlined, const Color(0xFF2196F3)),
                  const SizedBox(height: 12),
                  _statCard('Public Projects', '$_publicProjects', Icons.public, const Color(0xFF4CAF50)),
                  const SizedBox(height: 12),
                  _statCard('Published Designs', '$_publishedDesigns', Icons.storefront_outlined, const Color(0xFFFF793A)),
                  const SizedBox(height: 12),
                  _statCard('Total Likes Received', '$_totalLikes', Icons.favorite_outline, const Color(0xFFE91E63)),
                  const SizedBox(height: 24),
                  Text(
                    'Detailed charts and revenue analytics will arrive in a future update.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.outlineVariant.withValues(alpha: 0.8), fontSize: 13),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: AppColors.outlineVariant, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
