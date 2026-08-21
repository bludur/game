# Architecture

## Scene composition

```text
Main (Node3D)
├── WorldEnvironment
├── Sun
├── Arena (StaticBody3D)
├── Player (CharacterBody3D instance)
├── WaveDirector
│   ├── Enemies
│   └── SpawnPoints × 4
├── RunDirector
├── TopDownCamera (Node3D instance)
│   └── Camera3D
├── TrainingTarget × 3
├── MageHud (CanvasLayer)
└── SessionUi (CanvasLayer)
```

`Main` — composition root. Он размещает мир и экземпляры, но не содержит игровой логики.

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
`PlayerController` владеет только перемещением и поворотом визуальной модели.
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
Player group -> TopDownCamera -> smoothed world position
primary_spell -> SpellCaster -> ManaComponent.try_spend()
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
- `TopDownCamera` — параметры визуального слежения.
- `WaveDirector` — текущая волна, очередь появления и оставшиеся враги.
- `RunDirector` — стадия сессии и временно применённое улучшение.
