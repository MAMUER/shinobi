extends Area2D

@export var speed: float = 300.0
@export var max_distance: float = 60.0
@export var damage: int = 20

var direction: Vector2 = Vector2.RIGHT
var shooter: CollisionObject2D
var travelled_distance: float = 0.0
var _spent: bool = false


func _ready() -> void:
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	direction = direction.normalized()
	global_rotation = direction.angle()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _spent:
		return

	var remaining: float = max_distance - travelled_distance
	if remaining <= 0.0:
		queue_free()
		return

	var step: float = minf(maxf(speed, 0.0) * delta, remaining)
	var next_position: Vector2 = global_position + direction * step

	# Check the entire step so a fast kunai cannot skip a thin wall.
	var excluded: Array[RID] = [get_rid()]
	if is_instance_valid(shooter):
		excluded.append(shooter.get_rid())
	var query := PhysicsRayQueryParameters2D.create(
		global_position, next_position, collision_mask, excluded
	)
	query.hit_from_inside = true
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		travelled_distance += global_position.distance_to(hit["position"])
		global_position = hit["position"]
		_hit_body(hit["collider"] as Node2D)
		return

	global_position = next_position
	travelled_distance += step
	if travelled_distance >= max_distance:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	_hit_body(body)


func _hit_body(body: Node2D) -> void:
	if _spent or not is_instance_valid(body) or body == shooter:
		return

	_spent = true
	set_physics_process(false)
	if body.has_method("take_damage"):
		body.call("take_damage", damage)
	queue_free()
