"use client";
import { useEffect, useState, useRef } from "react";
import { getSupabaseAdmin } from "@/lib/supabase";
import { getSupabaseBrowser } from "@/lib/supabase-browser";

// Prefer service_role for admin writes when configured
const supabaseAdmin = getSupabaseAdmin();
const supabase = getSupabaseBrowser();

interface ClothingTemplate {
  id: string;
  name: string;
  slug: string;
  template_type: string;
  description: string | null;
  cover_image_url: string | null;
  shirt_texture_url: string | null;
  pants_texture_url: string | null;
  preview_front_url: string | null;
  preview_back_url: string | null;
  is_active: boolean;
  is_pro: boolean;
  sort_order: number;
  created_at: string;
}

const TEMPLATE_TYPES = [
  { value: "classic_shirt", label: "Classic Shirt (585×559)", badge: "badge-purple", needsShirt: true, needsPants: false },
  { value: "classic_pants", label: "Classic Pants (585×559)", badge: "badge-cyan", needsShirt: false, needsPants: true },
  { value: "classic_set", label: "Classic Set (Shirt + Pants)", badge: "badge-accent", needsShirt: true, needsPants: true },
  { value: "classic_tshirt", label: "Classic T-Shirt (128×128)", badge: "badge-purple", needsShirt: true, needsPants: false },
];

export default function TemplatesPage() {
  const [templates, setTemplates] = useState<ClothingTemplate[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<ClothingTemplate | null>(null);

  const fetchTemplates = async () => {
    setLoading(true);
    const { data } = await supabaseAdmin
      .from("clothing_templates")
      .select("*")
      .order("sort_order", { ascending: true });
    if (data) setTemplates(data);
    setLoading(false);
  };

  useEffect(() => { fetchTemplates(); }, []);

  const handleDelete = async (id: string) => {
    if (!confirm("Bu şablonu silmek istediğinize emin misiniz?")) return;
    await supabaseAdmin.from("clothing_templates").delete().eq("id", id);
    fetchTemplates();
  };

  const handleToggleActive = async (t: ClothingTemplate) => {
    await supabaseAdmin.from("clothing_templates").update({ is_active: !t.is_active }).eq("id", t.id);
    fetchTemplates();
  };

  const handleTogglePro = async (t: ClothingTemplate) => {
    await supabaseAdmin.from("clothing_templates").update({ is_pro: !t.is_pro }).eq("id", t.id);
    fetchTemplates();
  };

  const typeBadge = (type: string) => {
    const t = TEMPLATE_TYPES.find(x => x.value === type);
    return t ? t.badge : "badge-accent";
  };

  const typeLabel = (type: string) => {
    const t = TEMPLATE_TYPES.find(x => x.value === type);
    return t ? t.label : type;
  };

  return (
    <div className="admin-page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Kıyafet Şablonları</h1>
          <p className="page-subtitle">Classic clothing UV şablonları · 585×559 · Pro erişim kontrolü</p>
        </div>
        <button className="btn btn-primary" onClick={() => { setEditing(null); setShowForm(true); }}>
          <span className="material-symbols-rounded" style={{ fontSize: 18 }}>add</span>
          Yeni Şablon
        </button>
      </div>

      <div className="info-banner">
        <span className="material-symbols-rounded">cloud_sync</span>
        <div>
          <strong>Uygulama senkronu</strong>
          <p>
            <strong>Aktif</strong> şablonlar mobil uygulamada Templates sekmesinde ve oluştur ekranında görünür.
            Uygulama açılışında veya sayfa yenilendiğinde Supabase&apos;ten çekilir.
            <strong> Pro</strong> işaretli şablonlar yalnızca Pro aboneliği olan kullanıcılar tarafından açılabilir.
            Pasif şablonlar uygulamada gizlenir.
          </p>
        </div>
      </div>

      {showForm && (
        <TemplateForm
          initial={editing}
          onSave={() => { setShowForm(false); fetchTemplates(); }}
          onCancel={() => setShowForm(false)}
        />
      )}

      {loading ? (
        <div className="empty-state">
          <span className="material-symbols-rounded">hourglass_top</span>
          <p>Yükleniyor...</p>
        </div>
      ) : templates.length === 0 ? (
        <div className="empty-state">
          <span className="material-symbols-rounded">inbox</span>
          <p>Henüz şablon eklenmedi</p>
        </div>
      ) : (
        <div style={{ display: "grid", gap: 12 }}>
          {templates.map((t) => (
            <div key={t.id} className="form-card template-row">
              <div className="template-row-inner">
                <div className="template-thumb">
                  {(t.preview_front_url || t.shirt_texture_url || t.cover_image_url) ? (
                    <img
                      src={t.preview_front_url || t.shirt_texture_url || t.cover_image_url || ""}
                      alt={t.name}
                    />
                  ) : (
                    <span className="material-symbols-rounded" style={{ fontSize: 30, color: "var(--text-muted)" }}>checkroom</span>
                  )}
                </div>

                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 4, flexWrap: "wrap" }}>
                    <span style={{ fontWeight: 800, fontSize: 15, letterSpacing: "-0.02em" }}>{t.name}</span>
                    <span className={`badge ${typeBadge(t.template_type)}`}>{typeLabel(t.template_type).split(" (")[0]}</span>
                  </div>
                  <div style={{ fontSize: 12, color: "var(--text-muted)", marginBottom: 8 }}>{t.slug}</div>
                  <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
                    {t.shirt_texture_url && (
                      <span className="badge badge-purple">
                        <span className="material-symbols-rounded" style={{ fontSize: 12 }}>checkroom</span> Shirt
                      </span>
                    )}
                    {t.pants_texture_url && (
                      <span className="badge badge-cyan">
                        <span className="material-symbols-rounded" style={{ fontSize: 12 }}>styler</span> Pants
                      </span>
                    )}
                    {t.preview_front_url && (
                      <span className="badge badge-accent">
                        <span className="material-symbols-rounded" style={{ fontSize: 12 }}>image</span> Preview
                      </span>
                    )}
                  </div>
                </div>

                <div className="template-actions">
                  <div style={{ display: "flex", gap: 6, flexWrap: "wrap", justifyContent: "flex-end" }}>
                    <button className={`toggle-btn ${t.is_active ? "toggle-active" : "toggle-inactive"}`} onClick={() => handleToggleActive(t)}>
                      <span className="material-symbols-rounded" style={{ fontSize: 14 }}>
                        {t.is_active ? "check_circle" : "cancel"}
                      </span>
                      {t.is_active ? "Aktif" : "Pasif"}
                    </button>
                    <button className={`toggle-btn ${t.is_pro ? "toggle-pro" : "toggle-free"}`} onClick={() => handleTogglePro(t)}>
                      <span className="material-symbols-rounded" style={{ fontSize: 14 }}>
                        workspace_premium
                      </span>
                      {t.is_pro ? "Pro" : "Free"}
                    </button>
                  </div>
                  <div style={{ display: "flex", gap: 6 }}>
                    <button className="btn btn-secondary btn-sm" onClick={() => { setEditing(t); setShowForm(true); }}>
                      <span className="material-symbols-rounded" style={{ fontSize: 14 }}>edit</span>
                      Düzenle
                    </button>
                    <button className="btn btn-danger btn-sm" onClick={() => handleDelete(t.id)}>
                      <span className="material-symbols-rounded" style={{ fontSize: 14 }}>delete</span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// TEMPLATE FORM — with file upload + dimension validation
// ═══════════════════════════════════════════════════════════════════════════

function TemplateForm({ initial, onSave, onCancel }: {
  initial: ClothingTemplate | null; onSave: () => void; onCancel: () => void;
}) {
  const [name, setName] = useState(initial?.name || "");
  const [slug, setSlug] = useState(initial?.slug || "");
  const [templateType, setTemplateType] = useState(initial?.template_type || "classic_set");
  const [description, setDescription] = useState(initial?.description || "");
  const [sortOrder, setSortOrder] = useState(initial?.sort_order || 0);
  const [isPro, setIsPro] = useState(initial?.is_pro ?? false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // File states
  const [shirtFile, setShirtFile] = useState<File | null>(null);
  const [pantsFile, setPantsFile] = useState<File | null>(null);
  const [shirtPreview, setShirtPreview] = useState<string | null>(initial?.shirt_texture_url || null);
  const [pantsPreview, setPantsPreview] = useState<string | null>(initial?.pants_texture_url || null);

  const shirtRef = useRef<HTMLInputElement>(null);
  const pantsRef = useRef<HTMLInputElement>(null);

  const typeConfig = TEMPLATE_TYPES.find(t => t.value === templateType);

  // Auto-generate slug from name
  useEffect(() => {
    if (!initial) {
      setSlug(name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""));
    }
  }, [name, initial]);

  // Validate image dimensions
  const validateImageDimensions = (file: File, expectedW: number, expectedH: number): Promise<boolean> => {
    return new Promise((resolve) => {
      const img = new Image();
      img.onload = () => {
        const valid = img.width === expectedW && img.height === expectedH;
        URL.revokeObjectURL(img.src);
        resolve(valid);
      };
      img.onerror = () => resolve(false);
      img.src = URL.createObjectURL(file);
    });
  };

  const handleFileSelect = async (file: File, target: "shirt" | "pants") => {
    setError(null);
    const isTShirt = templateType === "classic_tshirt";
    const expectedW = isTShirt ? 128 : 585;
    const expectedH = isTShirt ? 128 : 559;

    const valid = await validateImageDimensions(file, expectedW, expectedH);
    if (!valid) {
      setError(`${target === "shirt" ? "Shirt" : "Pants"} texture boyutu ${expectedW}×${expectedH} olmalı!`);
      return;
    }

    const preview = URL.createObjectURL(file);
    if (target === "shirt") {
      setShirtFile(file);
      setShirtPreview(preview);
    } else {
      setPantsFile(file);
      setPantsPreview(preview);
    }
  };

  const uploadFile = async (file: File, path: string): Promise<string | null> => {
    const { data, error } = await supabaseAdmin.storage
      .from("clothing-assets")
      .upload(path, file, { upsert: true, contentType: file.type });

    if (error) {
      console.error("Upload error:", error);
      return null;
    }

    const { data: urlData } = supabaseAdmin.storage.from("clothing-assets").getPublicUrl(data.path);
    return urlData.publicUrl;
  };

  const handleSubmit = async () => {
    setError(null);
    if (!name.trim() || !slug.trim()) {
      setError("Ad ve Slug zorunlu!");
      return;
    }

    // Validate required textures
    if (typeConfig?.needsShirt && !shirtFile && !initial?.shirt_texture_url) {
      setError("Shirt texture zorunlu!");
      return;
    }
    if (typeConfig?.needsPants && !pantsFile && !initial?.pants_texture_url) {
      setError("Pants texture zorunlu!");
      return;
    }

    setSaving(true);
    try {
      let shirtUrl = initial?.shirt_texture_url || null;
      let pantsUrl = initial?.pants_texture_url || null;

      // Upload shirt texture
      if (shirtFile) {
        const path = `templates/${slug}/shirt_${Date.now()}.png`;
        shirtUrl = await uploadFile(shirtFile, path);
        if (!shirtUrl) { setError("Shirt upload başarısız!"); setSaving(false); return; }
      }

      // Upload pants texture
      if (pantsFile) {
        const path = `templates/${slug}/pants_${Date.now()}.png`;
        pantsUrl = await uploadFile(pantsFile, path);
        if (!pantsUrl) { setError("Pants upload başarısız!"); setSaving(false); return; }
      }

      const payload = {
        name,
        slug,
        template_type: templateType,
        description: description || null,
        shirt_texture_url: shirtUrl,
        pants_texture_url: pantsUrl,
        sort_order: sortOrder,
        is_pro: isPro,
      };

      if (initial) {
        const { error: dbErr } = await supabaseAdmin.from("clothing_templates").update(payload).eq("id", initial.id);
        if (dbErr) { setError(`DB hatası: ${dbErr.message}`); setSaving(false); return; }
      } else {
        const { error: dbErr } = await supabaseAdmin.from("clothing_templates").insert(payload);
        if (dbErr) { setError(`DB hatası: ${dbErr.message}`); setSaving(false); return; }
      }

      onSave();
    } catch (e: any) {
      setError(e.message || "Beklenmeyen hata");
    }
    setSaving(false);
  };

  return (
    <div className="form-card">
      <h3 style={{ fontSize: 16, fontWeight: 800, marginBottom: 16, display: "flex", alignItems: "center", gap: 8 }}>
        <span className="material-symbols-rounded" style={{ fontSize: 20, color: "var(--accent)" }}>
          {initial ? "edit" : "add_circle"}
        </span>
        {initial ? "Şablon Düzenle" : "Yeni Şablon Ekle"}
      </h3>

      {error && (
        <div style={{
          padding: "10px 14px", marginBottom: 16, borderRadius: 10,
          background: "rgba(239,68,68,0.1)", border: "1px solid rgba(239,68,68,0.2)",
          color: "#ef4444", fontSize: 13, fontWeight: 600, display: "flex", alignItems: "center", gap: 8
        }}>
          <span className="material-symbols-rounded" style={{ fontSize: 18 }}>error</span>
          {error}
        </div>
      )}

      <div className="form-grid">
        <div>
          <label className="form-label">Ad</label>
          <input className="form-input" value={name} onChange={(e) => setName(e.target.value)} placeholder="King Urban Set" />
        </div>
        <div>
          <label className="form-label">Slug</label>
          <input className="form-input" value={slug} onChange={(e) => setSlug(e.target.value)} placeholder="king-urban-set" />
        </div>
        <div>
          <label className="form-label">Tip</label>
          <select className="form-select" value={templateType} onChange={(e) => setTemplateType(e.target.value)}>
            {TEMPLATE_TYPES.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
          </select>
        </div>
        <div>
          <label className="form-label">Sıra</label>
          <input className="form-input" type="number" value={sortOrder} onChange={(e) => setSortOrder(Number(e.target.value))} />
        </div>
        <div style={{ gridColumn: "1 / -1" }}>
          <label className="form-label">Açıklama</label>
          <input className="form-input" value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Şablon açıklaması..." />
        </div>
        <div style={{ gridColumn: "1 / -1" }}>
          <label className="form-label">Erişim</label>
          <label
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 10,
              cursor: "pointer",
              padding: "10px 14px",
              borderRadius: 10,
              border: `1px solid ${isPro ? "rgba(251, 191, 36, 0.45)" : "var(--border)"}`,
              background: isPro ? "rgba(251, 191, 36, 0.08)" : "var(--bg-secondary)",
              userSelect: "none",
            }}
          >
            <input
              type="checkbox"
              checked={isPro}
              onChange={(e) => setIsPro(e.target.checked)}
              style={{ width: 16, height: 16, accentColor: "#fbbf24" }}
            />
            <span className="material-symbols-rounded" style={{ fontSize: 18, color: isPro ? "#fbbf24" : "var(--text-muted)" }}>
              workspace_premium
            </span>
            <span style={{ fontSize: 13, fontWeight: 700 }}>
              Pro şablon — sadece Pro aboneler kullanabilir
            </span>
          </label>
        </div>
      </div>

      {/* ── Texture Upload Area ── */}
      <div style={{ marginTop: 20, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
        {/* Shirt Upload */}
        {typeConfig?.needsShirt && (
          <div>
            <label className="form-label" style={{ marginBottom: 8 }}>
              <span className="material-symbols-rounded" style={{ fontSize: 16, verticalAlign: "middle" }}>checkroom</span>
              {" "}Shirt Texture {templateType === "classic_tshirt" ? "(128×128)" : "(585×559)"}
            </label>
            <div
              onClick={() => shirtRef.current?.click()}
              style={{
                border: "2px dashed var(--border)", borderRadius: 12,
                padding: 16, textAlign: "center", cursor: "pointer",
                background: shirtPreview ? "transparent" : "var(--bg-secondary)",
                transition: "all 0.2s", position: "relative", minHeight: 120,
                display: "flex", alignItems: "center", justifyContent: "center"
              }}
            >
              {shirtPreview ? (
                <img src={shirtPreview} alt="Shirt" style={{ maxWidth: "100%", maxHeight: 150, borderRadius: 8 }} />
              ) : (
                <div style={{ color: "var(--text-muted)" }}>
                  <span className="material-symbols-rounded" style={{ fontSize: 36, display: "block", marginBottom: 4 }}>upload_file</span>
                  <span style={{ fontSize: 11, fontWeight: 600 }}>Shirt PNG yükle</span>
                </div>
              )}
              <input ref={shirtRef} type="file" accept="image/png" hidden
                onChange={(e) => e.target.files?.[0] && handleFileSelect(e.target.files[0], "shirt")} />
            </div>
          </div>
        )}

        {/* Pants Upload */}
        {typeConfig?.needsPants && (
          <div>
            <label className="form-label" style={{ marginBottom: 8 }}>
              <span className="material-symbols-rounded" style={{ fontSize: 16, verticalAlign: "middle" }}>styler</span>
              {" "}Pants Texture (585×559)
            </label>
            <div
              onClick={() => pantsRef.current?.click()}
              style={{
                border: "2px dashed var(--border)", borderRadius: 12,
                padding: 16, textAlign: "center", cursor: "pointer",
                background: pantsPreview ? "transparent" : "var(--bg-secondary)",
                transition: "all 0.2s", position: "relative", minHeight: 120,
                display: "flex", alignItems: "center", justifyContent: "center"
              }}
            >
              {pantsPreview ? (
                <img src={pantsPreview} alt="Pants" style={{ maxWidth: "100%", maxHeight: 150, borderRadius: 8 }} />
              ) : (
                <div style={{ color: "var(--text-muted)" }}>
                  <span className="material-symbols-rounded" style={{ fontSize: 36, display: "block", marginBottom: 4 }}>upload_file</span>
                  <span style={{ fontSize: 11, fontWeight: 600 }}>Pants PNG yükle</span>
                </div>
              )}
              <input ref={pantsRef} type="file" accept="image/png" hidden
                onChange={(e) => e.target.files?.[0] && handleFileSelect(e.target.files[0], "pants")} />
            </div>
          </div>
        )}
      </div>

      <div className="form-actions" style={{ marginTop: 20 }}>
        <button className="btn btn-primary" onClick={handleSubmit} disabled={saving}>
          <span className="material-symbols-rounded" style={{ fontSize: 16 }}>save</span>
          {saving ? "Kaydediliyor..." : "Kaydet"}
        </button>
        <button className="btn btn-secondary" onClick={onCancel}>İptal</button>
      </div>
    </div>
  );
}
