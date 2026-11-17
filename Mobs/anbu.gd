extends CharacterBody2D

@export var health: int = 60
@export var speed: float = 100.0
@export var attack_damage: int = 20
@export var attack_distance: float = 32.0
@export var attack_height_tolerance: float = 20.0
@export var attack_cooldown: float = 0.8
@export var attack_start_frame: int = 1
@export var attack_end_frame: int = 2

@export_group("Jump")
@export var jump_speed: float = 400.0
@export var jump_horizontal_speed: float = 140.0
@export var jump_cooldown: float = 1.0
@export var jump_search_distance: float = 120.0
@export var jump_max_drop: float = 24.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var obstacle_check: RayCast2D = $JumpObstacleCheck
@onready var head_check: RayCast2D = $JumpHeadCheck
@onready var floor_check: RayCast2D = $JumpFloorCheck
@onready var landing_check: RayCast2D = $JumpLandingCheck
@onready var _attack_offset: Vector2 = attack_area.position

var chase = false
var alive = true
var is_attacking = false
var is_hurt = false
var is_jumping = false

var _player: Node2D
var _cooldown_remaining: float = 0.0
var _attack_hit = false
var _jump_preparing = false
var _jump_prepare_time: float = 0.0
var _jump_cooldown_remaining: float = 0.0
var _jump_check_remaining: float = 0.0
var _jump_direction: float = 1.0
var _jump_velocity_x: float = 0.0
var _jump_target: Vector2
var _air_phase: int = 0
var _air_frame_time: float = 0.0
var _escaping_actor = false
var _support_actor: CharacterBody2D
var _escape_direction: float = 1.0
var _saved_platform_layers: int = 0


func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	var candidate := get_node_or_null("../../Player/Player") as Node2D
	if _is_player_body(candidate):
		_player = candidate
	_update_attack_area()


func _physics_process(delta: float) -> void:
	if _escaping_actor and not is_instance_valid(_support_actor):
		_finish_actor_escape()
	var actor_floor: CharacterBody2D = _get_actor_floor()
	if actor_floor != null:
		_start_actor_escape(actor_floor)
	if not is_on_floor() or _escaping_actor:
		velocity += get_gravity() * delta

	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_jump_cooldown_remaining = maxf(_jump_cooldown_remaining - delta, 0.0)
	_jump_check_remaining = maxf(_jump_check_remaining - delta, 0.0)

	# Смерть и получение урона прерывают подготовку и управление прыжком.
	if not alive or is_hurt:
		velocity.x = 0.0
		move_and_slide()
		return

	if _escaping_actor:
		_process_actor_escape(delta)
		return

	if is_attacking:
		velocity.x = 0.0
		move_and_slide()
		_deal_attack_damage()
		return

	if not _has_live_player():
		chase = false

	if is_jumping:
		_process_jump(delta)
		return

	# Падение с платформы и первоначальное появление в воздухе тоже используют Jump.
	if not is_on_floor():
		velocity.x = signf(_player.global_position.x - global_position.x) * speed if chase else 0.0
		_move_in_air(delta)
		return

	if not chase:
		velocity.x = 0.0
		anim.play("Idle")
		move_and_slide()
		return

	var offset: Vector2 = _player.global_position - global_position
	if not is_zero_approx(offset.x):
		anim.flip_h = offset.x < 0.0
	_update_attack_area()

	var in_attack_range: bool = (
		absf(offset.x) <= attack_distance
		and absf(offset.y) <= attack_height_tolerance
	)
	if in_attack_range and _has_clear_attack_path():
		velocity.x = 0.0
		if _cooldown_remaining <= 0.0:
			_start_attack()
		else:
			anim.play("Idle")
	else:
		var direction: float = -1.0 if anim.flip_h else 1.0
		_update_jump_sensors(direction)
		var blocked: bool = obstacle_check.is_colliding()
		var at_edge: bool = not floor_check.is_colliding()
		var target_above: bool = offset.y < -attack_height_tolerance
		if (blocked or at_edge or target_above) and _try_start_jump(direction, target_above):
			move_and_slide()
			return
		# Без подходящего прыжка не бежим в стену или в пропасть.
		velocity.x = 0.0 if blocked or at_edge else signf(offset.x) * speed
		_play_ground_animation()
	move_and_slide()


func _update_jump_sensors(direction: float) -> void:
	var half_size: Vector2 = _body_half_size()
	obstacle_check.position = Vector2(0.0, half_size.y - 6.0)
	obstacle_check.target_position = Vector2(direction * (half_size.x + 18.0), 0.0)
	head_check.position = Vector2(0.0, -half_size.y + 1.0)
	head_check.target_position = Vector2(0.0, -20.0)
	floor_check.position = Vector2(direction * (half_size.x + 8.0), 0.0)
	floor_check.target_position = Vector2(0.0, half_size.y + 12.0)
	var excluded: Array[RID] = _world_query_exclusions()
	for ray in [obstacle_check, head_check, floor_check, landing_check]:
		ray.collision_mask = collision_mask
		ray.clear_exceptions()
		for body_rid in excluded:
			ray.add_exception_rid(body_rid)
	obstacle_check.force_raycast_update()
	head_check.force_raycast_update()
	floor_check.force_raycast_update()


func _try_start_jump(direction: float, target_above: bool) -> bool:
	if _jump_cooldown_remaining > 0.0 or _jump_check_remaining > 0.0 or head_check.is_colliding():
		return false
	_jump_check_remaining = 0.2
	var plan: Dictionary = _find_jump_plan(direction, target_above)
	if plan.is_empty():
		return false
	is_jumping = true
	_jump_preparing = true
	_jump_prepare_time = 0.0
	_jump_direction = direction
	velocity.x = 0.0
	_set_jump_frame(0)
	return true


func _process_jump(delta: float) -> void:
	if _jump_preparing:
		velocity.x = 0.0
		if not chase or not _has_live_player() or not is_on_floor():
			_cancel_jump()
			return
		_jump_prepare_time += delta
		_set_jump_frame(0)
		if _jump_prepare_time < _jump_frame_duration(0):
			move_and_slide()
			return

		# После подготовки повторяем проверку: GG или препятствия могли переместиться.
		_update_jump_sensors(_jump_direction)
		var offset: Vector2 = _player.global_position - global_position
		var plan: Dictionary = _find_jump_plan(_jump_direction, offset.y < -attack_height_tolerance)
		if head_check.is_colliding() or plan.is_empty() or offset.x * _jump_direction < -attack_distance:
			_cancel_jump()
			return
		_jump_preparing = false
		_jump_target = plan["position"]
		_jump_velocity_x = float(plan["velocity_x"])
		velocity.y = -jump_speed
		_air_phase = 0

	# Не пролетаем выбранное место приземления по горизонтали.
	var remaining_x: float = _jump_target.x - global_position.x
	velocity.x = clampf(remaining_x / maxf(delta, 0.001), -absf(_jump_velocity_x), absf(_jump_velocity_x))
	_move_in_air(delta)


func _move_in_air(delta: float) -> void:
	move_and_slide()
	if not alive or is_hurt:
		return
	if is_on_floor():
		var actor_floor: CharacterBody2D = _get_actor_floor()
		if actor_floor != null:
			_start_actor_escape(actor_floor)
			_update_air_animation(delta)
			return
		if is_jumping:
			is_jumping = false
			_jump_cooldown_remaining = jump_cooldown
		_air_phase = 0
		_play_ground_animation()
	else:
		_update_air_animation(delta)


func _get_actor_floor() -> CharacterBody2D:
	if not is_on_floor():
		return null
	for index in range(get_slide_collision_count()):
		var hit: KinematicCollision2D = get_slide_collision(index)
		var body := hit.get_collider() as CharacterBody2D
		if body != null and hit.get_normal().dot(Vector2.UP) >= cos(floor_max_angle):
			return body
	return null


func _start_actor_escape(actor: CharacterBody2D) -> void:
	if not _escaping_actor:
		_saved_platform_layers = platform_floor_layers
		var offset_x: float = global_position.x - actor.global_position.x
		_escape_direction = signf(offset_x) if not is_zero_approx(offset_x) else _jump_direction
		_cancel_jump()
		is_attacking = false
		_cooldown_remaining = maxf(_cooldown_remaining, attack_cooldown)
		_escaping_actor = true
	_support_actor = actor
	# Персонажи не должны переносить anbu вместе с собой как платформы.
	platform_floor_layers = 0


func _process_actor_escape(delta: float) -> void:
	velocity.x = _escape_direction * maxf(speed, 60.0)
	anim.flip_h = _escape_direction < 0.0
	_update_attack_area()
	move_and_slide()
	if not alive or is_hurt:
		return
	if _has_world_floor():
		_finish_actor_escape()
		_play_ground_animation()
		return
	# Если с выбранной стороны стена, сходим с головы в другую сторону.
	for index in range(get_slide_collision_count()):
		var hit: KinematicCollision2D = get_slide_collision(index)
		if not hit.get_collider() is CharacterBody2D and hit.get_normal().x * _escape_direction < -0.5:
			_escape_direction *= -1.0
			break
	_update_air_animation(delta)


func _has_world_floor() -> bool:
	if not is_on_floor():
		return false
	for index in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(index)
		if not collision.get_collider() is CharacterBody2D and collision.get_normal().dot(Vector2.UP) >= cos(floor_max_angle):
			return true
	var feet: Vector2 = body_collision.global_position + Vector2.DOWN * _body_half_size().y
	var excluded: Array[RID] = _world_query_exclusions()
	if is_instance_valid(_support_actor) and not excluded.has(_support_actor.get_rid()):
		excluded.append(_support_actor.get_rid())
	var query := PhysicsRayQueryParameters2D.create(feet + Vector2.UP * 2.0, feet + Vector2.DOWN * 4.0, collision_mask, excluded)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and Vector2(hit["normal"]).dot(Vector2.UP) >= cos(floor_max_angle)


func _finish_actor_escape() -> void:
	platform_floor_layers = _saved_platform_layers
	_escaping_actor = false
	_support_actor = null
	_air_phase = 0


func _update_air_animation(delta: float) -> void:
	var phase: int = -1 if velocity.y < 0.0 else 1
	if phase != _air_phase:
		_air_phase = phase
		_air_frame_time = 0.0
	else:
		_air_frame_time += delta
	# Индексы 1–2: подъём. Индексы 3–4: падение.
	var first_frame: int = 1 if phase < 0 else 3
	var frame: int = first_frame if _air_frame_time < _jump_frame_duration(first_frame) else first_frame + 1
	_set_jump_frame(frame)


func _set_jump_frame(frame: int) -> void:
	anim.animation = "Jump"
	anim.pause()
	anim.set_frame_and_progress(frame, 0.0)


func _jump_frame_duration(frame: int) -> float:
	return anim.sprite_frames.get_frame_duration("Jump", frame) / maxf(anim.sprite_frames.get_animation_speed("Jump"), 0.1)


func _cancel_jump() -> void:
	is_jumping = false
	_jump_preparing = false
	_jump_cooldown_remaining = jump_cooldown
	_air_phase = 0


func _play_ground_animation() -> void:
	anim.play("Run" if not is_zero_approx(velocity.x) else "Idle")


func _body_half_size() -> Vector2:
	return body_collision.shape.get_rect().size * body_collision.global_scale.abs() * 0.5


func _body_transform_at(point: Vector2) -> Transform2D:
	var result: Transform2D = body_collision.global_transform
	result.origin += point - global_position
	return result


func _find_jump_plan(direction: float, target_above: bool) -> Dictionary:
	var gravity: float = get_gravity().y
	if gravity <= 0.0 or jump_speed <= 0.0 or jump_horizontal_speed <= 0.0:
		return {}
	var half_size: Vector2 = _body_half_size()
	var height: float = jump_speed * jump_speed / (2.0 * gravity)
	var feet_y: float = body_collision.global_position.y + half_size.y
	var flight_limit: float = (jump_speed + sqrt(jump_speed * jump_speed + 2.0 * gravity * maxf(jump_max_drop, 0.0))) / gravity
	var max_distance: float = minf(jump_search_distance, jump_horizontal_speed * flight_limit)
	var excluded: Array[RID] = _world_query_exclusions()
	var best: Dictionary = {}
	var best_score: float = INF
	for distance in range(int(half_size.x * 2.0 + 12.0), int(max_distance) + 1, 8):
		var x: float = global_position.x + direction * float(distance)
		landing_check.global_position = Vector2(x, feet_y - height + 0.5)
		landing_check.target_position = Vector2(0.0, height + maxf(jump_max_drop, 0.0) - 0.5)
		landing_check.force_raycast_update()
		if not landing_check.is_colliding() or landing_check.get_collision_normal().dot(Vector2.UP) < cos(floor_max_angle):
			continue
		var surface: Vector2 = landing_check.get_collision_point()
		if target_above and feet_y - surface.y < attack_height_tolerance:
			continue
		var landing: Vector2 = Vector2(x, surface.y - half_size.y - 0.25) - body_collision.position
		var discriminant: float = jump_speed * jump_speed + 2.0 * gravity * (landing.y - global_position.y)
		if discriminant <= 0.0:
			continue
		var flight_time: float = (jump_speed + sqrt(discriminant)) / gravity
		var horizontal_velocity: float = (landing.x - global_position.x) / flight_time
		if absf(horizontal_velocity) > jump_horizontal_speed:
			continue
		if not _landing_is_free(landing, surface, half_size.x, excluded):
			continue
		if not _jump_arc_is_clear(landing, horizontal_velocity, flight_time, gravity, excluded):
			continue
		var score: float = landing.distance_to(_player.global_position)
		if score < best_score:
			best_score = score
			best = {"position": landing, "velocity_x": horizontal_velocity}
	return best


func _landing_is_free(point: Vector2, surface: Vector2, half_width: float, excluded: Array[RID]) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body_collision.shape
	query.transform = _body_transform_at(point)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = 0.05
	var space := get_world_2d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	# Проверяем опору с обеих сторон капсулы, чтобы не выбирать край площадки.
	for side in [-1.0, 1.0]:
		var from: Vector2 = Vector2(point.x + side * half_width * 0.8, surface.y - 2.0)
		var ray := PhysicsRayQueryParameters2D.create(from, from + Vector2.DOWN * 6.0, collision_mask, excluded)
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty() or Vector2(hit["normal"]).dot(Vector2.UP) < cos(floor_max_angle):
			return false
	return true


func _jump_arc_is_clear(landing: Vector2, horizontal_velocity: float, flight_time: float, gravity: float, excluded: Array[RID]) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body_collision.shape
	query.collision_mask = collision_mask
	query.exclude = excluded
	query.margin = 0.05
	var space := get_world_2d().direct_space_state
	var steps: int = maxi(int(ceil(flight_time * 60.0)), 1)
	var previous: Vector2 = global_position
	for step in range(1, steps + 1):
		var time: float = flight_time * float(step) / float(steps)
		var point: Vector2 = global_position + Vector2(horizontal_velocity * time, -jump_speed * time + 0.5 * gravity * time * time)
		if step == steps:
			point = landing
		query.transform = _body_transform_at(previous)
		query.motion = point - previous
		var fractions: PackedFloat32Array = space.cast_motion(query)
		if fractions[0] < 0.999:
			return false
		previous = point
	return true


func _is_player_body(body: Node2D) -> bool:
	return is_instance_valid(body) and body.name == "Player" and body.get("health") != null


func _has_live_player() -> bool:
	return is_instance_valid(_player) and int(_player.get("health")) > 0


func _update_attack_area() -> void:
	attack_area.position = Vector2(-absf(_attack_offset.x) if anim.flip_h else absf(_attack_offset.x), _attack_offset.y)


func _world_query_exclusions() -> Array[RID]:
	var excluded: Array[RID] = [get_rid()]
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is CollisionObject2D:
			excluded.append(enemy.get_rid())
	if _player is CollisionObject2D and is_instance_valid(_player):
		excluded.append(_player.get_rid())
	return excluded


func _has_clear_attack_path() -> bool:
	if not _has_live_player():
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, _player.global_position, collision_mask, _world_query_exclusions())
	query.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _start_attack() -> void:
	is_attacking = true
	is_hurt = false
	_attack_hit = false
	velocity.x = 0.0
	_update_attack_area()
	anim.stop()
	anim.play("Attack1")


func _deal_attack_damage() -> void:
	if not alive or is_hurt or not is_attacking or _attack_hit:
		return
	if not _has_live_player() or anim.animation != "Attack1":
		return
	if anim.frame < attack_start_frame or anim.frame > attack_end_frame:
		return
	if not _has_clear_attack_path():
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_collision.shape
	query.transform = attack_collision.global_transform
	query.collision_mask = attack_area.collision_mask
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		if hit["collider"] == _player:
			_attack_hit = true
			_player.call("take_damage", attack_damage)
			return


func _on_detector_body_entered(body: Node2D) -> void:
	if _is_player_body(body):
		_player = body
		chase = alive


func _on_detector_body_exited(body: Node2D) -> void:
	if body == _player:
		chase = false


func _on_death_body_entered(body: Node2D) -> void:
	if (
		_is_player_body(body) and body is CharacterBody2D and alive
		and int(body.get("health")) > 0 and body.velocity.y > 0.0
		and body.global_position.y < global_position.y
	):
		body.velocity.y = -300.0
		death()


func take_damage(amount: int) -> void:
	if not alive or amount <= 0:
		return
	health = maxi(health - amount, 0)
	if health <= 0:
		death()
		return
	_cancel_jump()
	is_attacking = false
	is_hurt = true
	_attack_hit = false
	_cooldown_remaining = attack_cooldown
	velocity.x = 0.0
	anim.stop()
	anim.play("Damage")


func death() -> void:
	if not alive:
		return
	_cancel_jump()
	alive = false
	health = 0
	chase = false
	is_attacking = false
	is_hurt = false
	_attack_hit = true
	velocity.x = 0.0
	anim.stop()
	anim.play("Death")


func _on_animation_finished() -> void:
	if not alive:
		if anim.animation == "Death":
			queue_free()
		return
	if anim.animation == "Damage" and is_hurt:
		is_hurt = false
	elif anim.animation == "Attack1" and is_attacking:
		is_attacking = false
		_cooldown_remaining = attack_cooldown
