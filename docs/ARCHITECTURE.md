# Architecture

## Scene composition

```text
Main (Node3D)
├── WorldEnvironment
├── Sun
├── Arena (StaticBody3D)
├── Player (CharacterBody3D instance)
└── TopDownCamera (Node3D instance)
    └── Camera3D
```

`Main` — composition root. Он размещает мир и экземпляры, но не содержит игровой логики.

## Player

```text
Player (CharacterBody3D)
├── CollisionShape3D
└── Visuals
    ├── Body
    ├── Head
    ├── HatBrim
    └── HatCrown
```

`PlayerController` владеет только перемещением и поворотом визуальной модели. Заклинания, здоровье и состояния будут подключаться отдельными компонентами.

## Data flow

```text
Input Map -> PlayerController -> CharacterBody3D.velocity -> move_and_slide()
Player group -> TopDownCamera -> smoothed world position
SpellData (.tres) -> future SpellCaster component -> projectile/VFX scene
```

## Data ownership

- `SpellData` — неизменяемое описание заклинания.
- Будущий `SpellCaster` — кулдауны, текущая мана и активное применение.
- `PlayerController` — скорость и текущее направление движения.
- `TopDownCamera` — параметры визуального слежения.
