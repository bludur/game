[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$godotRunner = Join-Path $projectRoot 'tools\godot.ps1'
$windowsDirectory = Join-Path $projectRoot 'build\windows'
$executablePath = Join-Path $windowsDirectory 'Witchroot.exe'
$archivePath = Join-Path $projectRoot 'build\Witchroot-0.3.0-dev-Windows-x86_64.zip'
$checksumPath = "$archivePath.sha256"
$releaseNotesPath = Join-Path $projectRoot 'docs\RELEASE_NOTES_0_3_0_DEV.md'

New-Item -ItemType Directory -Path $windowsDirectory -Force | Out-Null

Write-Host 'Exporting Windows Desktop release...'
& $godotRunner -Console --headless --path $projectRoot --export-release 'Windows Desktop' $executablePath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $executablePath)) {
    throw 'Windows export failed. Install the matching Godot 4.7.2 export templates and retry.'
}

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
Compress-Archive -LiteralPath $executablePath, $releaseNotesPath -DestinationPath $archivePath -CompressionLevel Optimal
$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksumPath -Value "$hash  $(Split-Path -Leaf $archivePath)" -Encoding ascii
Write-Host "Windows build ready: $archivePath"
Write-Host "SHA-256: $checksumPath"
