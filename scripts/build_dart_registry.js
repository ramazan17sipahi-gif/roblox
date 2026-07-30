/**
 * Reads generated_assets.json and outputs a Dart file for the Flutter app.
 */
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('generated_assets.json', 'utf8'));

function buildEntries(category) {
  const entries = [];
  for (const [id, asset] of Object.entries(data[category])) {
    if (asset.status !== 'SUCCEEDED') continue;
    const thumb = asset.thumbnail_url || '';
    const glb = (asset.model_urls && asset.model_urls.glb) || '';
    const fbx = (asset.model_urls && asset.model_urls.fbx) || '';
    entries.push(`    '${id}': MeshyAsset(\n      thumbnailUrl: '${thumb}',\n      glbUrl: '${glb}',\n      fbxUrl: '${fbx}',\n    ),`);
  }
  return entries.join('\n');
}

const dart = `/// Auto-generated Meshy 3D asset registry.
/// Generated: ${new Date().toISOString()}
/// Templates: ${Object.values(data.templates).filter(v => v.status === 'SUCCEEDED').length}
/// Accessories: ${Object.values(data.accessories).filter(v => v.status === 'SUCCEEDED').length}
/// Items3D: ${Object.values(data.items3d).filter(v => v.status === 'SUCCEEDED').length}

class MeshyAsset {
  final String thumbnailUrl;
  final String glbUrl;
  final String fbxUrl;
  const MeshyAsset({required this.thumbnailUrl, this.glbUrl = '', this.fbxUrl = ''});
}

class MeshyAssetRegistry {
  static const Map<String, MeshyAsset> templates = {
${buildEntries('templates')}
  };

  static const Map<String, MeshyAsset> accessories = {
${buildEntries('accessories')}
  };

  static const Map<String, MeshyAsset> items3d = {
${buildEntries('items3d')}
  };

  static MeshyAsset? find(String id) {
    return templates[id] ?? accessories[id] ?? items3d[id];
  }

  static String? thumbnailFor(String id) => find(id)?.thumbnailUrl;

  static String? glbFor(String id) {
    final asset = find(id);
    return (asset != null && asset.glbUrl.isNotEmpty) ? asset.glbUrl : null;
  }
}
`;

const outPath = 'apps/mobile_app/lib/features/editor/data/meshy_asset_registry.dart';
fs.writeFileSync(outPath, dart);
console.log('Written:', outPath);
console.log('Templates:', Object.values(data.templates).filter(v => v.status === 'SUCCEEDED').length);
console.log('Accessories:', Object.values(data.accessories).filter(v => v.status === 'SUCCEEDED').length);
console.log('Items3D:', Object.values(data.items3d).filter(v => v.status === 'SUCCEEDED').length);
