import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../l10n/generated/app_localizations.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _items = [];
          _loading = false;
        });
        return;
      }
      final res = await Supabase.instance.client
          .from('notification_records')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[notifications] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await Supabase.instance.client
          .from('notification_records')
          .update({'is_read': true})
          .eq('id', id);
    } catch (e) {
      debugPrint('[notifications] mark read: $e');
    }
  }

  Future<void> _clearAll() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('notification_records')
          .delete()
          .eq('user_id', userId);
      setState(() => _items = []);
    } catch (e) {
      debugPrint('[notifications] clear: $e');
    }
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'generation_failed':
        return Icons.error_outline;
      case 'export_ready':
        return Icons.download_done;
      case 'publish_completed':
        return Icons.public;
      case 'insufficient_credits':
        return Icons.monetization_on_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'generation_failed':
        return AppColors.error;
      case 'export_ready':
      case 'publish_completed':
        return const Color(0xFF2E7D32);
      case 'insufficient_credits':
        return const Color(0xFFE65100);
      default:
        return AppColors.primary;
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.notificationsTitle,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: Text(
                AppLocalizations.of(context)!.notificationsClearAll,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: AppColors.outlineVariant.withOpacity(0.2),
                      ),
                      SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.notificationsAllCaughtUp,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context)!.notificationsNoNew,
                        style: TextStyle(color: AppColors.outlineVariant),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final n = _items[index];
                      final type = n['notification_type'] as String?;
                      final isRead = n['is_read'] == true;
                      return Dismissible(
                        key: ValueKey(n['id']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: AppColors.error.withOpacity(0.15),
                          child: const Icon(Icons.delete, color: AppColors.error),
                        ),
                        onDismissed: (_) async {
                          final id = n['id'] as String;
                          await Supabase.instance.client
                              .from('notification_records')
                              .delete()
                              .eq('id', id);
                          setState(() => _items.removeAt(index));
                        },
                        child: ListTile(
                          onTap: () {
                            if (!isRead) _markRead(n['id'] as String);
                            setState(() => _items[index]['is_read'] = true);
                          },
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _colorFor(type).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_iconFor(type), color: _colorFor(type), size: 20),
                          ),
                          title: Text(
                            n['title'] as String? ?? '',
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            n['body'] as String? ?? '',
                            style: TextStyle(fontSize: 12, color: AppColors.outlineVariant),
                          ),
                          trailing: Text(
                            _timeAgo(n['created_at'] as String?),
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.outlineVariant.withOpacity(0.7),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
