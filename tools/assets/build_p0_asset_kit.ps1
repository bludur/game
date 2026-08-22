$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$builderScript = Join-Path $PSScriptRoot "build_p0_asset_kit.py"

Push-Location $projectRoot
try {
    blender --background --factory-startup --python $builderScript
    if ($LASTEXITCODE -ne 0) {
        throw "Blender asset build failed with exit code $LASTEXITCODE."
    }

    $expectedAssets = @(
        "assets\models\mage_player.glb",
        "assets\models\shadow_chaser.glb",
        "assets\models\ember_cultist.glb",
        "assets\models\arena_floor.glb",
        "assets\models\arena_obelisk.glb",
        "assets\models\arena_altar.glb",
        "assets\source\mage_prototype_p0.blend"
    )
    foreach ($assetPath in $expectedAssets) {
        if (-not (Test-Path $assetPath)) {
            throw "Blender asset build did not create $assetPath."
        }
    }
}
finally {
    Pop-Location
}

Write-Host "P0 asset kit ready in assets/models and assets/source."
