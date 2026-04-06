extends Node

const SETTINGS_PATH     := "user://settings.cfg"
const TRANSLATIONS_PATH := "res://translations/translations.csv"
const SUPPORTED_LOCALES := ["de", "en"]
const DEFAULT_LOCALE    := "de"


func _ready() -> void:
	_load_csv_translations()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	var locale : String = cfg.get_value("general", "locale", DEFAULT_LOCALE)
	TranslationServer.set_locale(locale)


func set_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("general", "locale", locale)
	cfg.save(SETTINGS_PATH)


func get_locale() -> String:
	return TranslationServer.get_locale()


func _load_csv_translations() -> void:
	var file := FileAccess.open(TRANSLATIONS_PATH, FileAccess.READ)
	if file == null:
		push_error("LocaleManager: could not open %s" % TRANSLATIONS_PATH)
		return

	# Parse header to find locale columns
	var header := file.get_csv_line()
	if header.size() < 2:
		push_error("LocaleManager: CSV header too short")
		return

	# Build a Translation object per locale column
	var translations : Dictionary = {}   # locale → Translation
	for i in range(1, header.size()):
		var locale := header[i].strip_edges()
		var t := Translation.new()
		t.locale = locale
		translations[locale] = t

	# Parse rows
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2 or row[0].strip_edges().is_empty():
			continue
		var key := row[0].strip_edges()
		for i in range(1, mini(row.size(), header.size())):
			var locale := header[i].strip_edges()
			if translations.has(locale):
				translations[locale].add_message(key, row[i])

	# Register all translations
	for locale in translations:
		TranslationServer.add_translation(translations[locale])
