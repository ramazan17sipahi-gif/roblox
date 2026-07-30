# Release AAB with compile-time secrets + Dart obfuscation.
# Requires env.local.json (copy from env.local.json.example).

$ErrorActionPreference = "Stop"

if (-not (Test-Path "env.local.json")) {
  Write-Error "env.local.json not found. Copy env.local.json.example and fill in your values."
}

$envFile = (Resolve-Path "env.local.json").Path

flutter build appbundle --release `
  --dart-define-from-file="$envFile" `
  --dart-define=APP_ENVIRONMENT=production `
  --obfuscate `
  --split-debug-info=build/debug-info `
  --no-tree-shake-icons
