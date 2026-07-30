"use client";
import { useEffect, useState } from "react";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ""
);

interface StickerCategory {
  id: string;
  name: string;
  slug: string;
  icon_name: string | null;
  sort_order: number;
  is_active: boolean;
}

interface Sticker {
  id: string;
  category_id: string;
  name: string;
  image_url: string;
  is_active: boolean;
  is_pro: boolean;
  sort_order: number;
}

export default function StickersPage() {
  const [categories, setCategories] = useState<StickerCategory[]>([]);
  const [stickers, setStickers] = useState<Sticker[]>([]);
  const [selectedCat, setSelectedCat] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [showCatForm, setShowCatForm] = useState(false);
  const [showStickerForm, setShowStickerForm] = useState(false);
  const [editingSticker, setEditingSticker] = useState<Sticker | null>(null);

  const fetchAll = async () => {
    setLoading(true);
    const [catRes, stkRes] = await Promise.all([
      supabase.from("sticker_categories").select("*").order("sort_order"),
      supabase.from("stickers").select("*").order("sort_order"),
    ]);
    if (catRes.data) setCategories(catRes.data);
    if (stkRes.data) setStickers(stkRes.data);
    setLoading(false);
  };

  useEffect(() => { fetchAll(); }, []);

  const filteredStickers = selectedCat
    ? stickers.filter((s) => s.category_id === selectedCat)
    : stickers;

  const handleDeleteCategory = async (id: string) => {
    if (!confirm("Bu kategoriyi ve tüm sticker'larını silmek istediğinize emin misiniz?")) return;
    await supabase.from("sticker_categories").delete().eq("id", id);
    fetchAll();
  };

  const handleDeleteSticker = async (id: string) => {
    if (!confirm("Sticker'ı silmek istediğinize emin misiniz?")) return;
    await supabase.from("stickers").delete().eq("id", id);
    fetchAll();
  };

  const handleToggleStickerActive = async (s: Sticker) => {
    await supabase.from("stickers").update({ is_active: !s.is_active }).eq("id", s.id);
    fetchAll();
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Sticker Yönetimi</h1>
          <p className="page-subtitle">Kategori ve sticker CRUD işlemleri</p>
        </div>
        <div style={{ display: "flex", gap: 8 }}>
          <button className="btn btn-secondary" onClick={() => setShowCatForm(true)}>
            <span className="material-symbols-rounded" style={{ fontSize: 16 }}>create_new_folder</span>
            Kategori Ekle
          </button>
          <button className="btn btn-primary" onClick={() => { setEditingSticker(null); setShowStickerForm(true); }}>
            <span className="material-symbols-rounded" style={{ fontSize: 16 }}>add</span>
            Sticker Ekle
          </button>
        </div>
      </div>

      {showCatForm && (
        <CategoryForm onSave={() => { setShowCatForm(false); fetchAll(); }} onCancel={() => setShowCatForm(false)} />
      )}

      {showStickerForm && (
        <StickerForm
          categories={categories}
          initial={editingSticker}
          defaultCategoryId={selectedCat}
          onSave={() => { setShowStickerForm(false); fetchAll(); }}
          onCancel={() => setShowStickerForm(false)}
        />
      )}

      {/* Category chips */}
      <div className="chip-row">
        <button className={`chip ${selectedCat === null ? "active" : ""}`} onClick={() => setSelectedCat(null)}>
          Tümü ({stickers.length})
        </button>
        {categories.map((c) => (
          <div key={c.id} style={{ display: "flex", alignItems: "center", gap: 2 }}>
            <button
              className={`chip ${selectedCat === c.id ? "active" : ""}`}
              onClick={() => setSelectedCat(c.id)}
            >
              {c.name} ({stickers.filter((s) => s.category_id === c.id).length})
            </button>
            <button
              onClick={() => handleDeleteCategory(c.id)}
              style={{ background: "none", border: "none", color: "var(--text-muted)", cursor: "pointer", fontSize: 14, padding: 2 }}
            >
              ×
            </button>
          </div>
        ))}
      </div>

      {/* Sticker grid */}
      {loading ? (
        <div className="empty-state">
          <span className="material-symbols-rounded">hourglass_top</span>
          <p>Yükleniyor...</p>
        </div>
      ) : filteredStickers.length === 0 ? (
        <div className="empty-state">
          <span className="material-symbols-rounded">image_not_supported</span>
          <p>Sticker bulunamadı</p>
        </div>
      ) : (
        <div className="sticker-grid">
          {filteredStickers.map((s) => (
            <div key={s.id} className="sticker-card">
              <div
                className="sticker-preview"
                style={s.image_url ? { backgroundImage: `url(${s.image_url})` } : undefined}
              >
                {!s.image_url && (
                  <span className="material-symbols-rounded" style={{ fontSize: 32, color: "var(--text-muted)", opacity: 0.3 }}>image</span>
                )}
              </div>
              <div style={{ fontWeight: 700, fontSize: 13, marginBottom: 6 }}>{s.name}</div>
              <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
                <button
                  className={`toggle-btn ${s.is_active ? "toggle-active" : "toggle-inactive"}`}
                  onClick={() => handleToggleStickerActive(s)}
                >
                  {s.is_active ? "Aktif" : "Pasif"}
                </button>
                {s.is_pro && <span className="badge badge-yellow">Pro</span>}
              </div>

              <div className="sticker-actions">
                <button className="btn btn-secondary btn-sm" onClick={() => { setEditingSticker(s); setShowStickerForm(true); }}>
                  <span className="material-symbols-rounded" style={{ fontSize: 14 }}>edit</span>
                </button>
                <button className="btn btn-danger btn-sm" onClick={() => handleDeleteSticker(s.id)}>
                  <span className="material-symbols-rounded" style={{ fontSize: 14 }}>delete</span>
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function CategoryForm({ onSave, onCancel }: { onSave: () => void; onCancel: () => void }) {
  const [name, setName] = useState("");
  const [slug, setSlug] = useState("");
  const [sortOrder, setSortOrder] = useState(0);

  const handleSubmit = async () => {
    await supabase.from("sticker_categories").insert({ name, slug, sort_order: sortOrder });
    onSave();
  };

  return (
    <div className="form-card">
      <h3 style={{ fontSize: 16, fontWeight: 800, marginBottom: 16, display: "flex", alignItems: "center", gap: 8 }}>
        <span className="material-symbols-rounded" style={{ fontSize: 20, color: "var(--accent)" }}>create_new_folder</span>
        Yeni Kategori
      </h3>
      <div style={{ display: "flex", gap: 12 }}>
        <div style={{ flex: 1 }}>
          <label className="form-label">Ad</label>
          <input className="form-input" value={name} onChange={(e) => setName(e.target.value)} placeholder="Kategori adı" />
        </div>
        <div style={{ flex: 1 }}>
          <label className="form-label">Slug</label>
          <input className="form-input" value={slug} onChange={(e) => setSlug(e.target.value)} placeholder="kategori-slug" />
        </div>
        <div style={{ width: 100 }}>
          <label className="form-label">Sıra</label>
          <input className="form-input" type="number" value={sortOrder} onChange={(e) => setSortOrder(Number(e.target.value))} />
        </div>
      </div>
      <div className="form-actions">
        <button className="btn btn-primary" onClick={handleSubmit}>
          <span className="material-symbols-rounded" style={{ fontSize: 16 }}>save</span>
          Kaydet
        </button>
        <button className="btn btn-secondary" onClick={onCancel}>İptal</button>
      </div>
    </div>
  );
}

function StickerForm({ categories, initial, defaultCategoryId, onSave, onCancel }: {
  categories: StickerCategory[]; initial: Sticker | null; defaultCategoryId: string | null;
  onSave: () => void; onCancel: () => void;
}) {
  const [name, setName] = useState(initial?.name || "");
  const [imageUrl, setImageUrl] = useState(initial?.image_url || "");
  const [categoryId, setCategoryId] = useState(initial?.category_id || defaultCategoryId || categories[0]?.id || "");
  const [sortOrder, setSortOrder] = useState(initial?.sort_order || 0);
  const [isPro, setIsPro] = useState(initial?.is_pro || false);

  const handleSubmit = async () => {
    const payload = { name, image_url: imageUrl, category_id: categoryId, sort_order: sortOrder, is_pro: isPro };
    if (initial) {
      await supabase.from("stickers").update(payload).eq("id", initial.id);
    } else {
      await supabase.from("stickers").insert(payload);
    }
    onSave();
  };

  return (
    <div className="form-card">
      <h3 style={{ fontSize: 16, fontWeight: 800, marginBottom: 16, display: "flex", alignItems: "center", gap: 8 }}>
        <span className="material-symbols-rounded" style={{ fontSize: 20, color: "var(--purple)" }}>
          {initial ? "edit" : "add_circle"}
        </span>
        {initial ? "Sticker Düzenle" : "Yeni Sticker Ekle"}
      </h3>
      <div className="form-grid">
        <div>
          <label className="form-label">Ad</label>
          <input className="form-input" value={name} onChange={(e) => setName(e.target.value)} placeholder="Sticker adı" />
        </div>
        <div>
          <label className="form-label">Image URL</label>
          <input className="form-input" value={imageUrl} onChange={(e) => setImageUrl(e.target.value)} placeholder="https://..." />
        </div>
        <div>
          <label className="form-label">Kategori</label>
          <select className="form-select" value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
            {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
        </div>
        <div style={{ display: "flex", gap: 16 }}>
          <div style={{ flex: 1 }}>
            <label className="form-label">Sıra</label>
            <input className="form-input" type="number" value={sortOrder} onChange={(e) => setSortOrder(Number(e.target.value))} />
          </div>
          <div style={{ flex: 1, display: "flex", alignItems: "flex-end", paddingBottom: 10 }}>
            <label style={{ fontSize: 13, color: "var(--text-secondary)", display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }}>
              <input type="checkbox" checked={isPro} onChange={(e) => setIsPro(e.target.checked)} />
              <span className="material-symbols-rounded" style={{ fontSize: 16, color: isPro ? "var(--yellow)" : "var(--text-muted)" }}>workspace_premium</span>
              Pro İçerik
            </label>
          </div>
        </div>
      </div>
      <div className="form-actions">
        <button className="btn btn-primary" onClick={handleSubmit}>
          <span className="material-symbols-rounded" style={{ fontSize: 16 }}>save</span>
          {initial ? "Güncelle" : "Ekle"}
        </button>
        <button className="btn btn-secondary" onClick={onCancel}>İptal</button>
      </div>
    </div>
  );
}
