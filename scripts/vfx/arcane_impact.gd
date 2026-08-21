class_name ArcaneImpact
extends GPUParticles3D

@onready var _cleanup_timer: Timer = get_node("CleanupTimer") as Timer
@onready var _sfx_pool: SfxPool3D = get_node("SfxPool3D") as SfxPool3D


func _ready() -> void:
	restart()
	emitting = true
	_sfx_pool.play_sfx(SyntheticAudio.create_arcane_impact(), -1.0)
	_cleanup_timer.timeout.connect(queue_free)
	_cleanup_timer.start(lifetime + 0.2)
