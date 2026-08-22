[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$godotRunner = Join-Path $projectRoot 'tools\godot.ps1'
$qaLogDirectory = Join-Path $projectRoot '.godot'

if (-not (Test-Path -LiteralPath $godotRunner)) {
    throw 'tools\godot.ps1 is missing.'
}

New-Item -ItemType Directory -Path $qaLogDirectory -Force | Out-Null

Write-Host 'Refreshing Godot imports and typed class cache...'
& $godotRunner -Console --headless --editor --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_import.log') --quit
if ($LASTEXITCODE -ne 0) {
    throw "Godot import refresh failed with exit code $LASTEXITCODE."
}

Write-Host 'Starting the main scene headlessly...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_main.log') --quit-after 2
if ($LASTEXITCODE -ne 0) {
    throw "Godot import check failed with exit code $LASTEXITCODE."
}

Write-Host 'Running project smoke test...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_smoke.log') --script 'res://tests/qa/project_smoke_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Project smoke test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running Ashen Grove survival smoke test...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_survival_smoke.log') --script 'res://tests/qa/survival_smoke_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Survival smoke test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running enemy chase integration test...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_enemy_chase.log') --script 'res://tests/qa/enemy_chase_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Enemy chase test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running stylized asset integration test...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_stylized_assets.log') --script 'res://tests/qa/stylized_assets_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Stylized asset test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running performance smoke test...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_performance.log') --script 'res://tests/qa/performance_smoke_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Performance smoke test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running Ashen Grove performance smoke test...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_survival_performance.log') --script 'res://tests/qa/survival_performance_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Survival performance smoke test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running accelerated survival soak test...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_survival_soak.log') --script 'res://tests/qa/survival_soak_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Survival soak test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running Ashen Grove Compatibility renderer smoke test...'
& $godotRunner -Console --headless --rendering-method gl_compatibility --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_survival_compatibility.log') --script 'res://tests/qa/survival_smoke_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Survival Compatibility smoke test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running full release flow with five sessions...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_release_flow.log') --script 'res://tests/qa/release_flow_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Release flow test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running Compatibility renderer smoke test...'
& $godotRunner -Console --headless --rendering-method gl_compatibility --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_compatibility.log') --quit-after 2
if ($LASTEXITCODE -ne 0) {
    throw "Compatibility renderer smoke test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running GUT unit tests...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_gut.log') -s 'addons/gut/gut_cmdln.gd' -gexit
if ($LASTEXITCODE -ne 0) {
    throw "GUT tests failed with exit code $LASTEXITCODE."
}

Write-Host 'All checks passed.'
