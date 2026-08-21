[CmdletBinding()]
param(
    [switch]$Console,
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$GodotArguments
)

$ErrorActionPreference = 'Stop'
$packageRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
$executablePattern = if ($Console) {
    'Godot_v*-stable_win64_console.exe'
} else {
    'Godot_v*-stable_win64.exe'
}

$godotExecutable = Get-ChildItem -Path $packageRoot -Filter $executablePattern -Recurse -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $godotExecutable) {
    $commandName = if ($Console) { 'godot_console' } else { 'godot' }
    $fallbackCommand = Get-Command $commandName -ErrorAction SilentlyContinue
    if (-not $fallbackCommand) {
        throw 'Godot was not found. Install it with: winget install --id GodotEngine.GodotEngine'
    }
    & $fallbackCommand.Source @GodotArguments
    exit $LASTEXITCODE
}

& $godotExecutable.FullName @GodotArguments
exit $LASTEXITCODE
