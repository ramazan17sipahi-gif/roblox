import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:networking/networking.dart';

final exportPublishRepositoryProvider = Provider<ExportPublishRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ExportPublishRepository(supabase);
});

class ExportPublishRepository {
  final SupabaseClient _supabase;

  ExportPublishRepository(this._supabase);

  Future<void> publishDesign(String designId, String visibility) async {
    final response = await _supabase.functions.invoke(
      'publish-design',
      body: {'designId': designId, 'visibility': visibility},
    );

    if (response.status != 200) {
      final message = response.data['error'] ?? 'Publish failed';
      throw Exception(message);
    }
  }

  Future<void> createExportJob(String designId, String exportTarget, {String? designVersionId}) async {
    final response = await _supabase.functions.invoke(
      'create-export-job',
      body: {
        'designId': designId,
        'designVersionId': designVersionId ?? designId, // fallback until version tracking is wired
        'exportTarget': exportTarget,
      },
    );

    if (response.status != 200) {
      final message = response.data['error'] ?? 'Export failed';
      throw Exception(message);
    }
  }

  /// Reserve credits before an export/publish operation.
  /// Returns {reservationId, newBalance, expiresAt} on success.
  /// Throws on insufficient credits (402) or other errors.
  Future<Map<String, dynamic>> reserveCredits({
    required int amount,
    required String reason,
    required String idempotencyKey,
  }) async {
    final response = await _supabase.functions.invoke(
      'consume-credits',
      body: {
        'action': 'reserve',
        'amount': amount,
        'reason': reason,
        'idempotencyKey': idempotencyKey,
      },
    );

    if (response.status == 402) {
      throw InsufficientCreditsException(amount);
    }
    if (response.status != 200) {
      final message = response.data['error'] ?? 'Credit reservation failed';
      throw Exception(message);
    }
    return Map<String, dynamic>.from(response.data);
  }

  /// Commit a previously reserved credit charge.
  Future<void> commitCredits(String reservationId) async {
    final response = await _supabase.functions.invoke(
      'consume-credits',
      body: {
        'action': 'commit',
        'reservationId': reservationId,
      },
    );

    if (response.status != 200) {
      throw Exception('Credit commit failed: ${response.data}');
    }
  }

  /// Rollback a previously reserved credit charge (refund).
  Future<void> rollbackCredits(String reservationId) async {
    final response = await _supabase.functions.invoke(
      'consume-credits',
      body: {
        'action': 'rollback',
        'reservationId': reservationId,
      },
    );

    if (response.status != 200) {
      throw Exception('Credit rollback failed: ${response.data}');
    }
  }
}

/// Thrown when user doesn't have enough credits for the operation.
class InsufficientCreditsException implements Exception {
  final int required;
  InsufficientCreditsException(this.required);

  @override
  String toString() => 'Insufficient credits. Required: $required';
}
