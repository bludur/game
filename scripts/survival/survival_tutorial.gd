class_name SurvivalTutorial
extends Node

signal hint_requested(message: String)

const FINAL_STEP: int = 6

var current_step: int = 0
var _world_state: WorldState


func bind(
	world_state: WorldState,
	inventory: InventoryComponent,
	crafting_system: CraftingSystem,
	construction_system: ConstructionSystem,
	hearth: WitchfireHearth,
	world_clock: WorldClock,
	ritual_system: RitualSystem
) -> void:
	_world_state = world_state
	_sync_from_state()
	inventory.item_added.connect(_on_item_added)
	crafting_system.crafting_succeeded.connect(_on_crafting_succeeded)
	construction_system.piece_built.connect(_on_piece_built)
	hearth.rest_requested.connect(_on_hearth_bound)
	world_clock.phase_changed.connect(_on_phase_changed)
	ritual_system.ritual_completed.connect(_on_ritual_completed)
	world_state.state_changed.connect(_sync_from_state)
	call_deferred("_show_current_hint")


func _on_item_added(_item: ItemData, _quantity: int) -> void:
	if current_step == 0:
		_advance()


func _on_crafting_succeeded(_recipe: RecipeData) -> void:
	if current_step == 1:
		_advance()


func _on_piece_built(_piece: BuildingPiece) -> void:
	if current_step == 2:
		_advance()


func _on_hearth_bound(_hearth: WitchfireHearth, _player: MagePlayer) -> void:
	if current_step == 3:
		_advance()


func _on_phase_changed(phase: WorldClock.Phase) -> void:
	if current_step == 4 and phase == WorldClock.Phase.NIGHT:
		_advance()


func _on_ritual_completed(_ritual: RitualData) -> void:
	if current_step == 5:
		_advance()


func _advance() -> void:
	current_step = mini(current_step + 1, FINAL_STEP)
	if _world_state != null:
		_world_state.set_progression_flag(StringName("tutorial_step_%d" % current_step))
	_show_current_hint()


func _sync_from_state() -> void:
	if _world_state == null:
		return
	var restored_step: int = 0
	for step: int in range(1, FINAL_STEP + 1):
		if _world_state.has_progression_flag(StringName("tutorial_step_%d" % step)):
			restored_step = step
	current_step = maxi(current_step, restored_step)


func _show_current_hint() -> void:
	hint_requested.emit(tr("SURVIVAL_TUTORIAL_%d" % current_step))
