# Architecture

## Scene composition

```text
WorldSession (Node3D)
├── WorldEnvironment
├── Sun
├── RegionHost
│   ├── AshenGrove
│   └── StarlessCrypt
├── Player (CharacterBody3D instance)
├── ThirdPersonCameraRig
│   └── PitchPivot
│       └── ShoulderOffset
│           └── SpringArm3D
│               └── Camera3D
├── InteractionController
├── ConstructionHost
├── ThreatDirector
└── SurvivalHud (CanvasLayer)
```

`WorldSession` — composition root survival-среза. Старая `ArenaRun` с
`TopDownCamera` сохранена как отдельная боевая и QA-сцена.

## Player

```text
Player (CharacterBody3D)
├── PlayerController
├── HealthComponent
├── ManaComponent
├── SpellCaster
├── SpellLoadout
├── DashComponent
├── HurtboxComponent
├── CastOrigin
├── CollisionShape3D
└── Visuals
    ├── Body
    ├── Head
    ├── HatBrim
    └── HatCrown
```

`MagePlayer` — композиционный корень, который связывает прямых детей.
`PlayerController` владеет перемещением относительно камеры, бегом и поворотом
тела персонажа в направлении движения или заклинания.
`HealthComponent`, `ManaComponent`, `SpellCaster`, `SpellLoadout` и
`DashComponent` являются переиспользуемыми сценами.

## Session flow

```text
RunDirector.INTRO
  -> Wave 1 -> Wave 2
  -> UPGRADE (UpgradeData × 3)
  -> FINAL (Wave 3)
  -> VICTORY / DEFEAT
  -> clean restart
```

`RunDirector` владеет только состоянием забега и применением выбранной руны.
`WaveDirector` владеет созданными им врагами и их счётчиком. Тренировочные цели
остаются частью арены, но никогда не попадают в состояние волны.

## Data flow

```text
Input Map -> PlayerController -> CharacterBody3D.velocity -> move_and_slide()
Player group -> ThirdPersonCameraRig -> interpolated follow -> SpringArm3D collision
mouse/right stick -> ThirdPersonCameraRig -> yaw/pitch -> camera-relative movement
primary_spell -> screen-center aim -> SpellCaster -> ManaComponent.try_spend()
SpellData (.tres) -> ArcaneBolt (Area3D) -> HurtboxComponent -> HealthComponent
Health/Mana/SpellCaster signals -> MageHud
Enemy.defeated -> WaveDirector -> RunDirector -> SessionUi
UpgradeData -> RunDirector -> owning Health/Mana/SpellLoadout component
```

## Data ownership

- `SpellData` — неизменяемое описание заклинания.
- `UpgradeData` и `WaveData` — неизменяемые определения улучшений и волн.
- `SpellCaster` — кулдаун, прицеливание и создание снаряда.
- `ManaComponent` — текущая мана и восстановление.
- `HealthComponent` — изменяемое здоровье конкретной сущности.
- `PlayerController` — скорость и текущее направление движения.
- `ThirdPersonCameraRig` — orbit, zoom, мышь/геймпад и защита камеры от стен.
- `TopDownCamera` — сохранённая камера старой QA-арены.
- `WaveDirector` — текущая волна, очередь появления и оставшиеся враги.
- `RunDirector` — стадия сессии и временно применённое улучшение.
