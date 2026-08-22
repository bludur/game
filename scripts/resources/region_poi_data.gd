class_name RegionPoiData
extends Resource

enum Kind {
	AWAKENING,
	HEARTH,
	RUINS,
	BOG,
	CRYPT,
	BRIDGE,
	TOWER,
	MOONWELL,
	CAVE,
	PILGRIM_STONES,
	GALLOWS,
	CHAPEL,
}

enum AudioMood {
	WILDS,
	RUINS,
	BOG,
	CRYPT,
	HEARTH,
}

@export var poi_id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.AWAKENING
@export var world_position: Vector3 = Vector3.ZERO
@export_range(4.0, 32.0, 1.0) var discovery_radius: float = 14.0
@export_range(6.0, 40.0, 1.0) var audio_radius: float = 22.0
@export var audio_mood: AudioMood = AudioMood.WILDS
@export var map_color: Color = Color(0.7, 0.5, 0.9, 1.0)
@export var loot_hint: StringName = &""


func is_valid_definition() -> bool:
	return not poi_id.is_empty() and not display_name.is_empty() \
		and discovery_radius > 0.0 and audio_radius >= discovery_radius
