"""Remove `const` from widgets that use adaptive AppColors getters."""
from __future__ import annotations

import re
from pathlib import Path

ROOTS = [
    Path(r"c:\Users\User\Desktop\roblox\apps\mobile_app\lib"),
    Path(r"c:\Users\User\Desktop\roblox\packages\design_system\lib"),
    Path(r"c:\Users\User\Desktop\roblox\packages\billing\lib"),
]

ADAPTIVE = (
    r"AppColors\.(background|surface|surfaceContainerLowest|surfaceContainerLow|"
    r"surfaceContainerHigh|onBackground|onSurface|outlineVariant|surfaceMuted|"
    r"textHighEmphasis|textMediumEmphasis|textLowEmphasis|border|borderSubtle)"
)

# Also replace common hard-light sheet/card whites
REPLACEMENTS = [
    (re.compile(r"Color\(0xFFF6F6F3\)"), "AppColors.background"),
    (re.compile(r"Color\(0xFFf6f6f3\)"), "AppColors.background"),
]


def strip_const_before_adaptive(content: str) -> str:
    # const Icon(..., color: AppColors.onBackground)
    content = re.sub(
        rf"const (Icon|IconButton|Text|TextStyle|Divider|BorderSide|BoxDecoration|"
        rf"SizedBox|Padding|Center|Row|Column|Container|ListTile|CircleAvatar|"
        rf"InputDecoration|OutlineInputBorder|UnderlineInputBorder)\(([^;]*?{ADAPTIVE})",
        r"\1(\2",
        content,
        flags=re.DOTALL,
    )
    # const TextStyle(color: AppColors....)
    content = re.sub(
        rf"const TextStyle\(([^)]*{ADAPTIVE}[^)]*)\)",
        r"TextStyle(\1)",
        content,
    )
    content = re.sub(
        rf"const Icon\(([^)]*{ADAPTIVE}[^)]*)\)",
        r"Icon(\1)",
        content,
    )
    content = re.sub(
        rf"const Divider\(([^)]*{ADAPTIVE}[^)]*)\)",
        r"Divider(\1)",
        content,
    )
    content = re.sub(
        rf"const BorderSide\(([^)]*{ADAPTIVE}[^)]*)\)",
        r"BorderSide(\1)",
        content,
    )
    content = re.sub(
        rf"const BoxDecoration\(([^;]*?{ADAPTIVE})",
        r"BoxDecoration(\1",
        content,
        flags=re.DOTALL,
    )
    content = re.sub(
        rf"const IconThemeData\(([^)]*{ADAPTIVE}[^)]*)\)",
        r"IconThemeData(\1)",
        content,
    )
    return content


def fix_colors_white_surfaces(content: str) -> str:
    # backgroundColor: Colors.white -> AppColors.surfaceContainerLowest
    content = re.sub(
        r"backgroundColor:\s*Colors\.white\b",
        "backgroundColor: AppColors.surfaceContainerLowest",
        content,
    )
    content = re.sub(
        r"color:\s*Colors\.white\b(?=\s*,\s*\n\s*(?:borderRadius|border:|boxShadow|shape))",
        "color: AppColors.surfaceContainerLowest",
        content,
    )
    # Common light greys used as card fills
    content = re.sub(r"Color\(0xFFF5F5F5\)", "AppColors.surfaceContainerLow", content)
    content = re.sub(r"Color\(0xFF111111\)", "AppColors.onBackground", content)
    content = re.sub(r"Color\(0xFF6B6B6B\)", "AppColors.outlineVariant", content)
    return content


changed = 0
for root in ROOTS:
    if not root.exists():
        continue
    for path in root.rglob("*.dart"):
        original = path.read_text(encoding="utf-8")
        content = original
        content = strip_const_before_adaptive(content)
        content = fix_colors_white_surfaces(content)
        for pattern, repl in REPLACEMENTS:
            content = pattern.sub(repl, content)
        if content != original:
            path.write_text(content, encoding="utf-8")
            changed += 1
            print("updated", path.relative_to(root.parents[2] if "packages" in str(path) else root.parents[1]))

print("files changed:", changed)
