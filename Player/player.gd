extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const ENEMY_BOUNCE_SPEED = 300.0
const ATTACK_DAMAGE = 20
const ATTACK_START_FRAME = 2
const ATTACK_END_FRAME = 3
const KUNAI_RELEASE_FRAME = 2
const TELEPORT_ATTACK_DAMAGE = 20
const KUNAI_SCENE = preload("res://Weapons/kunai.tscn")

@export var kunai_distance: float = 60.0
# An oval around the visible body, including the extended arm in Brosok.
@export var kunai_orbit_center: Vector2 = Vector2(-1.76, -5.0)
@export var kunai_orbit_radii: Vector2 = Vector2(26.0, 28.0)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var kunai_spawn: Marker2D = $KunaiSpawn
@onready var aim_line: Line2D = $AimLine

var health = 100
var is_hurt = false
var is_dead = false
var _active_kunai: Area2D
var _enemy_platform_active = false
var _saved_platform_layers: int = 0
var is_attacking = false
var is_aiming = false
var is_throwing = false
var hit_bodies: Array[Node2D] = []
var aim_direction: Vector2 = Vector2.RIGHT
var throw_direction: Vector2 = Vector2.RIGHT
var throw_spawn_position: Vector2 = Vector2.ZERO
var kunai_released = false

var is_teleport_combo = false
var teleport_animation_finished = false
var kunai_flight_finished = false
var teleport_attack_started = false
var teleport_position: Vector2 = Vector2.ZERO
var teleport_start_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	anim.frame_changed.connect(_on_animation_frame_changed)
	aim_line.hide()
	kunai_spawn.position = _get_kunai_orbit_position(aim_direction)


func _physics_process(delta: float) -> void:
	if health <= 0 and not is_dead:
		death()

	# Damage and Death take priority over movement, attacks and teleportation.
	if is_dead or is_hurt:
		velocity.x = 0.0
		velocity += get_gravity() * delta
		_move_and_bounce_from_enemies()
		return

	if is_teleport_combo:
		_process_teleport_combo()
		return

	# Контакт с опорой обновляется и на земле: моб не должен становиться полом.
	velocity += get_gravity() * delta

	var direction := Input.get_axis("ui_left", "ui_right")
	var is_busy: bool = is_attacking or is_throwing

	if not is_busy:
		if Input.is_action_pressed("aim_kunai"):
			is_aiming = true
		elif is_aiming:
			# Capture the mouse direction when E is released.
			_update_aim()
			_start_kunai_throw()

		if is_aiming:
			_update_aim()
		elif not is_throwing:
			if direction != 0:
				anim.flip_h = direction < 0
			if Input.is_action_just_pressed("attack"):
				is_attacking = true
				hit_bodies.clear()
				anim.stop()
				anim.play("SimpleAttack")

	attack_area.position = Vector2(
		-30.0 if anim.flip_h else 30.0,
		-10.0
	)

	if is_attacking or is_throwing:
		velocity.x = 0
	else:
		if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not _enemy_platform_active:
			velocity.y = JUMP_VELOCITY

		if direction != 0:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	_move_and_bounce_from_enemies()

	if is_aiming:
		# Keep the line attached to gg while moving or jumping.
		_update_aim()
	elif is_throwing and not kunai_released:
		# The chosen offset follows gg; nearby obstacles can still block it.
		_update_kunai_spawn(throw_spawn_position)

	if is_attacking:
		# Each target can take damage only once per swing.
		if anim.frame >= ATTACK_START_FRAME and anim.frame <= ATTACK_END_FRAME:
			_deal_attack_damage()
		return

	if is_throwing:
		return

	if not is_on_floor() or velocity.y < 0.0:
		if velocity.y < 0:
			anim.play("Jump")
		else:
			anim.play("Fall")
	elif velocity.x != 0:
		anim.play("Run")
	else:
		anim.play("Idle")


func _move_and_bounce_from_enemies() -> void:
	# После move_and_slide() скорость падения уже может стать нулевой.
	var vertical_speed: float = velocity.y
	var was_falling: bool = not is_on_floor() and vertical_speed > 0.0
	move_and_slide()
	for index in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(index)
		var body := collision.get_collider() as Node2D
		if body == null or not body.is_in_group("enemies"):
			continue
		if collision.get_normal().dot(Vector2.UP) < cos(floor_max_angle):
			continue

		if not _enemy_platform_active:
			_saved_platform_layers = platform_floor_layers
			_enemy_platform_active = true
		# GG не переносится вместе с мобом как с движущейся платформой.
		platform_floor_layers = 0
		if body.get("alive") == false:
			# Тело погибшего моба не становится площадкой для GG.
			if body is PhysicsBody2D:
				add_collision_exception_with(body)
			velocity.y = vertical_speed
		elif not is_dead:
			velocity.y = -ENEMY_BOUNCE_SPEED
			# Падение сверху убивает anbu; простое касание опоры — только отскок.
			if was_falling and body.get("alive") == true and body.has_method("death"):
				body.call("death")
				if is_instance_valid(body) and body is PhysicsBody2D:
					add_collision_exception_with(body)
		return

	if _enemy_platform_active:
		platform_floor_layers = _saved_platform_layers
		_enemy_platform_active = false


func _update_aim() -> void:
	var center: Vector2 = to_global(kunai_orbit_center)
	var mouse_offset: Vector2 = get_global_mouse_position() - center
	# Aim from the fixed center so a cursor inside the oval cannot reverse aim.
	if not mouse_offset.is_zero_approx():
		aim_direction = mouse_offset.normalized()

	if not is_zero_approx(aim_direction.x):
		anim.flip_h = aim_direction.x < 0

	_update_kunai_spawn(_get_kunai_orbit_position(aim_direction))
	var origin: Vector2 = kunai_spawn.global_position
	aim_line.set_point_position(0, aim_line.to_local(origin))
	aim_line.set_point_position(1, aim_line.to_local(origin + aim_direction * kunai_distance))
	aim_line.visible = is_aiming


func _get_kunai_orbit_position(world_direction: Vector2) -> Vector2:
	var center: Vector2 = to_global(kunai_orbit_center)
	var local_direction: Vector2 = (to_local(center + world_direction) - kunai_orbit_center).normalized()
	var radii := Vector2(
		maxf(absf(kunai_orbit_radii.x), 0.1),
		maxf(absf(kunai_orbit_radii.y), 0.1)
	)
	var radius: float = 1.0 / sqrt(
		local_direction.x * local_direction.x / (radii.x * radii.x)
		+ local_direction.y * local_direction.y / (radii.y * radii.y)
	)
	return kunai_orbit_center + local_direction * radius


func _update_kunai_spawn(local_position: Vector2) -> void:
	var center: Vector2 = to_global(kunai_orbit_center)
	var origin: Vector2 = to_global(local_position)
	# Стены и пол ограничивают точку броска, а мобов пропускаем.
	var query := PhysicsRayQueryParameters2D.create(center, origin, 1, _get_teleport_path_exclusions())
	query.hit_from_inside = true
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var safe_distance: float = maxf(center.distance_to(hit["position"]) - 0.1, 0.0)
		origin = center + (origin - center).normalized() * safe_distance
	kunai_spawn.global_position = origin


func _get_teleport_path_exclusions() -> Array[RID]:
	var excluded: Array[RID] = [get_rid()]
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is CollisionObject2D:
			excluded.append(enemy.get_rid())
	return excluded


func _start_kunai_throw() -> void:
	if is_dead or is_hurt:
		return
	is_aiming = false
	aim_line.hide()
	is_throwing = true
	throw_direction = aim_direction
	throw_spawn_position = kunai_spawn.position
	kunai_released = false
	anim.stop()
	anim.play("Brosok")


func _release_kunai() -> void:
	if is_dead or is_hurt or kunai_released:
		return
	kunai_released = true

	var kunai = KUNAI_SCENE.instantiate()
	kunai.direction = throw_direction
	kunai.shooter = self
	kunai.max_distance = kunai_distance
	_active_kunai = kunai
	kunai.flight_finished.connect(_on_kunai_flight_finished)

	# The projectile belongs to the level and moves independently of gg.
	var projectile_parent: Node = get_tree().current_scene
	if projectile_parent == null or projectile_parent == self:
		projectile_parent = get_parent()
	if projectile_parent is Node2D:
		kunai.position = projectile_parent.to_local(kunai_spawn.global_position)
	else:
		kunai.position = kunai_spawn.global_position
	_start_teleport_combo()
	projectile_parent.add_child(kunai)


func _on_animation_frame_changed() -> void:
	if is_dead or is_hurt:
		return
	if is_throwing and anim.animation == "Brosok" and anim.frame >= KUNAI_RELEASE_FRAME:
		_release_kunai()


func _deal_attack_damage() -> void:
	if is_dead or is_hurt:
		return
	for body in attack_area.get_overlapping_bodies():
		if body == self or not is_instance_valid(body):
			continue

		if body.has_method("take_damage") and not hit_bodies.has(body):
			hit_bodies.append(body)
			body.call("take_damage", ATTACK_DAMAGE)


func _on_animation_finished() -> void:
	if is_dead:
		if anim.animation == "Death":
			get_tree().call_deferred("change_scene_to_file", "res://menu.tscn")
		return
	if is_hurt:
		if anim.animation == "Damage":
			is_hurt = false
		return

	if anim.animation == "SimpleAttack":
		is_attacking = false
	elif anim.animation == "Brosok" and is_throwing:
		# Still throw once if the animation is later shortened in the editor.
		_release_kunai()
		is_throwing = false
	elif anim.animation == "Teleport" and is_teleport_combo:
		teleport_animation_finished = true
		anim.hide()
	elif anim.animation == "TeleportAttack" and is_teleport_combo:
		_finish_teleport_combo()


func _start_teleport_combo() -> void:
	is_teleport_combo = true
	is_throwing = false
	is_aiming = false
	teleport_animation_finished = false
	kunai_flight_finished = false
	teleport_attack_started = false
	teleport_start_position = global_position
	velocity = Vector2.ZERO
	aim_line.hide()
	anim.show()
	anim.stop()
	anim.play("Teleport")


func _on_kunai_flight_finished(final_position: Vector2) -> void:
	_active_kunai = null
	if is_dead or is_hurt or not is_teleport_combo:
		return
	teleport_position = final_position
	kunai_flight_finished = true


func _process_teleport_combo() -> void:
	velocity = Vector2.ZERO
	if not teleport_attack_started:
		if not teleport_animation_finished or not kunai_flight_finished:
			return
		global_position = _find_safe_teleport_position(teleport_position)
		_move_and_bounce_from_enemies()
		teleport_attack_started = true
		hit_bodies.clear()
		anim.show()
		anim.stop()
		anim.play("TeleportAttack")
	_deal_teleport_attack_damage()


func _find_safe_teleport_position(target: Vector2) -> Vector2:
	var steps: int = int(ceil(target.distance_to(teleport_start_position) / 2.0)) + 1
	for i in range(steps):
		var base_position: Vector2 = target.move_toward(teleport_start_position, float(i) * 2.0)
		# Поднимаем капсулу над полом, если кунай остановился у поверхности.
		for up_step in range(11):
			var candidate: Vector2 = base_position + Vector2.UP * float(up_step * 2)
			if _can_teleport_to(candidate):
				return candidate
	return teleport_start_position


func _can_teleport_to(point: Vector2) -> bool:
	var collider: CollisionShape2D = $CollisionShape2D
	var shape_transform: Transform2D = collider.global_transform
	shape_transform.origin += point - global_position
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collider.shape
	query.transform = shape_transform
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = 2.0
	var space := get_world_2d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	# Мобы не блокируют путь, но сама точка появления должна быть свободной.
	var path := PhysicsRayQueryParameters2D.create(
		teleport_start_position, point, collision_mask, _get_teleport_path_exclusions()
	)
	path.hit_from_inside = true
	return space.intersect_ray(path).is_empty()


func _deal_teleport_attack_damage() -> void:
	if is_dead or is_hurt:
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30, 24)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(throw_direction.angle(), global_position + throw_direction * 18.0)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var body = hit["collider"]
		if is_instance_valid(body) and body.has_method("take_damage") and not hit_bodies.has(body):
			hit_bodies.append(body)
			body.call("take_damage", TELEPORT_ATTACK_DAMAGE)


func _finish_teleport_combo() -> void:
	is_teleport_combo = false
	teleport_animation_finished = false
	kunai_flight_finished = false
	teleport_attack_started = false
	velocity = Vector2.ZERO
	anim.show()


func take_damage(amount: int) -> void:
	# Мёртвый гг не получает урон.
	# Нулевой и отрицательный урон игнорируем.
	if is_dead or amount <= 0:
		return

	# Пока гг телепортируется и ещё не начал атаку
	# в точке назначения — полностью игнорируем урон.
	if is_teleport_combo and not teleport_attack_started:
		return
	
	if is_dead or amount <= 0:
		return

	health = maxi(health - amount, 0)
	if health <= 0:
		death()
		return

	_cancel_actions()
	is_hurt = true
	anim.stop()
	anim.play("Damage")


func death() -> void:
	if is_dead:
		return

	is_dead = true
	is_hurt = false
	health = 0
	_cancel_actions()
	anim.stop()
	anim.play("Death")


func _cancel_actions() -> void:
	is_attacking = false
	is_aiming = false
	is_throwing = false
	kunai_released = false
	hit_bodies.clear()
	aim_line.hide()
	_finish_teleport_combo()

	# An interrupted throw must not teleport gg after another throw has started.
	if is_instance_valid(_active_kunai):
		if _active_kunai.is_connected("flight_finished", _on_kunai_flight_finished):
			_active_kunai.disconnect("flight_finished", _on_kunai_flight_finished)
	_active_kunai = null
