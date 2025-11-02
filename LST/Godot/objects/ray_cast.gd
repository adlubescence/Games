extends RayCast3D


@onready var perma_crosshair = $perma_crosshair
@onready var active_crosshair = $active_crosshair

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if self.is_colliding():
		active_crosshair.visible = true
		perma_crosshair.visible = false
		active_crosshair.global_transform.origin = self.get_collision_point()
	else:
		active_crosshair.visible = false
		perma_crosshair.visible = true
		perma_crosshair.position = self.target_position
