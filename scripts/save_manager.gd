extends Node

## Persistiert alle Spieler-Daten über Sessions hinweg.
##
## Ordner-Struktur:
##   user://saves/[world_name]/player_solo.json        ← Solo-Modus
##   user://saves/[world_name]/players/[uuid].json     ← Multiplayer-Gäste
##   user://saves/[world_name]/world_info.json         ← Metadaten (letztes Spielen, Modus)

const SAVES_ROOT := "user://saves/"

## Name der aktuell aktiven Welt. Wird per set_world() gesetzt.
var current_world_name: String = "default"


func _ready() -> void:
	pass  # Kein automatisches Laden – Welt wird explizit per set_world() aktiviert.


# ── Welt aktivieren ───────────────────────────────────────────────────────────

## Aktiviert eine Welt: Erstellt fehlende Ordner und setzt den aktiven Pfad.
## Muss vor dem ersten get/update Aufruf aufgerufen werden.
func set_world(world_name: String) -> void:
	current_world_name = world_name
	_ensure_dir(_world_path())
	_ensure_dir(_world_path() + "players/")
	print("SaveManager: Welt '%s' aktiviert – Pfad: %s" % [world_name, _world_path()])


# ── Welt-Verwaltung ───────────────────────────────────────────────────────────

## Gibt alle vorhandenen Welten-Namen zurück (Unterordner in user://saves/).
func list_available_worlds() -> Array[String]:
	_ensure_dir(SAVES_ROOT)
	var worlds: Array[String] = []
	var dir := DirAccess.open(SAVES_ROOT)
	if dir == null:
		return worlds
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			worlds.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	worlds.sort()
	return worlds


## Liest Metadaten einer Welt (Modus, letztes Spielen) aus world_info.json.
## Gibt ein leeres Dictionary zurück, wenn keine Info-Datei existiert.
func get_world_meta(world_name: String) -> Dictionary:
	return _read_json(SAVES_ROOT + world_name + "/world_info.json", {})


# ── Spieler-Daten ─────────────────────────────────────────────────────────────

## Lädt Spieler-Daten.
##   uuid = ""  → Solo-Modus (player_solo.json)
##   uuid = "…" → Multiplayer (players/[uuid].json)
func get_player_data(uuid: String) -> Dictionary:
	return _read_json(_player_path(uuid), _default_player_data())


## Gibt true zurück, wenn für diese UUID eine Save-Datei existiert.
## Nützlich als Guard, bevor Server-seitige Aktionen erlaubt werden.
func player_file_exists(uuid: String) -> bool:
	return FileAccess.file_exists(_player_path(uuid))


## Speichert Spieler-Daten und aktualisiert world_info.json.
##   uuid = ""  → Solo-Modus
##   uuid = "…" → Multiplayer
func update_player_data(uuid: String, data: Dictionary) -> void:
	_write_json(_player_path(uuid), data)
	_write_world_meta("solo" if uuid.is_empty() else "multiplayer")


# ── Interne Pfad-Helfer ───────────────────────────────────────────────────────

func _world_path() -> String:
	return SAVES_ROOT + current_world_name + "/"


func _player_path(uuid: String) -> String:
	if uuid.is_empty():
		return _world_path() + "player_solo.json"
	return _world_path() + "players/" + uuid + ".json"


func _write_world_meta(mode: String) -> void:
	var meta := {
		"world_name":  current_world_name,
		"mode":        mode,
		"last_played": Time.get_unix_time_from_system(),
	}
	_write_json(SAVES_ROOT + current_world_name + "/world_info.json", meta)


# ── Datei-Helfer ──────────────────────────────────────────────────────────────

func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		var err := DirAccess.make_dir_recursive_absolute(path)
		if err != OK:
			push_error("SaveManager: Konnte Verzeichnis nicht erstellen – %s" % path)


func _read_json(path: String, fallback: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return fallback.duplicate()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Konnte Datei nicht lesen – %s" % path)
		return fallback.duplicate()
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("SaveManager: JSON-Parsing fehlgeschlagen – %s" % path)
		return fallback.duplicate()
	return json.data as Dictionary if json.data is Dictionary else fallback.duplicate()


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Konnte Datei nicht schreiben – %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _default_player_data() -> Dictionary:
	return {
		"skills":        {},
		"hotbar":        ["", "", "", "", "", "", ""],
		"points":        5,
		"last_position": {"x": 0.0, "y": 1.0, "z": 22.0},
	}
