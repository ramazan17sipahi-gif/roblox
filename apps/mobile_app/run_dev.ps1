# Local debug run with secrets from env.local.json (gitignored).

$ErrorActionPreference = "Stop"

if (-not (Test-Path "env.local.json")) {
  Write-Error "env.local.json not found. Copy env.local.json.example and fill in your values."
}

$envFile = (Resolve-Path "env.local.json").Path

flutter run --dart-define-from-file="$envFile" @args
