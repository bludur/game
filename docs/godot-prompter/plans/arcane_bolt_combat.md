# Arcane Bolt Combat Slice

## Decision

Use a code-moved `Area3D` projectile. Compared with hitscan, it makes magic
readable on screen; compared with `RigidBody3D`, it gives deterministic movement
without force integration. A primitive sphere overlap is sufficient for the
current speed and target sizes.

## Scene trees

```text
Player (CharacterBody3D)
├── PlayerController (Node)
├── HealthComponent (Node)
├── ManaComponent (Node)
├── CastOrigin (Marker3D)
├── SpellCaster (Node)
└── Visuals (Node3D)

ArcaneBolt (Area3D)
├── CollisionShape3D
├── Core (MeshInstance3D)
├── Glow (OmniLight3D)
└── Trail (GPUParticles3D)

TrainingTarget (StaticBody3D)
├── CollisionShape3D
├── Visuals (Node3D)
├── HealthComponent (Node)
├── HurtboxComponent (Area3D)
└── RespawnTimer (Timer)

MageHud (CanvasLayer)
└── Root (Control, Full Rect)
    └── StatusPanel (PanelContainer)
        └── VBoxContainer
            ├── HealthBar (ProgressBar)
            ├── ManaBar (ProgressBar)
            └── CooldownBar (ProgressBar)
```

## Ownership and signals

- `HealthComponent` owns current and maximum health; emits `health_changed` and `died`.
- `ManaComponent` owns current mana and regeneration; emits `mana_changed`.
- `SpellCaster` owns cooldown state; consumes `primary_spell`, spends mana, and
  emits `spell_cast`, `cast_failed`, and `cooldown_changed`.
- `ArcaneBolt` owns travel distance and collision; calls the public
  `HurtboxComponent.receive_hit()` contract.
- `HurtboxComponent` routes damage to its explicitly wired `HealthComponent`.
- `TrainingTarget` owns death feedback and respawn, listening to component signals.
- `MageHud` listens to component signals; it does not poll gameplay state.

## Data flow

```text
primary_spell
  -> SpellCaster ray/ground-plane aim
  -> ManaComponent.try_spend
  -> ArcaneBolt.configure + spawn
  -> HurtboxComponent.receive_hit
  -> HealthComponent.take_damage
  -> TrainingTarget feedback / respawn
```

## Implementation tasks

- [x] Components and their isolated unit tests.
  Skills: `component-system`, `gdscript-patterns`, `godot-testing`
- [x] Arcane Bolt projectile and impact/trail VFX.
  Skills: `resource-pattern`, `physics-system`, `particles-vfx`
- [x] Player composition and mouse casting.
  Skills: `input-handling`, `component-system`
- [x] Training targets and HUD.
  Skills: `component-system`, `godot-ui`, `hud-system`
- [x] Scene smoke test and final review.
  Skills: `godot-testing`, `godot-code-review`
