extends CanvasLayer

# Меню паузы. Esc — пауза/снятие. Кнопки рендерятся поверх уровня (layer = 10).
# Узел должен иметь process_mode = ALWAYS (3), чтобы работать на паузе.

const TEX_NORMAL := preload("res://Tiles/Sengoku_Pixel_Pack/ui/ui_sengoku_button_01_vermilion_a_normal.png")
const TEX_HOVER := preload("res://Tiles/Sengoku_Pixel_Pack/ui/ui_sengoku_button_01_vermilion_a_hover.png")
const TEX_PRESSED := preload("res://Tiles/Sengoku_Pixel_Pack/ui/ui_sengoku_button_01_vermilion_a_pressed.png")

@onready var root: Control = $Root
@onready var resume_btn: Button = $Root/VBox/Resume
@onready var restart_btn: Button = $Root/VBox/Restart
@onready var mainmenu_btn: Button = $Root/VBox/MainMenu
@onready var quit_btn: Button = $Root/VBox/Quit

func _ready() -> void:
	_setup_buttons()
	resume_btn.pressed.connect(_on_resume)
	restart_btn.pressed.connect(_on_restart)
	mainmenu_btn.pressed.connect(_on_main_menu)
	quit_btn.pressed.connect(_on_quit)
	root.visible = false

func _setup_buttons() -> void:
	var normal := _make_box(TEX_NORMAL)
	var hover := _make_box(TEX_HOVER)
	var pressed := _make_box(TEX_PRESSED)
	_style_button(resume_btn, normal, hover, pressed)
	_style_button(restart_btn, normal, hover, pressed)
	_style_button(mainmenu_btn, normal, hover, pressed)
	_style_button(quit_btn, normal, hover, pressed)

func _make_box(tex: Texture2D) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.texture_margin_left = 20.0
	box.texture_margin_right = 20.0
	box.texture_margin_top = 14.0
	box.texture_margin_bottom = 14.0
	return box

func _style_button(b: Button, normal: StyleBoxTexture, hover: StyleBoxTexture, pressed: StyleBoxTexture) -> void:
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", Color("#fff2d0"))
	b.add_theme_color_override("font_hover_color", Color("#ffffff"))
	b.add_theme_color_override("font_pressed_color", Color("#e0c890"))
	b.add_theme_font_size_override("font_size", 32)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	var new_paused := not get_tree().paused
	get_tree().paused = new_paused
	root.visible = new_paused

func _on_resume() -> void:
	get_tree().paused = false
	root.visible = false

func _on_restart() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://level.tscn")

func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menu.tscn")

func _on_quit() -> void:
	get_tree().quit()