extends CharacterBody2D

@export var health: int = 60
@export var speed: float = 100.0
@export var attack_damage: int = 20
@export var attack_distance: float = 32.0
@export var attack_height_tolerance: float = 20.0
@export var attack_cooldown: float = 0.8
@export var attack_start_frame: int = 1
@export var attack_end_frame: int = 2

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var _attack_offset: Vector2 = attack_area.position

var chase = false
var alive = true
var is_attacking = false
var is_hurt = false

var _player: Node2D
var _cooldown_remaining: float = 0.0
var _attack_hit = false


func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	var candidate := get_node_or_null("../../Player/Player") as Node2D
	if _is_player_body(candidate):
		_player = candidate
	_update_attack_area()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)

	# Смерть и получение урона имеют приоритет над атакой и погоней.
	if not alive or is_hurt:
		velocity.x = 0.0
		move_and_slide()
		return

	if is_attacking:
		# Направление взмаха сохраняется до конца анимации.
		velocity.x = 0.0
		move_and_slide()
		_deal_attack_damage()
		return

	if not _has_live_player():
		chase = false

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

	if in_attack_range:
		velocity.x = 0.0
		if is_on_floor() and _cooldown_remaining <= 0.0 and _has_clear_attack_path():
			_start_attack()
		else:
			anim.play("Idle")
	else:
		velocity.x = signf(offset.x) * speed
		anim.play("Run" if not is_zero_approx(velocity.x) else "Idle")

	move_and_slide()


func _is_player_body(body: Node2D) -> bool:
	return is_instance_valid(body) and body.name == "Player" and body.get("health") != null


func _has_live_player() -> bool:
	return is_instance_valid(_player) and int(_player.get("health")) > 0


func _update_attack_area() -> void:
	attack_area.position = Vector2(
		-absf(_attack_offset.x) if anim.flip_h else absf(_attack_offset.x),
		_attack_offset.y
	)


func _has_clear_attack_path() -> bool:
	if not _has_live_player():
		return false

	# Мобы не закрывают обзор; стены и пол закрывают.
	var excluded: Array[RID] = [get_rid()]
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is CollisionObject2D:
			excluded.append(enemy.get_rid())
	if _player is CollisionObject2D:
		excluded.append(_player.get_rid())

	var query := PhysicsRayQueryParameters2D.create(
		global_position, _player.global_position, collision_mask, excluded
	)
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

	# Свежая проверка учитывает телепортацию гг в этом физическом кадре.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_collision.shape
	query.transform = attack_collision.global_transform
	query.collision_mask = attack_area.collision_mask
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		if hit["collider"] == _player:
			_attack_hit = true
			_player.set("health", maxi(int(_player.get("health")) - attack_damage, 0))
			return


func _on_detector_body_entered(body: Node2D) -> void:
	if _is_player_body(body):
		_player = body
		chase = alive


func _on_detector_body_exited(body: Node2D) -> void:
	if body == _player:
		chase = false


func _on_death_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body is CharacterBody2D and alive:
		body.velocity.y -= 300.0
		death()


func take_damage(amount: int) -> void:
	if not alive or amount <= 0:
		return

	health = maxi(health - amount, 0)
	if health <= 0:
		death()
		return

	# Получение урона прерывает текущий взмах и заново проигрывает Damage.
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
