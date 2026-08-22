# Воспроизводимые кадры 0.2.0

Запускать из корня проекта с Godot 4.7.2:

```powershell
.\tools\godot.ps1 -Console --path . --resolution 1280x720 --fixed-fps 30 --write-movie .godot/repro_menu.png --quit-after 3
.\tools\godot.ps1 -Console --path . --resolution 1280x720 --fixed-fps 30 --write-movie .godot/repro_boss.png --quit-after 50 res://tests/visual/boss_preview.tscn
```

Godot создаёт последовательность кадров с числовым суффиксом. Для сравнения
релизов используйте последний кадр меню и кадр boss preview, на котором
одновременно видны HUD, Хранитель и телеграф. Зафиксированные эталоны лежат рядом:
`main_menu_0_2_0.png` и `boss_encounter_0_2_0.png`. Папка имеет `.gdignore` и
исключена из export preset, поэтому материалы QA не попадают в сборку.
