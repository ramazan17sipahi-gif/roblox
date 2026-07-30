/**
 * Meshy API Batch Asset Generator
 * Generates 3D assets for templates, accessories, clothing, items, and textures.
 * Results are saved to generated_assets.json for Flutter integration.
 */

const API_KEY = 'msy_rSNZ2JiPw1quleeWLCvWzUYEE5FMg5rk5P6S';
const BASE_URL = 'https://api.meshy.ai/v2';
const POLL_INTERVAL = 15000; // 15 seconds
const MAX_CONCURRENT = 8;
const OUTPUT_FILE = './generated_assets.json';

// ─── Asset Definitions ───────────────────────────────────────────────────────

const ASSETS = {
  templates: [
    { id: 'tpl_knight_helm',   prompt: 'Medieval knight helmet with visor, metallic steel, Roblox accessory style, low poly game asset',         artStyle: 'realistic' },
    { id: 'tpl_golden_crown',  prompt: 'Golden royal crown with gemstones, ornate design, Roblox hat accessory, low poly game asset',            artStyle: 'realistic' },
    { id: 'tpl_devil_horns',   prompt: 'Red devil horns headband, demonic style, Roblox head accessory, cartoon game asset',                     artStyle: 'realistic' },
    { id: 'tpl_scifi_visor',   prompt: 'Futuristic sci-fi visor helmet with LED glow, cyberpunk style, Roblox face accessory',                   artStyle: 'realistic' },
    { id: 'tpl_samurai_mask',  prompt: 'Japanese samurai mask oni demon face, red and gold, Roblox face accessory, low poly',                    artStyle: 'realistic' },
    { id: 'tpl_angel_halo',    prompt: 'Glowing golden angel halo floating ring, holy light effect, Roblox hat accessory',                       artStyle: 'realistic' },
    { id: 'tpl_back_shield',   prompt: 'Medieval tower shield with dragon emblem, worn metal texture, Roblox back accessory',                    artStyle: 'realistic' },
    { id: 'tpl_waist_belt',    prompt: 'Tactical utility belt with pouches and gadgets, military style, Roblox waist accessory',                 artStyle: 'realistic' },
    { id: 'tpl_neck_scarf',    prompt: 'Ninja scarf bandana flowing in wind, dark fabric, Roblox neck accessory',                                artStyle: 'realistic' },
    { id: 'tpl_basic_tshirt',  prompt: 'Basic white t-shirt on mannequin torso, clean fabric, Roblox layered clothing template',                 artStyle: 'realistic' },
    { id: 'tpl_basic_jacket',  prompt: 'Leather biker jacket with zipper, dark brown, Roblox layered jacket clothing',                          artStyle: 'realistic' },
    { id: 'tpl_slim_pants',    prompt: 'Slim fit dark jeans pants, detailed denim texture, Roblox layered pants clothing',                       artStyle: 'realistic' },
    { id: 'tpl_sneakers',      prompt: 'High top sneakers shoes, white with red accents, Roblox layered shoe accessory',                        artStyle: 'realistic' },
    { id: 'tpl_dress',         prompt: 'Summer dress with floral pattern, flowing fabric, Roblox layered dress clothing',                        artStyle: 'realistic' },
    { id: 'tpl_hoodie',        prompt: 'Streetwear hoodie with front pocket, dark gray fabric, Roblox layered jacket clothing',                  artStyle: 'realistic' },
    { id: 'tpl_cargo_pants',   prompt: 'Military cargo pants with side pockets, olive green, Roblox layered pants clothing',                    artStyle: 'realistic' },
    { id: 'tpl_sport_shorts',  prompt: 'Athletic sport shorts with stripe detail, polyester fabric, Roblox layered shorts clothing',            artStyle: 'realistic' },
    { id: 'tpl_bow_rigid',     prompt: 'Cute hair bow ribbon accessory, pink satin fabric, Roblox hair accessory',                              artStyle: 'realistic' },
    { id: 'tpl_blank_rigid',   prompt: 'Simple geometric cube primitive, clean white material, blank Roblox accessory template',                artStyle: 'realistic' },
    { id: 'tpl_blank_layer',   prompt: 'Blank body mannequin torso form, smooth white surface, Roblox layered clothing template base',          artStyle: 'realistic' },
  ],
  accessories: [
    { id: 'acc_anime_hair',    prompt: 'Anime style spiky hair wig, bright blue color, Roblox hair accessory, cartoon game asset',               artStyle: 'realistic' },
    { id: 'acc_ponytail',      prompt: 'Long flowing ponytail hairstyle, brown hair, Roblox hair accessory',                                   artStyle: 'realistic' },
    { id: 'acc_afro',          prompt: 'Large afro curly hairstyle, dark brown natural hair, Roblox hair accessory',                            artStyle: 'realistic' },
    { id: 'acc_mohawk',        prompt: 'Neon green mohawk punk hairstyle, glowing tips, Roblox hair accessory',                                 artStyle: 'realistic' },
    { id: 'acc_top_hat',       prompt: 'Classic black top hat with silk band, Victorian gentleman style, Roblox hat accessory',                 artStyle: 'realistic' },
    { id: 'acc_beanie',        prompt: 'Knitted red beanie winter hat, cozy wool texture, Roblox hat accessory',                                artStyle: 'realistic' },
    { id: 'acc_fedora',        prompt: 'Brown leather fedora detective hat with band, Roblox hat accessory',                                    artStyle: 'realistic' },
    { id: 'acc_snapback',      prompt: 'Blue snapback baseball cap with flat brim, Roblox hat accessory, sporty style',                         artStyle: 'realistic' },
    { id: 'acc_sunglasses',    prompt: 'Aviator sunglasses with gold frame and dark lenses, Roblox face accessory',                             artStyle: 'realistic' },
    { id: 'acc_cybermask',     prompt: 'Cyberpunk LED face mask with glowing cyan lines, futuristic Roblox face accessory',                     artStyle: 'realistic' },
    { id: 'acc_bandana',       prompt: 'Red bandana face mask tied at back, outlaw Western style, Roblox face accessory',                       artStyle: 'realistic' },
    { id: 'acc_round_glasses', prompt: 'Round golden frame glasses, Harry Potter wizard style, Roblox face accessory',                          artStyle: 'realistic' },
    { id: 'acc_gold_chain',    prompt: 'Thick gold chain necklace with pendant, hip hop style, Roblox neck accessory',                          artStyle: 'realistic' },
    { id: 'acc_headphones',    prompt: 'Over-ear gaming headphones, black with red LED accents, Roblox neck accessory',                         artStyle: 'realistic' },
    { id: 'acc_angel_wings',   prompt: 'Large white feathered angel wings spread open, heavenly glow, Roblox back accessory',                   artStyle: 'realistic' },
    { id: 'acc_demon_wings',   prompt: 'Bat-like demon wings, dark red with bone structure, Roblox back accessory',                             artStyle: 'realistic' },
    { id: 'acc_jetpack',       prompt: 'Futuristic jetpack with rocket thrusters, metallic silver, Roblox back accessory',                      artStyle: 'realistic' },
    { id: 'acc_katana_sheath', prompt: 'Japanese katana sword in sheath, black lacquer with gold details, Roblox waist accessory',              artStyle: 'realistic' },
    { id: 'acc_fanny_pack',    prompt: 'Neon colored fanny pack waist bag, 90s retro style, Roblox waist accessory',                            artStyle: 'realistic' },
    { id: 'acc_tool_belt',     prompt: 'Construction worker tool belt with hammer and wrench, leather, Roblox waist accessory',                 artStyle: 'realistic' },
  ],
  items3d: [
    { id: 'itm_katana',        prompt: 'Crystal katana sword with glowing blue blade, fantasy weapon, Roblox game prop',                        artStyle: 'realistic' },
    { id: 'itm_shield',        prompt: 'Dragon scale shield with fire emblem, medieval fantasy, Roblox weapon prop',                            artStyle: 'realistic' },
    { id: 'itm_staff',         prompt: 'Wizard magic staff with crystal orb on top, glowing purple, fantasy game prop',                         artStyle: 'realistic' },
    { id: 'itm_bow',           prompt: 'Elvish wooden longbow with vine decorations, fantasy archery weapon, game prop',                        artStyle: 'realistic' },
    { id: 'itm_trident',       prompt: 'Ocean trident weapon with coral and pearl decorations, mythical sea weapon, game prop',                 artStyle: 'realistic' },
    { id: 'itm_hammer',        prompt: 'Thunder war hammer with lightning rune engravings, Viking Nordic style, game weapon prop',               artStyle: 'realistic' },
    { id: 'itm_trophy',        prompt: 'Golden trophy cup with star emblem, champion award, Roblox game prop',                                 artStyle: 'realistic' },
    { id: 'itm_boombox',       prompt: 'Retro 80s boombox radio with speakers, neon stickers, Roblox prop',                                    artStyle: 'realistic' },
    { id: 'itm_skateboard',    prompt: 'Skateboard with graffiti art design on bottom, worn wheels, Roblox prop',                               artStyle: 'realistic' },
    { id: 'itm_guitar',        prompt: 'Electric guitar rock style, red with flame design, Roblox music prop',                                  artStyle: 'realistic' },
    { id: 'itm_camera',        prompt: 'Vintage polaroid instant camera, retro beige color, Roblox prop',                                      artStyle: 'realistic' },
    { id: 'itm_microphone',    prompt: 'Stage performance microphone with stand, chrome silver, Roblox prop',                                  artStyle: 'realistic' },
    { id: 'itm_tree_pine',     prompt: 'Low poly pine tree, stylized game environment asset, green foliage',                                   artStyle: 'realistic' },
    { id: 'itm_rock_mossy',    prompt: 'Mossy boulder rock with green moss patches, nature environment game asset',                             artStyle: 'realistic' },
    { id: 'itm_mushroom',      prompt: 'Glowing fantasy mushroom with bioluminescent purple spots, magical game prop',                          artStyle: 'realistic' },
    { id: 'itm_crystal',       prompt: 'Purple amethyst crystal cluster, shiny gem formation, fantasy game prop',                               artStyle: 'realistic' },
    { id: 'itm_fire_aura',     prompt: 'Fire flame effect orb, burning embers and sparks, VFX game asset',                                     artStyle: 'realistic' },
    { id: 'itm_ice_particles', prompt: 'Ice crystal frost effect, frozen snowflake particles, VFX game asset',                                  artStyle: 'realistic' },
    { id: 'itm_sparkle_trail', prompt: 'Golden sparkle star trail effect, magical glitter particles, VFX game asset',                           artStyle: 'realistic' },
    { id: 'itm_lightning',     prompt: 'Lightning bolt energy effect, electric plasma discharge, VFX game asset',                               artStyle: 'realistic' },
  ],
};

// ─── API Functions ───────────────────────────────────────────────────────────

async function createTask(prompt, artStyle = 'realistic') {
  const response = await fetch(`${BASE_URL}/text-to-3d`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      mode: 'preview',
      prompt,
      art_style: artStyle,
      negative_prompt: 'ugly, blurry, low quality, deformed',
      topology: 'quad',
      target_polycount: 30000,
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Create task failed (${response.status}): ${err}`);
  }

  const data = await response.json();
  return data.result || data.id;
}

async function getTask(taskId) {
  const response = await fetch(`${BASE_URL}/text-to-3d/${taskId}`, {
    headers: { 'Authorization': `Bearer ${API_KEY}` },
  });

  if (!response.ok) {
    throw new Error(`Get task failed (${response.status})`);
  }

  return await response.json();
}

async function pollTask(taskId, label) {
  let attempts = 0;
  const maxAttempts = 60; // 15 minutes max

  while (attempts < maxAttempts) {
    const task = await getTask(taskId);
    const status = task.status;

    if (status === 'SUCCEEDED') {
      console.log(`  ✅ ${label} — DONE`);
      return {
        id: taskId,
        status: 'SUCCEEDED',
        thumbnail_url: task.thumbnail_url,
        model_urls: task.model_urls || {},
        video_url: task.video_url,
      };
    }

    if (status === 'FAILED' || status === 'EXPIRED') {
      console.log(`  ❌ ${label} — ${status}: ${task.task_error?.message || 'unknown'}`);
      return { id: taskId, status, error: task.task_error?.message };
    }

    const progress = task.progress || 0;
    process.stdout.write(`\r  ⏳ ${label} — ${status} (${progress}%) [${attempts + 1}/${maxAttempts}]`);

    attempts++;
    await new Promise(r => setTimeout(r, POLL_INTERVAL));
  }

  console.log(`  ⚠️ ${label} — TIMEOUT after ${maxAttempts} polls`);
  return { id: taskId, status: 'TIMEOUT' };
}

// ─── Batch Processing ────────────────────────────────────────────────────────

async function processBatch(items, category) {
  console.log(`\n${'═'.repeat(60)}`);
  console.log(`📦 Category: ${category} (${items.length} items)`);
  console.log(`${'═'.repeat(60)}`);

  const results = {};

  // Submit tasks in waves of MAX_CONCURRENT
  for (let i = 0; i < items.length; i += MAX_CONCURRENT) {
    const wave = items.slice(i, i + MAX_CONCURRENT);
    console.log(`\n🚀 Wave ${Math.floor(i / MAX_CONCURRENT) + 1} — Submitting ${wave.length} tasks...`);

    // Submit all in wave
    const taskPromises = wave.map(async (item) => {
      try {
        const taskId = await createTask(item.prompt, item.artStyle);
        console.log(`  📝 ${item.id} → Task: ${taskId}`);
        return { ...item, taskId };
      } catch (err) {
        console.log(`  ❌ ${item.id} — Submit failed: ${err.message}`);
        return { ...item, taskId: null, error: err.message };
      }
    });

    const submitted = await Promise.all(taskPromises);

    // Small delay before polling to let tasks start
    await new Promise(r => setTimeout(r, 5000));

    // Poll all tasks in wave
    console.log(`\n⏳ Polling wave results...`);
    const pollPromises = submitted
      .filter(s => s.taskId)
      .map(s => pollTask(s.taskId, s.id).then(result => ({ ...s, result })));

    const completed = await Promise.all(pollPromises);

    for (const item of completed) {
      results[item.id] = {
        taskId: item.taskId,
        prompt: item.prompt,
        thumbnail_url: item.result?.thumbnail_url || null,
        model_urls: item.result?.model_urls || {},
        video_url: item.result?.video_url || null,
        status: item.result?.status || 'UNKNOWN',
      };
    }

    // For failed submissions
    for (const item of submitted.filter(s => !s.taskId)) {
      results[item.id] = { error: item.error, status: 'SUBMIT_FAILED' };
    }

    // Pause between waves
    if (i + MAX_CONCURRENT < items.length) {
      console.log(`\n⏸️  Pausing 10s before next wave...`);
      await new Promise(r => setTimeout(r, 10000));
    }
  }

  return results;
}

// ─── Main ────────────────────────────────────────────────────────────────────

async function main() {
  console.log('🎮 Meshy 3D Asset Batch Generator');
  console.log(`📊 Total assets to generate: ${
    Object.values(ASSETS).reduce((sum, arr) => sum + arr.length, 0)
  }`);
  console.log(`🔑 API Key: ${API_KEY.substring(0, 8)}...`);
  console.log(`⚙️  Max concurrent: ${MAX_CONCURRENT}`);

  // Check balance first
  try {
    const balanceRes = await fetch(`${BASE_URL}/../openapi/v1/balance`, {
      headers: { 'Authorization': `Bearer ${API_KEY}` },
    });
    if (balanceRes.ok) {
      const balance = await balanceRes.json();
      console.log(`💰 Credits: ${JSON.stringify(balance)}`);
    }
  } catch (e) {
    console.log('⚠️  Could not check balance');
  }

  const allResults = {};

  for (const [category, items] of Object.entries(ASSETS)) {
    allResults[category] = await processBatch(items, category);

    // Save intermediate results
    const fs = require('fs');
    fs.writeFileSync(OUTPUT_FILE, JSON.stringify(allResults, null, 2));
    console.log(`\n💾 Saved intermediate results → ${OUTPUT_FILE}`);
  }

  // Final summary
  console.log('\n' + '═'.repeat(60));
  console.log('📊 FINAL SUMMARY');
  console.log('═'.repeat(60));

  for (const [category, results] of Object.entries(allResults)) {
    const total = Object.keys(results).length;
    const succeeded = Object.values(results).filter(r => r.status === 'SUCCEEDED').length;
    const failed = total - succeeded;
    console.log(`  ${category}: ${succeeded}/${total} succeeded ${failed > 0 ? `(${failed} failed)` : '✅'}`);
  }

  console.log(`\n✅ Results saved to: ${OUTPUT_FILE}`);
  console.log('📱 Run the Dart code generator next to update the Flutter app.');
}

main().catch(err => {
  console.error('💥 Fatal error:', err);
  process.exit(1);
});
