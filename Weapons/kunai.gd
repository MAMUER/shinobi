extends Area2D

# Передаёт конечную точку полёта.
signal flight_finished(final_position: Vector2)

@export var speed: float = 300.0
@export var max_distance: float = 60.0
@export var damage: int = 20

var direction: Vector2 = Vector2.RIGHT
var shooter: CollisionObject2D
var travelled_distance: float = 0.0
var hit_bodies: Array[Node2D] = []
var pierced_rids: Array[RID] = []
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
		_finish_flight()
		return

	var step: float = minf(maxf(speed, 0.0) * delta, remaining)
	var start_position: Vector2 = global_position
	var next_position: Vector2 = start_position + direction * step

	# Проверяем весь шаг, чтобы не пропустить тонкую стену за мобами.
	var excluded: Array[RID] = [get_rid()]
	if is_instance_valid(shooter):
		excluded.append(shooter.get_rid())

	var query := PhysicsRayQueryParameters2D.create(
		start_position, next_position, collision_mask, excluded
	)
	query.hit_from_inside = true

	while true:
		query.exclude = excluded + pierced_rids
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break

		var body := hit["collider"] as Node2D
		if is_instance_valid(body) and body.is_in_group("enemies"):
			# После попадания исключаем моба и проверяем остаток того же шага.
			var body_rid: RID = hit["rid"]
			if not pierced_rids.has(body_rid):
				pierced_rids.append(body_rid)
			_hit_body(body)
			if _spent:
				return
			continue

		travelled_distance += start_position.distance_to(hit["position"])
		global_position = hit["position"]
		_hit_body(body)
		return

	global_position = next_position
	travelled_distance += step

	if travelled_distance >= max_distance:
		_finish_flight()


func _on_body_entered(body: Node2D) -> void:
	_hit_body(body)


func _hit_body(body: Node2D) -> void:
	if _spent or not is_instance_valid(body) or body == shooter:
		return

	if body.is_in_group("enemies"):
		if hit_bodies.has(body):
			return

		# Запоминаем цель до урона: анимация смерти не должна дать второй удар.
		hit_bodies.append(body)
		if body is CollisionObject2D:
			var body_rid: RID = body.get_rid()
			if not pierced_rids.has(body_rid):
				pierced_rids.append(body_rid)
		if body.has_method("take_damage"):
			body.call("take_damage", damage)
		return

	_finish_flight(body)


func _finish_flight(body: Node2D = null) -> void:
	# Полёт завершается только один раз.
	if _spent:
		return

	_spent = true
	set_physics_process(false)

	if is_instance_valid(body) and body.has_method("take_damage"):
		body.call("take_damage", damage)

	# Сначала сообщаем конечную точку, затем удаляем кунай.
	flight_finished.emit(global_position)
	queue_free()
