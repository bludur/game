class_name SurvivalHud
extends CanvasLayer

signal craft_requested(recipe_id: StringName)
signal ritual_requested(ritual_id: StringName)
signal interface_open_changed(open: bool)

var _session: WorldSession
var _inventory: InventoryComponent
var _selected_slot: int = -1
var _slot_buttons: Array[Button] = []
var _notification_tween: Tween

@onready var _health_bar: ProgressBar = get_node("Root/Status/Content/HealthBar") as ProgressBar
@onready var _health_label: Label = get_node("Root/Status/Content/HealthLabel") as Label
@onready var _mana_bar: ProgressBar = get_node("Root/Status/Content/ManaBar") as ProgressBar
@onready var _mana_label: Label = get_node("Root/Status/Content/ManaLabel") as Label
@onready var _stamina_bar: ProgressBar = get_node("Root/Status/Content/StaminaBar") as ProgressBar
@onready var _stamina_label: Label = get_node("Root/Status/Content/StaminaLabel") as Label
@onready var _corruption_bar: ProgressBar = get_node("Root/Status/Content/CorruptionBar") as ProgressBar
@onready var _corruption_label: Label = get_node("Root/Status/Content/CorruptionLabel") as Label
@onready var _corruption_reason: Label = get_node("Root/Status/Content/CorruptionReason") as Label
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
@onready var _split_button: Button = get_node("Root/SurvivalWindow/Layout/Tabs/Inventory/Content/Actions/Split") as Button
@onready var _drop_button: Button = get_node("Root/SurvivalWindow/Layout/Tabs/Inventory/Content/Actions/Drop") as Button
@onready var _map_panel: PanelContainer = get_node("Root/MapPanel") as PanelContainer
@onready var _map: SurvivalMap = get_node("Root/MapPanel/Map") as SurvivalMap
@onready var _build_label: Label = get_node("Root/BuildInfo") as Label
@onready var _crosshair: Label = get_node("Root/Crosshair") as Label
@onready var _notification_timer: Timer = get_node("NotificationTimer") as Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tabs.set_tab_title(0, tr("SURVIVAL_INVENTORY"))
	_tabs.set_tab_title(1, tr("SURVIVAL_CRAFTING"))
	_tabs.set_tab_title(2, tr("SURVIVAL_RITUALS"))
	_survival_window.visible = false
	_map_panel.visible = false
	_prompt.visible = false
	_build_label.visible = false
	_notification.modulate.a = 0.0
	_split_button.pressed.connect(_split_selected_stack)
	_drop_button.pressed.connect(_drop_selected_item)
	(get_node("Root/SurvivalWindow/Layout/Header/Close") as Button).pressed.connect(_close_interfaces)
	_notification_timer.timeout.connect(_hide_notification)


func bind(session: WorldSession) -> void:
	_session = session
	_inventory = session.player.get_inventory_component()
	_build_inventory_grid()
	_build_recipe_list()
	_build_ritual_list()
	_map.bind(session.player, session.world_state)
	_inventory.inventory_changed.connect(_refresh_inventory)
	session.player.get_health_component().health_changed.connect(_on_health_changed)
	session.player.get_mana_component().mana_changed.connect(_on_mana_changed)
	session.player.get_stamina_component().stamina_changed.connect(_on_stamina_changed)
	session.player.get_corruption_component().corruption_changed.connect(_on_corruption_changed)
	session.world_clock.time_changed.connect(_on_time_changed)
	session.threat_director.threat_changed.connect(_on_threat_changed)
	session.interaction_controller.focus_changed.connect(_on_interaction_focus_changed)
	session.construction_system.build_mode_changed.connect(_on_build_mode_changed)
	session.construction_system.selection_changed.connect(_on_build_selection_changed)
	session.notification_requested.connect(show_notification)
	var health: HealthComponent = session.player.get_health_component()
	var mana: ManaComponent = session.player.get_mana_component()
	var stamina: StaminaComponent = session.player.get_stamina_component()
	var corruption: CorruptionComponent = session.player.get_corruption_component()
	_on_health_changed(health.current_health, health.max_health)
	_on_mana_changed(mana.current_mana, mana.max_mana)
	_on_stamina_changed(stamina.current_stamina, stamina.max_stamina)
	_on_corruption_changed(corruption.current_corruption, corruption.maximum_corruption, &"safe")
	_on_time_changed(session.world_clock.normalized_time, session.world_clock.day_number)
	_refresh_inventory()
	_refresh_objective()


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
	_refresh_recipe_availability()


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


func _toggle_survival_window(tab_index: int) -> void:
	var should_open: bool = not _survival_window.visible or _tabs.current_tab != tab_index
	_map_panel.visible = false
	_survival_window.visible = should_open
	if should_open:
		_tabs.current_tab = tab_index
		_refresh_inventory()
		if tab_index == 0 and not _slot_buttons.is_empty():
			_slot_buttons[0].grab_focus()
	_emit_interface_state()


func _toggle_map() -> void:
	var should_open: bool = not _map_panel.visible
	_survival_window.visible = false
	_map_panel.visible = should_open
	_emit_interface_state()


func _close_interfaces() -> void:
	_survival_window.visible = false
	_map_panel.visible = false
	_emit_interface_state()


func _emit_interface_state() -> void:
	interface_open_changed.emit(_survival_window.visible or _map_panel.visible)


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


func _on_corruption_changed(current: float, maximum: float, reason: StringName) -> void:
	_corruption_bar.max_value = maximum
	_corruption_bar.value = current
	_corruption_label.text = tr("SURVIVAL_CORRUPTION") % floori(current)
	_corruption_reason.text = tr("CORRUPTION_REASON_%s" % String(reason).to_upper())


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
	if active:
		_close_interfaces()
		_on_build_selection_changed(_session.construction_system.get_selected_piece())


func _on_build_selection_changed(piece: BuildingPieceData) -> void:
	if piece != null:
		_build_label.text = tr("SURVIVAL_BUILD") % _building_name(piece)


func _refresh_objective() -> void:
	if _session.world_state.has_progression_flag(&"matriarch_defeated"):
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
