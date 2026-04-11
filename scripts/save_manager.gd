extends Node

## Persistiert alle Spieler-Daten über Sessions hinweg.
##
## Ordner-Struktur:
##   user://saves/[world_name]/players/[player_name].json   ← pro Spieler
##   user://saves/[world_name]/world_info.json              ← Metadaten
##
## Spieler werden jetzt über ihren NAME identifiziert, nicht per UUID.
## Das löst das Debug-PID-Problem (Saves gingen nach Neustart verloren).

const SAVES_ROOT := "user://saves/"

## Name der aktuell aktiven Welt.
var current_world_name: String = "default"


func _ready() -> void:
	pass


# ── Welt aktivieren ───────────────────────────────────────────────────────────

## Aktiviert eine Welt: erstellt fehlende Ordner, setzt den aktiven Pfad.
## Muss vor dem ersten get/update aufgerufen werden.
func set_world(world_name: String) -> void:
	current_world_name = world_name
	_ensure_dir(_world_path())
	_ensure_dir(_world_path() + "players/")
	print("SaveManager: Welt '%s' aktiviert – %s" % [world_name, _world_path()])


# ── Welt-Verwaltung ───────────────────────────────────────────────────────────

## Gibt alle vorhandenen Welten-Namen zurück.
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


## Liest Metadaten einer Welt aus world_info.json.
func get_world_meta(world_name: String) -> Dictionary:
	return _read_json(SAVES_ROOT + world_name + "/world_info.json", {})


# ── Spieler-Daten ─────────────────────────────────────────────────────────────

## Lädt alle Spielerdaten für den angegebenen Spielernamen.
## Gibt Default-Werte zurück wenn keine Save-Datei existiert.
func get_player_data(player_name: String) -> Dictionary:
	return _read_json(_player_path(player_name), _default_player_data())


## Gibt true zurück wenn eine Save-Datei für diesen Spieler existiert.
func player_file_exists(player_name: String) -> bool:
	return FileAccess.file_exists(_player_path(player_name))


## Speichert alle Spielerdaten und aktualisiert world_info.json.
func update_player_data(player_name: String, data: Dictionary) -> void:
	_write_json(_player_path(player_name), data)
	_write_world_meta()
	print("SaveManager: '%s' gespeichert → %s" % [player_name, _player_path(player_name)])


## Gibt alle Spielernamen zurück die in dieser Welt eine Save-Datei haben.
func list_players_in_world() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(_world_path() + "players/")
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			result.append(entry.trim_suffix(".json"))
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


# ── Welt-Zustand ─────────────────────────────────────────────────────────────

## Speichert den Welt-Zustand (Dropped Items, NPC-States, Tageszeit).
func save_world_state(data: Dictionary) -> void:
	_write_json(_world_path() + "world_state.json", data)


## Lädt den Welt-Zustand. Gibt leeres Dict zurück wenn keine Datei existiert.
func load_world_state() -> Dictionary:
	return _read_json(_world_path() + "world_state.json", {})


## Löscht eine komplette Welt (Ordner + alle Spieler-Saves).
func delete_world(world_name: String) -> bool:
	var path := SAVES_ROOT + world_name + "/"
	if not DirAccess.dir_exists_absolute(path):
		return false
	var success := _delete_dir_recursive(path)
	if success:
		print("SaveManager: Welt '%s' gelöscht." % world_name)
	return success


func _delete_dir_recursive(path: String) -> bool:
	var dir := DirAccess.open(path)
	if dir == null:
		return false
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full := path + entry
		if dir.current_is_dir():
			_delete_dir_recursive(full + "/")
		else:
			DirAccess.remove_absolute(full)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
	return true


# ── Interne Pfad-Helfer ───────────────────────────────────────────────────────

func _world_path() -> String:
	return SAVES_ROOT + current_world_name + "/"


func _player_path(player_name: String) -> String:
	if player_name.is_empty():
		return _world_path() + "players/_solo.json"
	return _world_path() + "players/" + player_name + ".json"


func _write_world_meta() -> void:
	var meta := {
		"world_name":  current_world_name,
		"last_played": Time.get_unix_time_from_system(),
	}
	_write_json(_world_path() + "world_info.json", meta)


# ── Datei-Helfer ──────────────────────────────────────────────────────────────

func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		var err := DirAccess.make_dir_recursive_absolute(path)
		if err != OK:
			push_error("SaveManager: Verzeichnis nicht erstellbar – %s" % path)


func _read_json(path: String, fallback: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return fallback.duplicate(true)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Datei nicht lesbar – %s" % path)
		return fallback.duplicate(true)
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("SaveManager: JSON-Fehler – %s" % path)
		return fallback.duplicate(true)
	return json.data as Dictionary if json.data is Dictionary else fallback.duplicate(true)


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Datei nicht schreibbar – %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _default_player_data() -> Dictionary:
	return {
		# Skills
		"skills":        {},
		"hotbar":        ["", "", "", "", "", "", ""],
		"points":        5,
		# Position
		"last_position": {"x": 0.0, "y": 1.0, "z": 22.0},
		# Inventar
		"inventory":     [],
		# Gold
		"gold":          0,
		# Equipment
		"equipment": {
			"helm": null, "torso": null, "pants": null,
			"shoes": null, "left_hand": null, "right_hand": null, "neck": null,
		},
		# Stats
		"stats_data": {
			"stats": {
				"strength":  1,
				"agility":   1,
				"defense":   1,
				"endurance": 1,
				"charisma":  1,
				"stamina":   1,
			},
			"stat_points": 5,
		},
		# Quests
		"quests_data": {
			"active":    [],
			"completed": [],
		},
		# Gilde
		"guild_data": {
			"rank_index": 0,
			"points":     0,
		},
		# Vitals
		"hp":      -1.0,   # -1 = max HP (wird beim Laden berechnet)
		"stamina": 100.0,
	}
