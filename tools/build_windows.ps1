[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$godotRunner = Join-Path $projectRoot 'tools\godot.ps1'
$windowsDirectory = Join-Path $projectRoot 'build\windows'
$executablePath = Join-Path $windowsDirectory 'Witchroot.exe'
$archivePath = Join-Path $projectRoot 'build\Witchroot-0.4.0-alpha-Windows-x86_64.zip'
$checksumPath = "$archivePath.sha256"
$releaseNotesPath = Join-Path $projectRoot 'docs\RELEASE_NOTES_0_4_0_ALPHA.md'
$playtestPath = Join-Path $projectRoot 'docs\PLAYTEST_0_4_PROTOCOL.md'

New-Item -ItemType Directory -Path $windowsDirectory -Force | Out-Null

Write-Host 'Exporting Windows Desktop release...'
& $godotRunner -Console --headless --path $projectRoot --export-release 'Windows Desktop' $executablePath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $executablePath)) {
    throw 'Windows export failed. Install the matching Godot 4.7.2 export templates and retry.'
}

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
Compress-Archive -LiteralPath $executablePath, $releaseNotesPath, $playtestPath -DestinationPath $archivePath -CompressionLevel Optimal
$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksumPath -Value "$hash  $(Split-Path -Leaf $archivePath)" -Encoding ascii

$buildRoot = (Resolve-Path (Join-Path $projectRoot 'build')).Path
$verifyDirectory = [IO.Path]::GetFullPath((Join-Path $buildRoot ("verify-" + [guid]::NewGuid().ToString('N'))))
$requiredPrefix = $buildRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $verifyDirectory.StartsWith($requiredPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to verify outside the build directory: $verifyDirectory"
}
New-Item -ItemType Directory -Path $verifyDirectory -Force | Out-Null
try {
    Expand-Archive -LiteralPath $archivePath -DestinationPath $verifyDirectory
    $verifiedExecutable = Join-Path $verifyDirectory 'Witchroot.exe'
    if (-not (Test-Path -LiteralPath $verifiedExecutable)) {
        throw 'The packaged archive does not contain Witchroot.exe.'
    }
    $process = Start-Process -FilePath $verifiedExecutable -ArgumentList '--headless', '--quit-after', '4' -WorkingDirectory $verifyDirectory -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "The unpacked Windows build exited with code $($process.ExitCode)."
    }
}
finally {
    if (Test-Path -LiteralPath $verifyDirectory) {
        Remove-Item -LiteralPath $verifyDirectory -Recurse -Force
    }
}

Write-Host "Windows build ready: $archivePath"
Write-Host "SHA-256: $checksumPath"
Write-Host 'Unpacked-path launch verification passed.'
