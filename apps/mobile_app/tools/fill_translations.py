"""Fill missing ARB keys from English using Google Translate via deep-translator."""
from __future__ import annotations

import json
import re
import time
from pathlib import Path

from deep_translator import GoogleTranslator

l10n = Path(__file__).resolve().parents[1] / "lib" / "l10n"

# Fix EN corrupted / Turkish strings
en_path = l10n / "app_en.arb"
raw = en_path.read_text(encoding="utf-8")
raw2 = re.sub(
    r'"accessoryPickerTemplateTitle"\s*:\s*"[^"]*"',
    '"accessoryPickerTemplateTitle": "3D Accessory Templates"',
    raw,
)
raw2 = re.sub(
    r'"accessoryPickerTemplateSubtitle"\s*:\s*"[^"]*"',
    '"accessoryPickerTemplateSubtitle": "Browse rigid, layered, and starter templates"',
    raw2,
)
raw2 = re.sub(
    r'"accessoryPickerTemplateCount"\s*:\s*"[^"]*"',
    '"accessoryPickerTemplateCount": "{count} templates"',
    raw2,
)
en_path.write_text(raw2, encoding="utf-8")
print("EN fixed")

en = json.loads(en_path.read_text(encoding="utf-8"))
en_keys = [k for k in en if not k.startswith("@") and k != "@@locale"]

ph_re = re.compile(r"\{[a-zA-Z_][a-zA-Z0-9_]*\}")


def protect(s: str):
    parts: list[str] = []

    def repl(m):
        parts.append(m.group(0))
        return f"<<PH{len(parts) - 1}>>"

    return ph_re.sub(repl, s), parts


def unprotect(s: str, parts: list[str]) -> str:
    for i, p in enumerate(parts):
        s = s.replace(f"<<PH{i}>>", p)
        s = s.replace(f"«PH{i}»", p)
        s = s.replace(f"<PH{i}>", p)
    return s


KEEP = {
    "appTitle",
    "splashTitle",
    "studioVersion",
    "settingsProPlan",
    "settingsStudioPro",
    "analytics3DModel",
    "homeImageFormats",
    "home3DModelFormats",
    "homeUrl",
    "colorPickerHex",
    "authPasswordHint",
    "home3DModel",
    "drawToolMarker",
    "editorDrawToolSticker",
    "clothingEditorSticker",
    "stickerCategoryEmoji",
    "accessory3DBadge",
}

LOCALES = {
    "tr": "tr",
    "de": "de",
    "es": "es",
    "fr": "fr",
    "pt": "pt",
    "ru": "ru",
    "id": "id",
    "ko": "ko",
    "ar": "ar",
}


def translate_batch(texts: list[str], target: str, max_retries: int = 3) -> list[str]:
    if not texts:
        return []
    translator = GoogleTranslator(source="en", target=target)
    out: list[str] = []
    chunk: list[str] = []
    chunk_chars = 3500

    def flush():
        nonlocal chunk, out
        if not chunk:
            return
        joined = "\n".join(chunk)
        for attempt in range(max_retries):
            try:
                translated = translator.translate(joined)
                if translated is None:
                    raise RuntimeError("None")
                lines = translated.split("\n")
                if len(lines) != len(chunk):
                    lines = []
                    for t in chunk:
                        time.sleep(0.05)
                        lines.append(translator.translate(t) or t)
                out.extend(lines)
                break
            except Exception as e:
                if attempt == max_retries - 1:
                    print("  batch fail, one-by-one:", e)
                    for t in chunk:
                        try:
                            time.sleep(0.08)
                            out.append(translator.translate(t) or t)
                        except Exception:
                            out.append(t)
                else:
                    time.sleep(1.5 * (attempt + 1))
        chunk = []

    for t in texts:
        if sum(len(x) + 1 for x in chunk) + len(t) > chunk_chars or len(chunk) >= 40:
            flush()
            time.sleep(0.25)
        chunk.append(t)
    flush()
    return out


for locale_code, google_code in LOCALES.items():
    path = l10n / f"app_{locale_code}.arb"
    data = json.loads(path.read_text(encoding="utf-8"))
    existing = {k for k in data if not k.startswith("@")}
    missing = [k for k in en_keys if k not in existing]
    print(f"\n=== {locale_code}: missing {len(missing)} ===")
    if not missing:
        continue

    prepared: list[str | None] = []
    metas: list[tuple[str, list[str]]] = []
    for k in missing:
        val = en[k]
        if not isinstance(val, str):
            prepared.append(str(val))
            metas.append((k, []))
            continue
        if k in KEEP or val.strip() == "":
            prepared.append(None)
            metas.append((k, []))
        else:
            prot, parts = protect(val)
            prepared.append(prot)
            metas.append((k, parts))

    to_translate = [p for p in prepared if p is not None]
    print(f"  translating {len(to_translate)} strings...")
    translated = translate_batch(to_translate, google_code)
    ti = 0
    for i, (k, parts) in enumerate(metas):
        if prepared[i] is None:
            data[k] = en[k]
        else:
            t = translated[ti]
            ti += 1
            data[k] = unprotect(t, parts)
        meta_key = "@" + k
        if meta_key in en and meta_key not in data:
            data[meta_key] = en[meta_key]

    data["@@locale"] = locale_code

    ordered: dict = {"@@locale": locale_code}
    for k in en:
        if k == "@@locale":
            continue
        if k in data:
            ordered[k] = data[k]
        if k.startswith("@"):
            continue
        mk = "@" + k
        if mk in data:
            ordered[mk] = data[mk]
    for k, v in data.items():
        if k not in ordered:
            ordered[k] = v

    path.write_text(json.dumps(ordered, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    key_count = len([k for k in ordered if not k.startswith("@")])
    print(f"  wrote {path.name}, keys={key_count}")

print("\nDONE")
