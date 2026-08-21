# Architecture

## Scene composition

```text
Main (Node3D)
├── WorldEnvironment
├── Sun
├── Arena (StaticBody3D)
├── Player (CharacterBody3D instance)
├── TopDownCamera (Node3D instance)
│   └── Camera3D
├── TrainingTarget × 3
└── MageHud (CanvasLayer)
```

`Main` — composition root. Он размещает мир и экземпляры, но не содержит игровой логики.

## Player

```text
Player (CharacterBody3D)
├── PlayerController
├── HealthComponent
├── ManaComponent
├── SpellCaster
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
`HealthComponent`, `ManaComponent` и `SpellCaster` являются переиспользуемыми сценами.

## Data flow

```text
Input Map -> PlayerController -> CharacterBody3D.velocity -> move_and_slide()
Player group -> TopDownCamera -> smoothed world position
primary_spell -> SpellCaster -> ManaComponent.try_spend()
SpellData (.tres) -> ArcaneBolt (Area3D) -> HurtboxComponent -> HealthComponent
Health/Mana/SpellCaster signals -> MageHud
```

## Data ownership

- `SpellData` — неизменяемое описание заклинания.
- `SpellCaster` — кулдаун, прицеливание и создание снаряда.
- `ManaComponent` — текущая мана и восстановление.
- `HealthComponent` — изменяемое здоровье конкретной сущности.
- `PlayerController` — скорость и текущее направление движения.
- `TopDownCamera` — параметры визуального слежения.
