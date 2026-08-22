class_name ChainLightning
extends Node3D

signal chain_resolved(targets: Array[HurtboxComponent])

var _source_faction: StringName = &"neutral"
var _caster_body: Node3D

@onready var _resolver: ChainTargetResolver = get_node("TargetResolver") as ChainTargetResolver
@onready var _arc_visuals: MeshInstance3D = get_node("ArcVisuals") as MeshInstance3D
@onready var _sparks: GPUParticles3D = get_node("Sparks") as GPUParticles3D
@onready var _sfx_pool: SfxPool3D = get_node("SfxPool3D") as SfxPool3D
@onready var _lifetime_timer: Timer = get_node("LifetimeTimer") as Timer


func _ready() -> void:
	_lifetime_timer.timeout.connect(queue_free)
	_lifetime_timer.start()


func configure(
	spell: SpellData,
	source_faction: StringName,
	caster_body: Node3D,
	aim_position: Vector3
) -> bool:
	_source_faction = source_faction
	_caster_body = caster_body
	var candidates: Array[HurtboxComponent] = []
	for node: Node in get_tree().get_nodes_in_group(&"hurtbox"):
		if node is HurtboxComponent:
			candidates.append(node as HurtboxComponent)
	var targets: Array[HurtboxComponent] = _resolver.resolve_chain(
		global_position,
		aim_position,
		candidates,
		_source_faction,
		spell.range_meters,
		spell.chain_jump_range,
		spell.max_chain_targets
	)
	if targets.is_empty():
		return false

	var confirmed: Array[HurtboxComponent] = []
	for target: HurtboxComponent in targets:
		if is_instance_valid(target) and target.receive_hit(spell.damage):
			confirmed.append(target)
	if confirmed.is_empty():
		return false

	_build_arc_mesh(confirmed, spell.cast_color)
	_sparks.restart()
	_sparks.emitting = true
	_sfx_pool.play_sfx(SyntheticAudio.create_chain_lightning(), -1.0)
	chain_resolved.emit(confirmed)
	return true


func _build_arc_mesh(targets: Array[HurtboxComponent], color: Color) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 4.0
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var previous_point: Vector3 = Vector3.ZERO
	for target: HurtboxComponent in targets:
		var target_point: Vector3 = to_local(target.global_position)
		mesh.surface_add_vertex(previous_point)
		mesh.surface_add_vertex(target_point)
		previous_point = target_point
	mesh.surface_end()
	_arc_visuals.mesh = mesh
