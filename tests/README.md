# Tests

- `qa/project_smoke_test.gd` проверяет загрузку основной сцены, игрока, камеры,
  целей и создание снаряда без графического окна.
- `unit/` содержит тесты GUT для ресурсов, здоровья, маны и интеграции попадания.
- `visual/combat_preview.tscn` автоматически выпускает `Arcane Bolt` для ручной
  проверки камеры, HUD, VFX и читаемости боя.

Запуск smoke-теста:

```powershell
.\tools\godot.ps1 -Console --headless --path . --script res://tests/qa/project_smoke_test.gd
```

Запуск GUT:

```powershell
.\tools\godot.ps1 -Console --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```
