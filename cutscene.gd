extends Control

const CUTSCENE_DIR := "res://Cutscene"
const SLIDE_DURATION := 3.0

@onready var texture_rect: TextureRect = $TextureRect
@onready var skip_button: Button = $SkipButton

var slides: Array[Texture2D] = []
var current_slide := 0
var slide_timer := 0.0

func _ready() -> void:
	skip_button.pressed.connect(_on_skip)
	_load_slides()
	if slides.is_empty():
		_finish()
		return
	_show_slide(0)

func _load_slides() -> void:
	var dir := DirAccess.open(CUTSCENE_DIR)
	if dir == null:
		return
	var files: Array[String] = []
	for file in dir.get_files():
		var lower := file.to_lower()
		if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp"):
			files.append(file)
	files.sort()
	for file in files:
		var path := CUTSCENE_DIR + "/" + file
		var texture := load(path) as Texture2D
		if texture != null:
			slides.append(texture)

func _show_slide(index: int) -> void:
	current_slide = index
	texture_rect.texture = slides[index]
	slide_timer = 0.0

func _process(delta: float) -> void:
	if slides.is_empty():
		return
	slide_timer += delta
	if slide_timer >= SLIDE_DURATION:
		_next_slide()

func _next_slide() -> void:
	current_slide += 1
	if current_slide >= slides.size():
		_finish()
	else:
		_show_slide(current_slide)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_finish()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_next_slide()
		get_viewport().set_input_as_handled()

func _on_skip() -> void:
	_finish()

func _finish() -> void:
	# Отложенный вызов: сцена меняется, когда дерево уже не занято добавлением.
	get_tree().call_deferred("change_scene_to_file", "res://menu.tscn")