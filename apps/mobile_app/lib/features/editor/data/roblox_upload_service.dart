import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for uploading assets to Roblox via Open Cloud API.
/// Supports Classic Clothing (Shirt/Pants/T-Shirt) and UGC assets.
class RobloxUploadService {
  static const _baseUrl = 'https://apis.roblox.com';

  /// Upload a clothing texture (PNG) to Roblox.
  /// Returns the asset ID on success.
  static Future<RobloxUploadResult> uploadClothing({
    required String apiKey,
    required Uint8List pngBytes,
    required String name,
    required String description,
    required RobloxAssetType assetType,
    required int creatorId,
    bool isGroup = false,
  }) async {
    try {
      final creatorType = isGroup ? 'Group' : 'User';
      
      // Step 1: Create the asset
      final createResponse = await http.post(
        Uri.parse('$_baseUrl/assets/v1/assets'),
        headers: {
          'x-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'assetType': assetType.robloxName,
          'displayName': name,
          'description': description,
          'creationContext': {
            'creator': {
              'userId': isGroup ? null : creatorId.toString(),
              'groupId': isGroup ? creatorId.toString() : null,
            },
          },
        }),
      );

      if (createResponse.statusCode != 200 && createResponse.statusCode != 201) {
        return RobloxUploadResult.error(
          'Failed to create asset: ${createResponse.statusCode} - ${createResponse.body}',
        );
      }

      final createData = jsonDecode(createResponse.body);
      final operationPath = createData['path'] as String?;
      
      if (operationPath == null) {
        return RobloxUploadResult.error('No operation path returned');
      }

      // Step 2: Upload the file content
      final uploadResponse = await http.post(
        Uri.parse('$_baseUrl/$operationPath'),
        headers: {
          'x-api-key': apiKey,
          'Content-Type': 'image/png',
        },
        body: pngBytes,
      );

      if (uploadResponse.statusCode != 200 && uploadResponse.statusCode != 201) {
        return RobloxUploadResult.error(
          'Failed to upload content: ${uploadResponse.statusCode} - ${uploadResponse.body}',
        );
      }

      final uploadData = jsonDecode(uploadResponse.body);
      final assetId = uploadData['assetId']?.toString() ?? uploadData['response']?['assetId']?.toString();
      
      return RobloxUploadResult.success(
        assetId: assetId ?? 'pending',
        assetUrl: assetId != null ? 'https://www.roblox.com/catalog/$assetId' : null,
      );
    } catch (e) {
      return RobloxUploadResult.error('Upload error: $e');
    }
  }

  /// Save/retrieve Roblox API key from Supabase user metadata.
  static Future<void> saveApiKey(String apiKey) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {'roblox_api_key': apiKey}),
    );
  }

  static String? getApiKey() {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.userMetadata?['roblox_api_key'] as String?;
  }

  /// List user's uploaded assets on Roblox.
  static Future<List<Map<String, dynamic>>> listUploadedAssets(String apiKey, int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/assets/v1/assets?creator=User/$userId'),
        headers: {'x-api-key': apiKey},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['assets'] ?? []);
      }
    } catch (e) {
      debugPrint('List assets error: $e');
    }
    return [];
  }
}

/// Roblox asset types for clothing/accessories.
enum RobloxAssetType {
  shirt('Shirt'),
  pants('Pants'),
  tShirt('TShirt'),
  decal('Decal'),
  audio('Audio'),
  model('Model');

  final String robloxName;
  const RobloxAssetType(this.robloxName);
}

/// Result of a Roblox upload operation.
class RobloxUploadResult {
  final bool isSuccess;
  final String? assetId;
  final String? assetUrl;
  final String? errorMessage;

  RobloxUploadResult._({
    required this.isSuccess,
    this.assetId,
    this.assetUrl,
    this.errorMessage,
  });

  factory RobloxUploadResult.success({required String assetId, String? assetUrl}) {
    return RobloxUploadResult._(isSuccess: true, assetId: assetId, assetUrl: assetUrl);
  }

  factory RobloxUploadResult.error(String message) {
    return RobloxUploadResult._(isSuccess: false, errorMessage: message);
  }
}
