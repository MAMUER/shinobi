extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const ATTACK_DAMAGE = 20
const ATTACK_START_FRAME = 2
const ATTACK_END_FRAME = 3
const KUNAI_RELEASE_FRAME = 2
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
var is_attacking = false
var is_aiming = false
var is_throwing = false
var hit_bodies: Array[Node2D] = []
var aim_direction: Vector2 = Vector2.RIGHT
var throw_direction: Vector2 = Vector2.RIGHT
var throw_spawn_position: Vector2 = Vector2.ZERO
var kunai_released = false


func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	anim.frame_changed.connect(_on_animation_frame_changed)
	aim_line.hide()
	kunai_spawn.position = _get_kunai_orbit_position(aim_direction)


func _physics_process(delta: float) -> void:
	if health <= 0:
		get_tree().change_scene_to_file("res://menu.tscn")
		return

	if not is_on_floor():
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
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		if direction != 0:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

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

	if not is_on_floor():
		if velocity.y < 0:
			anim.play("Jump")
		else:
			anim.play("Fall")
	elif velocity.x != 0:
		anim.play("Run")
	else:
		anim.play("Idle")


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
	# Prevent an orbiting launch point from jumping through a nearby wall or mob.
	var query := PhysicsRayQueryParameters2D.create(center, origin, 1, [get_rid()])
	query.hit_from_inside = true
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var safe_distance: float = maxf(center.distance_to(hit["position"]) - 0.1, 0.0)
		origin = center + (origin - center).normalized() * safe_distance
	kunai_spawn.global_position = origin


func _start_kunai_throw() -> void:
	is_aiming = false
	aim_line.hide()
	is_throwing = true
	throw_direction = aim_direction
	throw_spawn_position = kunai_spawn.position
	kunai_released = false
	anim.stop()
	anim.play("Brosok")


func _release_kunai() -> void:
	if kunai_released:
		return
	kunai_released = true

	var kunai = KUNAI_SCENE.instantiate()
	kunai.direction = throw_direction
	kunai.shooter = self
	kunai.max_distance = kunai_distance

	# The projectile belongs to the level and moves independently of gg.
	var projectile_parent: Node = get_tree().current_scene
	if projectile_parent == null or projectile_parent == self:
		projectile_parent = get_parent()
	if projectile_parent is Node2D:
		kunai.position = projectile_parent.to_local(kunai_spawn.global_position)
	else:
		kunai.position = kunai_spawn.global_position
	projectile_parent.add_child(kunai)


func _on_animation_frame_changed() -> void:
	if is_throwing and anim.animation == "Brosok" and anim.frame >= KUNAI_RELEASE_FRAME:
		_release_kunai()


func _deal_attack_damage() -> void:
	for body in attack_area.get_overlapping_bodies():
		if not is_instance_valid(body):
			continue

		if body.has_method("take_damage") and not hit_bodies.has(body):
			hit_bodies.append(body)
			body.call("take_damage", ATTACK_DAMAGE)


func _on_animation_finished() -> void:
	if anim.animation == "SimpleAttack":
		is_attacking = false
	elif anim.animation == "Brosok" and is_throwing:
		# Still throw once if the animation is later shortened in the editor.
		_release_kunai()
		is_throwing = false
