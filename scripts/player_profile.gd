extends Node

## Verwaltet die lokale Spieler-Identität (Name-basiert).
## Ersetzt das UUID/PID-System vollständig.
## Wird als Autoload registriert: PlayerProfile
##
## Speicherpfad: user://profiles/[name].json

const PROFILES_PATH := "user://profiles/"
const MAX_NAME_LENGTH := 32

## Name des aktuell eingeloggten Spielers. Leer = noch nicht eingeloggt.
var current_player_name: String = ""

signal player_logged_in(player_name: String)


func _ready() -> void:
	_ensure_dir(PROFILES_PATH)


# ── Login ─────────────────────────────────────────────────────────────────────

## Setzt den aktiven Spielernamen und speichert das Profil.
## Muss vor dem Start einer Welt aufgerufen werden.
func login(player_name: String) -> void:
	current_player_name = player_name
	_save_profile(player_name)
	print("PlayerProfile: Eingeloggt als '%s'" % player_name)
	player_logged_in.emit(player_name)


## Gibt true zurück, wenn ein Spieler eingeloggt ist.
func is_logged_in() -> bool:
	return not current_player_name.is_empty()


# ── Profil-Verwaltung ─────────────────────────────────────────────────────────

## Gibt alle vorhandenen Profilnamen alphabetisch sortiert zurück.
func list_profiles() -> Array[String]:
	_ensure_dir(PROFILES_PATH)
	var profiles: Array[String] = []
	var dir := DirAccess.open(PROFILES_PATH)
	if dir == null:
		return profiles
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json") and not entry.begins_with("."):
			profiles.append(entry.trim_suffix(".json"))
		entry = dir.get_next()
	dir.list_dir_end()
	profiles.sort()
	return profiles


## Gibt true zurück wenn ein Profil mit diesem Namen existiert.
func profile_exists(player_name: String) -> bool:
	if player_name.is_empty():
		return false
	return FileAccess.file_exists(PROFILES_PATH + player_name + ".json")


## Liest Metadaten eines Profils (last_login etc.).
func get_profile_meta(player_name: String) -> Dictionary:
	var path := PROFILES_PATH + player_name + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data as Dictionary if json.data is Dictionary else {}


## Bereinigt einen Profilnamen: nur Buchstaben, Zahlen, _ und -.
## Gibt einen leeren String zurück wenn der Name komplett ungültig ist.
func sanitize_name(raw: String) -> String:
	var result := ""
	for i: int in raw.length():
		var code: int = raw.unicode_at(i)
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		var is_safe  := code == 95 or code == 45   # _ oder -
		if is_upper or is_lower or is_digit or is_safe:
			result += raw[i]
		if result.length() >= MAX_NAME_LENGTH:
			break
	return result


## Gibt eine lesbare Fehlermeldung zurück wenn der Name ungültig ist, sonst "".
func validate_name(raw: String) -> String:
	if raw.strip_edges().is_empty():
		return "Name darf nicht leer sein."
	var clean := sanitize_name(raw.strip_edges())
	if clean.is_empty():
		return "Erlaubt: Buchstaben, Zahlen, _ und -"
	if clean.length() < 3:
		return "Mindestens 3 Zeichen erforderlich."
	return ""


# ── Intern ────────────────────────────────────────────────────────────────────

func _save_profile(player_name: String) -> void:
	var path := PROFILES_PATH + player_name + ".json"
	var existing := get_profile_meta(player_name)
	var created_at: float = existing.get("created_at", Time.get_unix_time_from_system()) as float
	var data := {
		"name":       player_name,
		"created_at": created_at,
		"last_login": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("PlayerProfile: Konnte Profil nicht speichern – %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		var err := DirAccess.make_dir_recursive_absolute(path)
		if err != OK:
			push_error("PlayerProfile: Konnte Verzeichnis nicht erstellen – %s" % path)
