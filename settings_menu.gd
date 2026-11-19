class_name SettingsMenu
extends CanvasLayer

signal language_changed

const SAVE_PATH := "user://settings.cfg"

@onready var root: Control = $Root
@onready var title_label: Label = $Root/Panel/Title
@onready var lang_label: Label = $Root/Panel/LangRow/LangLabel
@onready var lang_button: Button = $Root/Panel/LangRow/LangButton
@onready var fps_label: Label = $Root/Panel/FpsRow/FpsLabel
@onready var fps_button: Button = $Root/Panel/FpsRow/FpsButton
@onready var back_button: Button = $Root/Panel/BackButton

var fps_options: Array[int] = [60, 90, 120, 0]
var fps_index := 0

func _ready() -> void:
	root.visible = false
	lang_button.pressed.connect(_on_lang_pressed)
	fps_button.pressed.connect(_on_fps_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_load_fps()
	_apply_fps()
	_refresh_texts()

func open() -> void:
	root.visible = true
	_refresh_texts()

func _on_lang_pressed() -> void:
	I18n.call("toggle_locale")
	_refresh_texts()
	language_changed.emit()

func _on_fps_pressed() -> void:
	fps_index = (fps_index + 1) % fps_options.size()
	_apply_fps()
	_save_fps()
	_refresh_texts()

func _on_back_pressed() -> void:
	root.visible = false

func _apply_fps() -> void:
	Engine.max_fps = fps_options[fps_index]

func _refresh_texts() -> void:
	title_label.text = tr("settings")
	lang_label.text = tr("language") + ":"
	fps_label.text = tr("fps") + ":"
	back_button.text = tr("back")
	var lang_name := "English" if TranslationServer.get_locale() == "en" else "Русский"
	lang_button.text = lang_name
	fps_button.text = _fps_label()

func _fps_label() -> String:
	var value := fps_options[fps_index]
	if value == 0:
		return tr("off")
	return str(value)

func _load_fps() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var saved := int(cfg.get_value("fps", "max_fps", 60))
		fps_index = fps_options.find(saved)
		if fps_index < 0:
			fps_index = 0

func _save_fps() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("fps", "max_fps", fps_options[fps_index])
	cfg.save(SAVE_PATH)