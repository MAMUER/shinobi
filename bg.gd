extends ParallaxBackground


@export var speed := 50.0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	scroll_offset.x -= speed * delta