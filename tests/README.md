# Tests

- `qa/project_smoke_test.gd` проверяет загрузку основной сцены, игрока, камеры и определения заклинания без графического окна.
- `unit/` содержит модульные тесты GUT 9.7.1.
- `visual/` предназначена для запускаемых вручную сцен проверки камеры, VFX и читаемости боя.

Запуск smoke-теста:

```powershell
.\tools\godot.ps1 -Console --headless --path . --script res://tests/qa/project_smoke_test.gd
```

Запуск GUT:

```powershell
.\tools\godot.ps1 -Console --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```
