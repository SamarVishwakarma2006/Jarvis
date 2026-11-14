$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'VERSION must use the format major.minor.patch.' }

$files = @(
    'README.md', 'LICENSE', 'PRIVACY.md', 'RELEASE_NOTES.md', 'VERSION',
    'Run-VoiceDesk.cmd', 'VoiceDesk.ps1', 'package-release.ps1',
    'ai-service', 'gesture_service.py', 'requirements-gestures.txt'
)
foreach ($file in $files) {
    if (-not (Test-Path (Join-Path $root $file))) { throw "Release file is missing: $file" }
}

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$archive = Join-Path $dist "VoiceDesk-$version-source.zip"
Push-Location $root
try {
    Compress-Archive -Path $files -DestinationPath $archive -Force
} finally {
    Pop-Location
}
Write-Host "Created $archive"
