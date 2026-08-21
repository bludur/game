[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$godotRunner = Join-Path $projectRoot 'tools\godot.ps1'
$windowsDirectory = Join-Path $projectRoot 'build\windows'
$executablePath = Join-Path $windowsDirectory 'MagePrototype.exe'
$archivePath = Join-Path $projectRoot 'build\MagePrototype-Windows-x86_64.zip'

New-Item -ItemType Directory -Path $windowsDirectory -Force | Out-Null

Write-Host 'Exporting Windows Desktop release...'
& $godotRunner -Console --headless --path $projectRoot --export-release 'Windows Desktop' $executablePath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $executablePath)) {
    throw 'Windows export failed. Install the matching Godot 4.7.2 export templates and retry.'
}

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
Compress-Archive -LiteralPath $executablePath -DestinationPath $archivePath -CompressionLevel Optimal
Write-Host "Windows build ready: $archivePath"
