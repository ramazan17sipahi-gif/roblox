"""Re-translate French ARB keys that are still identical to English."""
from __future__ import annotations

import json
import re
import time
from pathlib import Path

from deep_translator import GoogleTranslator

l10n = Path(__file__).resolve().parents[1] / "lib" / "l10n"
en = json.loads((l10n / "app_en.arb").read_text(encoding="utf-8"))
fr_path = l10n / "app_fr.arb"
fr = json.loads(fr_path.read_text(encoding="utf-8"))

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
    "cancel",
    "ok",
    "retry",
}

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


keys = []
for k, v in en.items():
    if k.startswith("@") or k == "@@locale":
        continue
    if k in KEEP or not isinstance(v, str):
        continue
    if fr.get(k) == v and len(v) > 2:
        keys.append(k)

print(f"FR keys still English: {len(keys)}")
translator = GoogleTranslator(source="en", target="fr")

for i, k in enumerate(keys):
    src = en[k]
    prot, parts = protect(src)
    for attempt in range(5):
        try:
            out = translator.translate(prot) or src
            fr[k] = unprotect(out, parts)
            break
        except Exception as e:
            print(f"  fail {k} attempt {attempt}: {e}")
            time.sleep(2 * (attempt + 1))
    else:
        print(f"  SKIP {k}")
    if (i + 1) % 20 == 0:
        print(f"  {i + 1}/{len(keys)}")
        time.sleep(0.5)
    else:
        time.sleep(0.12)

# order like EN
ordered = {"@@locale": "fr"}
for k in en:
    if k == "@@locale":
        continue
    if k in fr:
        ordered[k] = fr[k]
    if not k.startswith("@"):
        mk = "@" + k
        if mk in fr:
            ordered[mk] = fr[mk]
        elif mk in en:
            ordered[mk] = en[mk]
for k, v in fr.items():
    if k not in ordered:
        ordered[k] = v

fr_path.write_text(json.dumps(ordered, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("FR rewritten")
