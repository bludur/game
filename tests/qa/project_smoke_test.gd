extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const ARCANE_BOLT: SpellData = preload("res://resources/spells/arcane_bolt.tres")


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var failures: Array[String] = []
	var feature_tags: PackedStringArray = ProjectSettings.get_setting(
		"application/config/features",
		PackedStringArray()
	) as PackedStringArray
	if not feature_tags.has("Forward Plus"):
		failures.append("Forward Plus is not selected in project features.")
	if not bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false)):
		failures.append("Physics interpolation is disabled.")
	for bus_name: StringName in [&"Music", &"SFX", &"Ambience"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			failures.append("Missing audio bus: %s." % bus_name)

	var main_scene: PackedScene = MAIN_SCENE
	if main_scene == null:
		failures.append("Main scene could not be loaded.")
	else:
		var main_instance: Node = main_scene.instantiate()
		root.add_child(main_instance)
		await process_frame
		await physics_frame

		var player: Node = get_first_node_in_group(&"player")
		if player == null:
			failures.append("Player group has no member.")
		elif player is MagePlayer:
			var mage: MagePlayer = player as MagePlayer
			var mana: ManaComponent = mage.get_mana_component()
			var caster: SpellCaster = mage.get_spell_caster()
			var loadout: SpellLoadout = mage.get_spell_loadout()
			var dash: DashComponent = mage.get_dash_component()
			if loadout.get_spell(0) == null or loadout.get_spell(1) == null:
				failures.append("Player spell loadout does not contain two spells.")
			if dash == null:
				failures.append("Player dash component is missing.")
			var mana_before: float = mana.current_mana
			if not caster.cast_at(mage.global_position + Vector3(0.0, 0.0, -4.0)):
				failures.append("Arcane Bolt could not be cast through the public API.")
			elif not is_equal_approx(mana.current_mana, mana_before - caster.spell_data.mana_cost):
				failures.append("Casting Arcane Bolt did not spend mana.")
		else:
			failures.append("Player group member is not a MagePlayer.")
		if root.get_camera_3d() == null:
			failures.append("No active Camera3D was found.")
		if main_instance.get_node_or_null("ArenaAudioDirector") == null:
			failures.append("Arena audio director is missing.")
		if get_nodes_in_group(&"training_target").size() != 3:
			failures.append("Expected three training targets in the main scene.")
		var enemies: Array[Node] = get_nodes_in_group(&"enemy")
		if enemies.size() != 1 or enemies[0] is not ChaserEnemy:
			failures.append("Expected one ChaserEnemy in the main scene.")
		var navigation_region: ArenaNavigation = main_instance.get_node_or_null("ArenaNavigation") as ArenaNavigation
		if navigation_region == null or navigation_region.navigation_mesh == null:
			failures.append("Arena navigation mesh was not created.")
		elif navigation_region.navigation_mesh.get_polygon_count() == 0:
			failures.append("Arena navigation mesh has no walkable polygons.")
		if get_nodes_in_group(&"projectile").is_empty():
			failures.append("Arcane Bolt projectile was not spawned.")

		main_instance.queue_free()
		await process_frame

	var spell: Resource = ARCANE_BOLT
	if spell == null:
		failures.append("Arcane Bolt resource could not be loaded.")
	elif not bool(spell.call("is_valid_definition")):
		failures.append("Arcane Bolt definition is invalid.")

	if failures.is_empty():
		print("SMOKE TEST PASSED")
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)
