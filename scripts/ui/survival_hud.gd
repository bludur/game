class_name SurvivalHud
extends CanvasLayer

signal craft_requested(recipe_id: StringName)
signal ritual_requested(ritual_id: StringName)
signal interface_open_changed(open: bool)

var _session: WorldSession
var _inventory: InventoryComponent
var _equipment: EquipmentComponent
var _selected_slot: int = -1
var _slot_buttons: Array[Button] = []
var _notification_tween: Tween
var _build_category_buttons: Array[Button] = []
var _storage_piece: BuildingPiece
var _grimoire_buttons: Array[Button] = []
var _selected_grimoire_node_id: StringName = &""

@onready var _health_bar: ProgressBar = get_node("Root/Status/Content/HealthBar") as ProgressBar
@onready var _health_label: Label = get_node("Root/Status/Content/HealthLabel") as Label
@onready var _mana_bar: ProgressBar = get_node("Root/Status/Content/ManaBar") as ProgressBar
@onready var _mana_label: Label = get_node("Root/Status/Content/ManaLabel") as Label
@onready var _stamina_bar: ProgressBar = get_node("Root/Status/Content/StaminaBar") as ProgressBar
@onready var _stamina_label: Label = get_node("Root/Status/Content/StaminaLabel") as Label
@onready var _ward_label: Label = get_node("Root/Status/Content/WardLabel") as Label
@onready var _corruption_bar: ProgressBar = get_node("Root/Status/Content/CorruptionBar") as ProgressBar
@onready var _corruption_label: Label = get_node("Root/Status/Content/CorruptionLabel") as Label
@onready var _corruption_reason: Label = get_node("Root/Status/Content/CorruptionReason") as Label
@onready var _cold_bar: ProgressBar = get_node("Root/Status/Content/ColdBar") as ProgressBar
@onready var _cold_label: Label = get_node("Root/Status/Content/ColdLabel") as Label
@onready var _time_label: Label = get_node("Root/WorldInfo/Content/Time") as Label
@onready var _threat_label: Label = get_node("Root/WorldInfo/Content/Threat") as Label
@onready var _objective_label: Label = get_node("Root/Objective") as Label
@onready var _prompt: Label = get_node("Root/InteractionPrompt") as Label
@onready var _notification: Label = get_node("Root/Notification") as Label
@onready var _survival_window: PanelContainer = get_node("Root/SurvivalWindow") as PanelContainer
@onready var _tabs: TabContainer = get_node("Root/SurvivalWindow/Layout/Tabs") as TabContainer
@onready var _inventory_grid: GridContainer = get_node("Root/SurvivalWindow/Layout/Tabs/Inventory/Content/Grid") as GridContainer
@onready var _crafting_list: VBoxContainer = get_node("Root/SurvivalWindow/Layout/Tabs/Crafting/Scroll/List") as VBoxContainer
@onready var _ritual_list: VBoxContainer = get_node("Root/SurvivalWindow/Layout/Tabs/Rituals/Scroll/List") as VBoxContainer
@onready var _grimoire_list: VBoxContainer = get_node("Root/SurvivalWindow/Layout/Tabs/Grimoire/Columns/Tree/Scroll/List") as VBoxContainer
@onready var _grimoire_title: Label = get_node("Root/SurvivalWindow/Layout/Tabs/Grimoire/Columns/Details/NodeTitle") as Label
@onready var _grimoire_details: Label = get_node("Root/SurvivalWindow/Layout/Tabs/Grimoire/Columns/Details/NodeDetails") as Label
@onready var _grimoire_unlock: Button = get_node("Root/SurvivalWindow/Layout/Tabs/Grimoire/Columns/Details/Actions/Unlock") as Button
@onready var _grimoire_activate: Button = get_node("Root/SurvivalWindow/Layout/Tabs/Grimoire/Columns/Details/Actions/Activate") as Button
@onready var _grimoire_journal: Label = get_node("Root/SurvivalWindow/Layout/Tabs/Grimoire/Columns/Details/Journal") as Label
@onready var _grimoire_respec: Button = get_node("Root/SurvivalWindow/Layout/Tabs/Grimoire/Columns/Details/Respec") as Button
@onready var _split_button: Button = get_node("Root/SurvivalWindow/Layout/Tabs/Inventory/Content/Actions/Split") as Button
@onready var _drop_button: Button = get_node("Root/SurvivalWindow/Layout/Tabs/Inventory/Content/Actions/Drop") as Button
@onready var _use_button: Button = get_node("Root/SurvivalWindow/Layout/Tabs/Inventory/Content/Actions/Use") as Button
@onready var _equip_button: Button = get_node("Root/SurvivalWindow/Layout/Tabs/Inventory/Content/Actions/Equip") as Button
@onready var _focus_button: Button = get_node("Root/SurvivalWindow/Layout/Tabs/Inventory/Content/Equipment/Slots/Focus") as Button
@onready var _robe_button: Button = get_node("Root/SurvivalWindow/Layout/Tabs/Inventory/Content/Equipment/Slots/Robe") as Button
@onready var _talisman_button: Button = get_node("Root/SurvivalWindow/Layout/Tabs/Inventory/Content/Equipment/Slots/Talisman") as Button
@onready var _equipment_comparison: Label = get_node("Root/SurvivalWindow/Layout/Tabs/Inventory/Content/Equipment/Comparison") as Label
@onready var _map_panel: PanelContainer = get_node("Root/MapPanel") as PanelContainer
@onready var _map: SurvivalMap = get_node("Root/MapPanel/Map") as SurvivalMap
@onready var _build_label: Label = get_node("Root/BuildInfo") as Label
@onready var _build_panel: PanelContainer = get_node("Root/BuildPanel") as PanelContainer
@onready var _storage_window: PanelContainer = get_node("Root/StorageWindow") as PanelContainer
@onready var _storage_title: Label = get_node("Root/StorageWindow/Layout/Header/Title") as Label
@onready var _storage_inventory_list: VBoxContainer = get_node("Root/StorageWindow/Layout/Columns/Inventory/Scroll/List") as VBoxContainer
@onready var _storage_chest_list: VBoxContainer = get_node("Root/StorageWindow/Layout/Columns/Chest/Scroll/List") as VBoxContainer
@onready var _crosshair: Label = get_node("Root/Crosshair") as Label
@onready var _active_effects_panel: PanelContainer = get_node("Root/ActiveEffects") as PanelContainer
@onready var _active_effects_label: Label = get_node("Root/ActiveEffects/Content") as Label
@onready var _notification_timer: Timer = get_node("NotificationTimer") as Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tabs.set_tab_title(0, tr("SURVIVAL_INVENTORY"))
	_tabs.set_tab_title(1, tr("SURVIVAL_CRAFTING"))
	_tabs.set_tab_title(2, tr("SURVIVAL_RITUALS"))
	_tabs.set_tab_title(3, tr("SURVIVAL_GRIMOIRE"))
	_survival_window.visible = false
	_map_panel.visible = false
	_prompt.visible = false
	_build_label.visible = false
	_build_panel.visible = false
	_storage_window.visible = false
	_notification.modulate.a = 0.0
	_build_category_buttons = [
		get_node("Root/BuildPanel/Categories/Foundations") as Button,
		get_node("Root/BuildPanel/Categories/Walls") as Button,
		get_node("Root/BuildPanel/Categories/Roofs") as Button,
		get_node("Root/BuildPanel/Categories/Stations") as Button,
		get_node("Root/BuildPanel/Categories/Magic") as Button,
	]
	for category: int in _build_category_buttons.size():
		_build_category_buttons[category].text = "[%d] %s" % [category + 1, tr(_category_key(category))]
		_build_category_buttons[category].pressed.connect(_select_build_category.bind(category))
	_split_button.pressed.connect(_split_selected_stack)
	_drop_button.pressed.connect(_drop_selected_item)
	_use_button.pressed.connect(_use_selected_preparation)
	_equip_button.pressed.connect(_equip_selected_item)
	_focus_button.pressed.connect(_unequip_slot.bind(EquipmentData.Slot.FOCUS))
	_robe_button.pressed.connect(_unequip_slot.bind(EquipmentData.Slot.ROBE))
	_talisman_button.pressed.connect(_unequip_slot.bind(EquipmentData.Slot.TALISMAN))
	_grimoire_unlock.pressed.connect(_unlock_selected_grimoire_node)
	_grimoire_activate.pressed.connect(_toggle_selected_grimoire_node)
	_grimoire_respec.pressed.connect(_request_grimoire_respec)
	(get_node("Root/SurvivalWindow/Layout/Header/Close") as Button).pressed.connect(_close_interfaces)
	(get_node("Root/StorageWindow/Layout/Header/Close") as Button).pressed.connect(_close_storage)
	_notification_timer.timeout.connect(_hide_notification)


func bind(session: WorldSession) -> void:
	_session = session
	_inventory = session.player.get_inventory_component()
	_equipment = session.player.get_equipment_component()
	_build_inventory_grid()
	_build_recipe_list()
	_build_ritual_list()
	_build_grimoire_list()
	_map.bind(session.player, session.world_state, session.region.poi_catalog)
	_inventory.inventory_changed.connect(_refresh_inventory)
	session.grimoire.fragment_discovered.connect(_on_grimoire_changed.unbind(1))
	session.grimoire.node_unlocked.connect(_on_grimoire_changed.unbind(1))
	session.grimoire.active_nodes_changed.connect(_on_grimoire_changed.unbind(1))
	session.grimoire.recipe_unlocked.connect(_on_grimoire_changed.unbind(1))
	session.world_state.state_changed.connect(_refresh_grimoire)
	_equipment.equipment_changed.connect(_on_equipment_changed)
	session.player.get_health_component().health_changed.connect(_on_health_changed)
	session.player.get_mana_component().mana_changed.connect(_on_mana_changed)
	session.player.get_stamina_component().stamina_changed.connect(_on_stamina_changed)
	session.player.get_ward_component().active_changed.connect(_on_ward_active_changed)
	session.player.get_status_effect_component().effects_changed.connect(_on_effects_changed)
	session.player.get_corruption_component().corruption_changed.connect(_on_corruption_changed)
	session.cold_exposure.exposure_changed.connect(_on_cold_exposure_changed)
	session.world_clock.time_changed.connect(_on_time_changed)
	session.threat_director.threat_changed.connect(_on_threat_changed)
	session.interaction_controller.focus_changed.connect(_on_interaction_focus_changed)
	session.construction_system.build_mode_changed.connect(_on_build_mode_changed)
	session.construction_system.selection_changed.connect(_on_build_selection_changed)
	session.construction_system.category_changed.connect(_on_build_category_changed)
	session.notification_requested.connect(show_notification)
	var health: HealthComponent = session.player.get_health_component()
	var mana: ManaComponent = session.player.get_mana_component()
	var stamina: StaminaComponent = session.player.get_stamina_component()
	var corruption: CorruptionComponent = session.player.get_corruption_component()
	_on_health_changed(health.current_health, health.max_health)
	_on_mana_changed(mana.current_mana, mana.max_mana)
	_on_stamina_changed(stamina.current_stamina, stamina.max_stamina)
	_on_ward_active_changed(session.player.get_ward_component().is_active)
	_on_effects_changed(session.player.get_status_effect_component().active_effects)
	_on_corruption_changed(corruption.current_corruption, corruption.maximum_corruption, &"safe")
	_on_cold_exposure_changed(
		session.cold_exposure.current_exposure,
		session.cold_exposure.maximum_exposure,
		false
	)
	_on_time_changed(session.world_clock.normalized_time, session.world_clock.day_number)
	_refresh_inventory()
	_refresh_equipment()
	_refresh_objective()
	_refresh_grimoire()
	_on_build_category_changed(session.construction_system.active_category)


func _process(_delta: float) -> void:
	if _session != null and _session.construction_system.build_mode:
		_refresh_build_label()


func _unhandled_input(event: InputEvent) -> void:
	if _session == null:
		return
	if event.is_action_pressed(&"inventory"):
		_toggle_survival_window(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"crafting"):
		_toggle_survival_window(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ritual") and not _session.construction_system.build_mode:
		_toggle_survival_window(2)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"grimoire"):
		_toggle_survival_window(3)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"region_map"):
		_toggle_map()
		get_viewport().set_input_as_handled()


func show_notification(message: String) -> void:
	_notification.text = message
	if _notification_tween != null:
		_notification_tween.kill()
	_notification.modulate.a = 0.0
	_notification_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_notification_tween.tween_property(_notification, "modulate:a", 1.0, 0.18)
	_notification_timer.start(3.2)
	_refresh_objective()


func rebind_region() -> void:
	if _session == null:
		return
	_map.bind(_session.player, _session.world_state, _session.region.poi_catalog)
	_session.cold_exposure.refresh()
	_refresh_objective()
	_refresh_grimoire()


func _build_inventory_grid() -> void:
	for child: Node in _inventory_grid.get_children():
		child.queue_free()
	_slot_buttons.clear()
	for index: int in _inventory.capacity:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(116, 54)
		button.focus_mode = Control.FOCUS_ALL
		button.toggle_mode = true
		button.pressed.connect(_on_slot_pressed.bind(index))
		_inventory_grid.add_child(button)
		_slot_buttons.append(button)


func _build_recipe_list() -> void:
	for recipe: RecipeData in _session.crafting_system.catalog.recipes:
		var button: Button = Button.new()
		button.custom_minimum_size.y = 52.0
		button.text = _recipe_name(recipe) + "\n" + _ingredient_text(recipe.ingredients)
		button.tooltip_text = _recipe_name(recipe)
		button.pressed.connect(craft_requested.emit.bind(recipe.recipe_id))
		_crafting_list.add_child(button)


func _build_ritual_list() -> void:
	for ritual: RitualData in _session.ritual_system.catalog.rituals:
		var button: Button = Button.new()
		button.custom_minimum_size.y = 58.0
		button.text = _ritual_name(ritual) + "\n" + _ritual_preview(ritual)
		button.tooltip_text = _ingredient_text(ritual.ingredients)
		button.pressed.connect(ritual_requested.emit.bind(ritual.ritual_id))
		_ritual_list.add_child(button)


func _build_grimoire_list() -> void:
	_grimoire_buttons.clear()
	for child: Node in _grimoire_list.get_children():
		child.queue_free()
	if _session.grimoire.definition == null:
		return
	for node_data: KnowledgeNodeData in _session.grimoire.definition.nodes:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(285, 54)
		button.focus_mode = Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_grimoire_node.bind(node_data.node_id))
		_grimoire_list.add_child(button)
		_grimoire_buttons.append(button)


func _refresh_inventory() -> void:
	if _inventory == null:
		return
	for index: int in mini(_slot_buttons.size(), _inventory.slots.size()):
		var button: Button = _slot_buttons[index]
		var slot: InventorySlot = _inventory.slots[index]
		if slot.is_empty():
			button.text = "—"
			button.tooltip_text = tr("SURVIVAL_EMPTY_SLOT")
			button.modulate = Color.WHITE
		else:
			button.text = "%s\n×%d" % [_item_name(slot.item), slot.quantity]
			button.tooltip_text = _item_description(slot.item)
			button.modulate = Color.WHITE.lerp(slot.item.accent_color, 0.18)
		button.button_pressed = index == _selected_slot
	_use_button.disabled = _selected_slot < 0 \
		or _inventory.slots[_selected_slot].is_empty() \
		or _inventory.slots[_selected_slot].item.preparation_effect == null
	_equip_button.disabled = _selected_slot < 0 \
		or _inventory.slots[_selected_slot].is_empty() \
		or _inventory.slots[_selected_slot].item.equipment == null
	_refresh_equipment_comparison()
	_refresh_recipe_availability()
	if _storage_window.visible:
		_refresh_storage()


func _refresh_recipe_availability() -> void:
	for index: int in mini(_crafting_list.get_child_count(), _session.crafting_system.catalog.recipes.size()):
		var recipe: RecipeData = _session.crafting_system.catalog.recipes[index]
		var button: Button = _crafting_list.get_child(index) as Button
		button.disabled = not _session.grimoire.is_recipe_unlocked(recipe.recipe_id) \
			or not recipe.can_craft(_inventory)
	for index: int in mini(_ritual_list.get_child_count(), _session.ritual_system.catalog.rituals.size()):
		var ritual: RitualData = _session.ritual_system.catalog.rituals[index]
		var button: Button = _ritual_list.get_child(index) as Button
		button.disabled = _session.world_state.has_ritual_flag(ritual.result_flag) \
			or not ritual.can_perform(_inventory)


func _on_slot_pressed(index: int) -> void:
	if _selected_slot < 0:
		_selected_slot = index
	elif _selected_slot == index:
		_selected_slot = -1
	else:
		_inventory.swap_slots(_selected_slot, index)
		_selected_slot = -1
	_refresh_inventory()


func _split_selected_stack() -> void:
	if _selected_slot < 0:
		return
	for index: int in _inventory.slots.size():
		if _inventory.slots[index].is_empty() and _inventory.split_stack(_selected_slot, index):
			_selected_slot = -1
			return


func _drop_selected_item() -> void:
	if _selected_slot >= 0 and _inventory.request_drop(_selected_slot, 1):
		_selected_slot = -1


func _use_selected_preparation() -> void:
	if _selected_slot >= 0 and _session.use_preparation_from_slot(_selected_slot):
		_selected_slot = -1
		_refresh_inventory()


func _equip_selected_item() -> void:
	if _selected_slot >= 0 and _equipment.equip_from_inventory(_selected_slot):
		_selected_slot = -1
		_refresh_inventory()


func _unequip_slot(slot: EquipmentData.Slot) -> void:
	if _equipment.unequip(slot, true):
		_refresh_inventory()


func _on_equipment_changed(_slot: EquipmentData.Slot, _item: ItemData) -> void:
	_refresh_equipment()
	_refresh_equipment_comparison()


func _refresh_equipment() -> void:
	if _equipment == null:
		return
	_focus_button.text = _equipment_slot_text(
		tr("EQUIPMENT_FOCUS"),
		_equipment.get_equipped_item(EquipmentData.Slot.FOCUS)
	)
	_robe_button.text = _equipment_slot_text(
		tr("EQUIPMENT_ROBE"),
		_equipment.get_equipped_item(EquipmentData.Slot.ROBE)
	)
	_talisman_button.text = _equipment_slot_text(
		tr("EQUIPMENT_TALISMAN"),
		_equipment.get_equipped_item(EquipmentData.Slot.TALISMAN)
	)


func _refresh_equipment_comparison() -> void:
	if _equipment == null or _selected_slot < 0 or _inventory.slots[_selected_slot].is_empty():
		_equipment_comparison.text = tr("EQUIPMENT_SELECT_HINT")
		return
	var candidate: ItemData = _inventory.slots[_selected_slot].item
	if candidate.equipment == null:
		_equipment_comparison.text = tr("EQUIPMENT_SELECT_HINT")
		return
	var current: ItemData = _equipment.get_equipped_item(candidate.equipment.slot)
	var current_name: String = tr("EQUIPMENT_EMPTY") if current == null else _item_name(current)
	_equipment_comparison.text = tr("EQUIPMENT_COMPARE") % [
		_item_name(candidate),
		current_name,
		_equipment_summary(candidate.equipment),
	]


func _equipment_slot_text(slot_name: String, item: ItemData) -> String:
	return "%s\n%s" % [slot_name, tr("EQUIPMENT_EMPTY") if item == null else _item_name(item)]


func _equipment_summary(equipment: EquipmentData) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if not is_equal_approx(equipment.cooldown_multiplier, 1.0):
		parts.append(tr("EQUIPMENT_STAT_COOLDOWN") % roundi((equipment.cooldown_multiplier - 1.0) * 100.0))
	if not is_equal_approx(equipment.damage_multiplier, 1.0):
		parts.append(tr("EQUIPMENT_STAT_DAMAGE") % roundi((equipment.damage_multiplier - 1.0) * 100.0))
	if not is_equal_approx(equipment.incoming_damage_multiplier, 1.0):
		parts.append(tr("EQUIPMENT_STAT_DEFENSE") % roundi((1.0 - equipment.incoming_damage_multiplier) * 100.0))
	if not is_equal_approx(equipment.area_radius_multiplier, 1.0):
		parts.append(tr("EQUIPMENT_STAT_AREA") % roundi((equipment.area_radius_multiplier - 1.0) * 100.0))
	if not is_equal_approx(equipment.effect_duration_multiplier, 1.0):
		parts.append(tr("EQUIPMENT_STAT_DURATION") % roundi((equipment.effect_duration_multiplier - 1.0) * 100.0))
	if equipment.corruption_per_cast > 0.0:
		parts.append(tr("EQUIPMENT_STAT_CORRUPTION") % equipment.corruption_per_cast)
	if equipment.condition != EquipmentData.Condition.ALWAYS:
		parts.append(tr("EQUIPMENT_CONDITIONAL"))
	return tr("EQUIPMENT_NO_DIRECT_STATS") if parts.is_empty() else ", ".join(parts)


func _toggle_survival_window(tab_index: int) -> void:
	var should_open: bool = not _survival_window.visible or _tabs.current_tab != tab_index
	_map_panel.visible = false
	_storage_window.visible = false
	_storage_piece = null
	_survival_window.visible = should_open
	if should_open:
		_tabs.current_tab = tab_index
		_refresh_inventory()
		if tab_index == 3:
			_refresh_grimoire()
		if tab_index == 0 and not _slot_buttons.is_empty():
			_slot_buttons[0].grab_focus()
		elif tab_index == 3 and not _grimoire_buttons.is_empty():
			_grimoire_buttons[0].grab_focus()
	_emit_interface_state()


func _select_grimoire_node(node_id: StringName) -> void:
	_selected_grimoire_node_id = node_id
	_refresh_grimoire()


func _unlock_selected_grimoire_node() -> void:
	if _session.grimoire.unlock_node(_selected_grimoire_node_id):
		show_notification(tr("NOTICE_GRIMOIRE_NODE_UNLOCKED"))
	else:
		show_notification(_session.grimoire.get_unlock_hint(_selected_grimoire_node_id))
	_refresh_grimoire()


func _toggle_selected_grimoire_node() -> void:
	if not _session.grimoire.toggle_node(_selected_grimoire_node_id):
		show_notification(tr("NOTICE_GRIMOIRE_INVALID_LOADOUT"))
	_refresh_grimoire()


func _request_grimoire_respec() -> void:
	_session.request_grimoire_respec()
	_refresh_grimoire()


func _on_grimoire_changed() -> void:
	_refresh_grimoire()
	_refresh_recipe_availability()


func _refresh_grimoire() -> void:
	if _session == null or _session.grimoire.definition == null:
		return
	var grimoire: GrimoireState = _session.grimoire
	if _selected_grimoire_node_id.is_empty() and not grimoire.definition.nodes.is_empty():
		var next_node: KnowledgeNodeData = grimoire.get_next_achievable_node()
		_selected_grimoire_node_id = next_node.node_id \
			if next_node != null else grimoire.definition.nodes[0].node_id
	for index: int in mini(_grimoire_buttons.size(), grimoire.definition.nodes.size()):
		var node_data: KnowledgeNodeData = grimoire.definition.nodes[index]
		var button: Button = _grimoire_buttons[index]
		var marker: String = "◆" if grimoire.active_node_ids.has(node_data.node_id) else (
			"✓" if grimoire.unlocked_nodes.has(node_data.node_id) else "·"
		)
		button.text = "%s %s  ·  ступень %s" % [
			marker, _school_name(node_data.school), "I".repeat(node_data.knowledge_level),
		]
		button.tooltip_text = node_data.display_name
		button.modulate = Color(0.78, 0.66, 1.0, 1.0) \
			if grimoire.get_unlock_status(node_data.node_id) == &"ready" else Color.WHITE
	var selected: KnowledgeNodeData = grimoire.definition.get_node_data(_selected_grimoire_node_id)
	if selected == null:
		return
	_grimoire_title.text = "%s · %s %d" % [
		selected.display_name, _school_name(selected.school), selected.knowledge_level,
	]
	_grimoire_details.text = "%s\n\n%s\n\n%s" % [
		selected.effect_summary(),
		_reward_text(selected),
		grimoire.get_unlock_hint(selected.node_id),
	]
	var unlocked: bool = grimoire.unlocked_nodes.has(selected.node_id)
	var active: bool = grimoire.active_node_ids.has(selected.node_id)
	_grimoire_unlock.visible = not unlocked
	_grimoire_unlock.disabled = not grimoire.can_unlock_node(selected.node_id)
	_grimoire_activate.visible = unlocked
	_grimoire_activate.text = tr("GRIMOIRE_DEACTIVATE") if active else tr("GRIMOIRE_ACTIVATE")
	_grimoire_journal.text = _journal_text()
	_grimoire_respec.text = tr("GRIMOIRE_RESPEC") % [
		grimoire.definition.respec_item_quantity,
	]
	_grimoire_respec.disabled = grimoire.active_node_ids.is_empty()


func _journal_text() -> String:
	var lines: PackedStringArray = PackedStringArray([tr("GRIMOIRE_JOURNAL")])
	for entry: Dictionary in _session.progress_journal.get_entries():
		lines.append("\n• %s\n  %s" % [String(entry.get("title", "")), String(entry.get("hint", ""))])
	return "\n".join(lines)


func _reward_text(node_data: KnowledgeNodeData) -> String:
	var reward_kind: String = ["заклинание", "модификатор", "ритуал", "рецепт экипировки"][node_data.reward_kind]
	return "Награда: %s · %s" % [reward_kind, String(node_data.reward_id)]


func _school_name(school: SpellModifierData.School) -> String:
	return ["Тайная", "Мороз", "Буря", "Запретная"][school]


func _toggle_map() -> void:
	var should_open: bool = not _map_panel.visible
	_survival_window.visible = false
	_storage_window.visible = false
	_storage_piece = null
	_map_panel.visible = should_open
	_emit_interface_state()


func _close_interfaces() -> void:
	_survival_window.visible = false
	_map_panel.visible = false
	_storage_window.visible = false
	_storage_piece = null
	_emit_interface_state()


func _emit_interface_state() -> void:
	interface_open_changed.emit(
		_survival_window.visible or _map_panel.visible or _storage_window.visible
	)


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = tr("SURVIVAL_HEALTH") % [ceili(current), ceili(maximum)]


func _on_mana_changed(current: float, maximum: float) -> void:
	_mana_bar.max_value = maximum
	_mana_bar.value = current
	_mana_label.text = tr("SURVIVAL_MANA") % [floori(current), floori(maximum)]


func _on_stamina_changed(current: float, maximum: float) -> void:
	_stamina_bar.max_value = maximum
	_stamina_bar.value = current
	_stamina_label.text = tr("SURVIVAL_STAMINA") % [floori(current), floori(maximum)]


func _on_ward_active_changed(active: bool) -> void:
	_ward_label.text = tr("HUD_WARD_ACTIVE") if active else tr("HUD_WARD_READY")
	_ward_label.modulate = Color(0.82, 0.56, 1.0, 1.0) if active else Color.WHITE
	_crosshair.modulate = Color(0.82, 0.56, 1.0, 1.0) if active else Color.WHITE


func _on_effects_changed(effects: Array[ActiveStatusEffect]) -> void:
	_active_effects_panel.visible = not effects.is_empty()
	if effects.is_empty():
		_active_effects_label.text = ""
		return
	var lines: PackedStringArray = PackedStringArray([tr("SURVIVAL_ACTIVE_EFFECTS")])
	for active: ActiveStatusEffect in effects:
		var effect_key: String = "STATUS_%s_NAME" % String(active.definition.effect_id).to_upper()
		var effect_name: String = tr(effect_key)
		if effect_name == effect_key:
			effect_name = active.definition.display_name
		var source_key: String = "STATUS_SOURCE_%s" % String(active.definition.source_id).to_upper()
		var source_name: String = tr(source_key)
		if source_name == source_key:
			source_name = String(active.definition.source_id)
		var remaining: int = ceili(active.remaining_seconds)
		lines.append("%s  %d:%02d  ·  %s" % [effect_name, remaining / 60, remaining % 60, source_name])
	_active_effects_label.text = "\n".join(lines)


func _on_corruption_changed(current: float, maximum: float, reason: StringName) -> void:
	_corruption_bar.max_value = maximum
	_corruption_bar.value = current
	_corruption_label.text = tr("SURVIVAL_CORRUPTION") % floori(current)
	_corruption_reason.text = tr("CORRUPTION_REASON_%s" % String(reason).to_upper())


func _on_cold_exposure_changed(current: float, maximum: float, protected: bool) -> void:
	var active: bool = _session != null and _session.get_region_id() == &"moonbound_expanse"
	_cold_bar.visible = active
	_cold_label.visible = active
	_cold_bar.max_value = maximum
	_cold_bar.value = current
	_cold_label.text = tr("SURVIVAL_COLD_PROTECTED") if protected \
		else tr("SURVIVAL_COLD") % floori(current)


func _on_time_changed(_normalized_time: float, day_number: int) -> void:
	_time_label.text = tr("SURVIVAL_TIME") % [day_number, _session.world_clock.get_time_label()]


func _on_threat_changed(score: float) -> void:
	_threat_label.text = tr("SURVIVAL_THREAT") % floori(score)


func _on_interaction_focus_changed(interactable: InteractableComponent) -> void:
	_prompt.visible = is_instance_valid(interactable) and not _survival_window.visible and not _map_panel.visible
	if is_instance_valid(interactable):
		_prompt.text = tr("SURVIVAL_INTERACT") % tr(interactable.prompt_text)


func close_interfaces() -> void:
	_close_interfaces()


func set_crosshair_visible(is_visible: bool) -> void:
	_crosshair.visible = is_visible


func _on_build_mode_changed(active: bool) -> void:
	_build_label.visible = active
	_build_panel.visible = active
	if active:
		_close_interfaces()
		_on_build_selection_changed(_session.construction_system.get_selected_piece())


func _on_build_selection_changed(piece: BuildingPieceData) -> void:
	if piece != null:
		_refresh_build_label()


func _refresh_build_label() -> void:
	var piece: BuildingPieceData = _session.construction_system.get_selected_piece()
	if piece == null:
		return
	var reason_key: String = "BUILD_REASON_%s" % String(
		_session.construction_system.placement_reason
	).to_upper()
	_build_label.text = tr("SURVIVAL_BUILD") % [
		_building_name(piece),
		tr(reason_key),
	]


func _select_build_category(category: int) -> void:
	if _session != null:
		_session.construction_system.select_category(category)


func _on_build_category_changed(category: int) -> void:
	for index: int in _build_category_buttons.size():
		_build_category_buttons[index].disabled = index == category


func _category_key(category: int) -> String:
	match category:
		BuildingPieceData.Category.FOUNDATIONS:
			return "BUILD_FOUNDATIONS"
		BuildingPieceData.Category.WALLS:
			return "BUILD_WALLS"
		BuildingPieceData.Category.ROOFS:
			return "BUILD_ROOFS"
		BuildingPieceData.Category.STATIONS:
			return "BUILD_STATIONS"
		_:
			return "BUILD_MAGIC"


func open_crafting_station(station_name: String) -> void:
	_storage_window.visible = false
	_storage_piece = null
	_map_panel.visible = false
	_survival_window.visible = true
	_tabs.current_tab = 1
	_refresh_inventory()
	show_notification(tr("NOTICE_STATION_OPENED") % station_name)
	_emit_interface_state()


func open_storage(piece: BuildingPiece) -> void:
	if piece == null or piece.piece_data.functional_kind != BuildingPieceData.FunctionalKind.STORAGE:
		return
	_storage_piece = piece
	_survival_window.visible = false
	_map_panel.visible = false
	_storage_window.visible = true
	_storage_title.text = tr("STORAGE_TITLE") % _building_name(piece.piece_data)
	_refresh_storage()
	_emit_interface_state()


func _close_storage() -> void:
	_storage_window.visible = false
	_storage_piece = null
	_emit_interface_state()


func _refresh_storage() -> void:
	_clear_container(_storage_inventory_list)
	_clear_container(_storage_chest_list)
	if not is_instance_valid(_storage_piece):
		_close_storage()
		return
	for slot: InventorySlot in _inventory.slots:
		if slot.is_empty():
			continue
		var inventory_button: Button = Button.new()
		inventory_button.text = "%s  ×%d  →" % [_item_name(slot.item), slot.quantity]
		inventory_button.pressed.connect(_store_one_item.bind(slot.item.item_id))
		_storage_inventory_list.add_child(inventory_button)
	for raw_entry: Variant in _storage_piece.get_storage_entries():
		if raw_entry is not Dictionary:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var item_id: StringName = StringName(String(entry.get("item_id", "")))
		var item: ItemData = _session.item_catalog.get_item(item_id)
		if item == null:
			continue
		var chest_button: Button = Button.new()
		chest_button.text = "←  %s  ×%d" % [_item_name(item), int(entry.get("quantity", 0))]
		chest_button.pressed.connect(_withdraw_one_item.bind(item_id))
		_storage_chest_list.add_child(chest_button)
	if not _has_live_children(_storage_inventory_list):
		_add_empty_label(_storage_inventory_list)
	if not _has_live_children(_storage_chest_list):
		_add_empty_label(_storage_chest_list)


func _store_one_item(item_id: StringName) -> void:
	if is_instance_valid(_storage_piece) and _storage_piece.store_item(_inventory, item_id, 1):
		_refresh_storage()
	else:
		show_notification(tr("NOTICE_STORAGE_FULL"))


func _withdraw_one_item(item_id: StringName) -> void:
	if is_instance_valid(_storage_piece) and _storage_piece.withdraw_item(_inventory, item_id, 1):
		_refresh_storage()
	else:
		show_notification(tr("NOTICE_INVENTORY_FULL"))


func _clear_container(container: Container) -> void:
	for child: Node in container.get_children():
		child.queue_free()


func _has_live_children(container: Container) -> bool:
	for child: Node in container.get_children():
		if not child.is_queued_for_deletion():
			return true
	return false


func _add_empty_label(container: Container) -> void:
	var label: Label = Label.new()
	label.text = tr("SURVIVAL_EMPTY_SLOT")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(label)


func _refresh_objective() -> void:
	if _session.get_region_id() == &"moonbound_expanse" \
			and _session.world_state.has_progression_flag(&"moon_eater_defeated"):
		_objective_label.text = tr("OBJECTIVE_MOON_COMPLETE")
	elif _session.get_region_id() == &"moonbound_expanse" \
			and _session.world_state.has_ritual_flag(&"moon_eclipse_path_open"):
		_objective_label.text = tr("OBJECTIVE_MOON_EATER")
	elif _session.get_region_id() == &"moonbound_expanse":
		_objective_label.text = tr("OBJECTIVE_MOON_RITUAL")
	elif _session.world_state.has_progression_flag(&"matriarch_defeated"):
		_objective_label.text = tr("OBJECTIVE_PORTAL")
	elif _session.world_state.has_progression_flag(&"crypt_puzzle_solved"):
		_objective_label.text = tr("OBJECTIVE_MATRIARCH")
	elif _session.world_state.has_ritual_flag(&"crypt_unsealed"):
		_objective_label.text = tr("OBJECTIVE_CRYPT")
	else:
		_objective_label.text = tr("OBJECTIVE_FIRST_NIGHT")


func _hide_notification() -> void:
	if _notification_tween != null:
		_notification_tween.kill()
	_notification_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_notification_tween.tween_property(_notification, "modulate:a", 0.0, 0.3)


func _ingredient_text(ingredients: Array[ItemAmountData]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for ingredient: ItemAmountData in ingredients:
		parts.append("%s ×%d" % [_item_name(ingredient.item), ingredient.quantity])
	return ", ".join(parts)


func _item_name(item: ItemData) -> String:
	return _translated_content("ITEM_%s_NAME" % String(item.item_id).to_upper(), item.display_name)


func _item_description(item: ItemData) -> String:
	return _translated_content("ITEM_%s_DESC" % String(item.item_id).to_upper(), item.description)


func _recipe_name(recipe: RecipeData) -> String:
	return _translated_content("RECIPE_%s_NAME" % String(recipe.recipe_id).to_upper(), recipe.display_name)


func _ritual_name(ritual: RitualData) -> String:
	return _translated_content("RITUAL_%s_NAME" % String(ritual.ritual_id).to_upper(), ritual.display_name)


func _ritual_preview(ritual: RitualData) -> String:
	return _translated_content("RITUAL_%s_PREVIEW" % String(ritual.ritual_id).to_upper(), ritual.preview_text)


func _building_name(piece: BuildingPieceData) -> String:
	return _translated_content("BUILDING_%s_NAME" % String(piece.piece_id).to_upper(), piece.display_name)


func _translated_content(key: String, fallback: String) -> String:
	var translated: String = tr(key)
	return fallback if translated == key else translated
