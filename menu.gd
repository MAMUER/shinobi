extends Node2D

# Текстуры кнопок (пиксель-арт, набор Sengoku, вариант vermilion_a)
const TEX_NORMAL := preload("res://Tiles/Sengoku_Pixel_Pack/ui/ui_sengoku_button_01_vermilion_a_normal.png")
const TEX_HOVER := preload("res://Tiles/Sengoku_Pixel_Pack/ui/ui_sengoku_button_01_vermilion_a_hover.png")
const TEX_PRESSED := preload("res://Tiles/Sengoku_Pixel_Pack/ui/ui_sengoku_button_01_vermilion_a_pressed.png")

@onready var play_btn: Button = $Play
@onready var quit_btn: Button = $Quit
@onready var settings_btn: Button = $Settings
@onready var settings_menu: SettingsMenu = $SettingsMenu

func _ready() -> void:
	_setup_buttons()
	settings_menu.language_changed.connect(_refresh_texts)
	_refresh_texts()

func _setup_buttons() -> void:
	var normal := _make_box(TEX_NORMAL)
	var hover := _make_box(TEX_HOVER)
	var pressed := _make_box(TEX_PRESSED)
	_style_button(play_btn, normal, hover, pressed)
	_style_button(quit_btn, normal, hover, pressed)
	_style_button(settings_btn, normal, hover, pressed)

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
	b.add_theme_font_size_override("font_size", 40)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://level.tscn")

func _on_settings_pressed() -> void:
	settings_menu.open()

func _refresh_texts() -> void:
	play_btn.text = tr("play")
	quit_btn.text = tr("quit")
	settings_btn.text = tr("settings")