class_name ArcaneImpact
extends GPUParticles3D

@onready var _cleanup_timer: Timer = get_node("CleanupTimer") as Timer


func _ready() -> void:
	restart()
	emitting = true
	_cleanup_timer.timeout.connect(queue_free)
	_cleanup_timer.start(lifetime + 0.2)
