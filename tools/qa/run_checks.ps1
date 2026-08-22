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

Write-Host 'Running Ashen Grove world-content and navigation test...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_ashen_grove_world.log') --script 'res://tests/qa/ashen_grove_world_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Ashen Grove world-content test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running Moonbound region transition and content test...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_moonbound_region.log') --script 'res://tests/qa/moonbound_region_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Moonbound region test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running third-person locomotion course regression...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_locomotion_course.log') --script 'res://tests/qa/third_person_locomotion_course_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Third-person locomotion course failed with exit code $LASTEXITCODE."
}

Write-Host 'Running three-dimensional spell aim regression...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_combat_aim.log') --script 'res://tests/qa/three_dimensional_aim_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Three-dimensional spell aim test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running authored third-person combat room regression...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_combat_room.log') --script 'res://tests/qa/third_person_combat_room_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Third-person combat room test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running enemy chase integration test...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_enemy_chase.log') --script 'res://tests/qa/enemy_chase_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Enemy chase test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running enemy ecology, raid, and eight-agent budget test...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_enemy_ecology.log') --script 'res://tests/qa/enemy_ecology_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Enemy ecology test failed with exit code $LASTEXITCODE."
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

Write-Host 'Running 250-piece construction performance test...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_construction_performance.log') --script 'res://tests/qa/construction_performance_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Construction performance test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running accelerated survival soak test...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_survival_soak.log') --script 'res://tests/qa/survival_soak_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Survival soak test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running alpha two-region transition, construction, save/load, and death soak test...'
& $godotRunner -Console --headless --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_alpha_two_region_soak.log') --script 'res://tests/qa/alpha_two_region_soak_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Alpha two-region soak test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running Ashen Grove Compatibility renderer smoke test...'
& $godotRunner -Console --headless --rendering-method gl_compatibility --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_survival_compatibility.log') --script 'res://tests/qa/survival_smoke_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Survival Compatibility smoke test failed with exit code $LASTEXITCODE."
}

Write-Host 'Running Moonbound Compatibility renderer transition test...'
& $godotRunner -Console --headless --rendering-method gl_compatibility --path $projectRoot --log-file (Join-Path $qaLogDirectory 'qa_moonbound_compatibility.log') --script 'res://tests/qa/moonbound_region_test.gd'
if ($LASTEXITCODE -ne 0) {
    throw "Moonbound Compatibility transition test failed with exit code $LASTEXITCODE."
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
