extends Node

# Загружает locale.csv и регистрирует переводы в TranslationServer.
# Все строки игры берутся через tr("ключ"). Добавляй строки/языки в locale.csv.

const LOCALE_CSV := "res://locale.csv"
const SAVE_PATH := "user://settings.cfg"

var locales: Array[String] = []
var current := "en"

func _ready() -> void:
	_load_translations()
	current = _load_saved_locale()
	TranslationServer.set_locale(current)

func _load_translations() -> void:
	var f := FileAccess.open(LOCALE_CSV, FileAccess.READ)
	if f == null:
		push_warning("i18n: не найден " + LOCALE_CSV)
		return
	var content := f.get_as_text()
	f.close()
	var rows: Array[String] = []
	for line in content.split("\n"):
		var l: String = line.strip_edges()
		if l != "":
			rows.append(l)
	if rows.size() < 2:
		push_warning("i18n: locale.csv пустой или без данных")
		return
	var headers := rows[0].split(",")
	for i in range(1, headers.size()):
		locales.append(headers[i].strip_edges())
	var translations: Dictionary = {}
	for loc in locales:
		var t := Translation.new()
		t.locale = loc
		translations[loc] = t
	for i in range(1, rows.size()):
		var cols := rows[i].split(",")
		if cols.size() < 2:
			continue
		var key := StringName(cols[0].strip_edges())
		for j in range(1, cols.size()):
			var idx := j - 1
			if idx < locales.size():
				var entry: Translation = translations[locales[idx]]
				entry.add_message(key, StringName(cols[j].strip_edges()))
	for loc in locales:
		var reg: Translation = translations[loc]
		TranslationServer.add_translation(reg)

func toggle_locale() -> void:
	if locales.is_empty():
		return
	var idx := locales.find(current)
	idx = (idx + 1) % locales.size()
	current = locales[idx]
	TranslationServer.set_locale(current)
	_save_locale()

func _load_saved_locale() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var loc: String = cfg.get_value("locale", "lang", "")
		if locales.has(loc):
			return loc
	if not locales.is_empty():
		return locales[0]
	return "en"

func _save_locale() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("locale", "lang", current)
	cfg.save(SAVE_PATH)
