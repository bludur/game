# AI Workflow

Codex работает непосредственно с репозиторием, а файл `AGENTS.md` фиксирует
границы продукта, архитектурные правила и обязательные проверки.

## Лучшие скилы для этого проекта

### Нужны почти на каждом этапе

- `godot-brainstorming` — сначала спроектировать новый игровой модуль и дерево сцен.
- `scene-organization` — не превращать одну сцену в неразделимый монолит.
- `gdscript-patterns` — сохранять строгую типизацию и актуальный синтаксис Godot 4.x.
- `godot-testing` — добавлять проверку вместе с поведением.
- `godot-code-review` — обязательный аудит перед завершением задачи.

### Основа вертикального среза

- `player-controller`, `input-handling`, `physics-system` — движение мага и коллизии.
- `camera-system` — top-down камера, сглаживание и look-ahead.
- `resource-pattern` — описания заклинаний, врагов и предметов в `.tres`.
- `component-system` — здоровье, мана, получение урона и применение заклинаний.
- `ai-navigation`, `state-machine` — первый преследующий противник.
- `particles-vfx`, `shader-basics`, `animation-system` — читаемая магия и отклик на попадание.
- `godot-ui`, `hud-system`, `responsive-ui` — HUD без привязки к одному разрешению.
- `audio-system` — звуки заклинаний и атмосфера.

### Подключать позже

- `assets-pipeline` — когда появятся реальные модели Blender, текстуры и аудио.
- `godot-optimization` — после появления измеряемых проблем в профайлере.
- `export-pipeline` — перед первой Windows-сборкой.
- `save-load`, `inventory-system`, `dialogue-system`, `localization` — только после
  подтверждения, что эти системы входят в игровой цикл.

`multiplayer-*`, `dedicated-server`, `procedural-generation` и `xr-development`
сейчас не нужны: они расширяют технологический риск, но не доказывают качество
основного цикла «движение → заклинание → попадание → победа».

## Формат хорошей задачи для Codex

```text
Сделай магический снаряд для текущего вертикального среза.
Сначала используй godot-brainstorming, затем resource-pattern,
physics-system, particles-vfx и godot-testing. Не добавляй Autoload.
После реализации запусти tools/qa/run_checks.ps1 и godot-code-review.
```

Такой запрос задаёт игровую цель, архитектурные ограничения и критерий готовности,
но оставляет Codex свободу подобрать конкретные узлы и реализацию.
