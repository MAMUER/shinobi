extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const ATTACK_DAMAGE = 20
const ATTACK_START_FRAME = 2
const ATTACK_END_FRAME = 3

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea

var health = 100
var is_attacking = false
var hit_bodies: Array[Node2D] = []


func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if health <= 0:
		get_tree().change_scene_to_file("res://menu.tscn")
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	var direction := Input.get_axis("ui_left", "ui_right")

	if not is_attacking:
		if direction != 0:
			anim.flip_h = direction < 0

		attack_area.position = Vector2(
			-30.0 if anim.flip_h else 30.0,
			-10.0
		)

		if Input.is_action_just_pressed("attack"):
			is_attacking = true
			hit_bodies.clear()
			anim.stop()
			anim.play("SimpleAttack")

	if is_attacking:
		velocity.x = 0
	else:
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		if direction != 0:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	if is_attacking:
		# Each target can take damage only once per swing.
		if anim.frame >= ATTACK_START_FRAME and anim.frame <= ATTACK_END_FRAME:
			_deal_attack_damage()
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
