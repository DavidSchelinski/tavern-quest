extends Node

## Verwaltet die lokale Spieler-Identität (Name + Passwort).
## Wird als Autoload registriert: PlayerProfile
##
## Speicherpfad: user://profiles/[name].json

const PROFILES_PATH := "user://profiles/"
const MAX_NAME_LENGTH := 32
const SALT := "tavern_quest_v1:"

## Name des aktuell eingeloggten Spielers. Leer = noch nicht eingeloggt.
var current_player_name: String = ""

## Verifikationscode für Server-Authentifizierung.
var _current_verification_code: String = ""

signal player_logged_in(player_name: String)


func _ready() -> void:
	_ensure_dir(PROFILES_PATH)


# ── Login ─────────────────────────────────────────────────────────────────────

## Setzt den aktiven Spielernamen, überprüft Passwort und generiert Verifikationscode.
func login(player_name: String, password: String = "") -> bool:
	# Verify password if profile already exists with one
	if profile_exists(player_name):
		var meta := get_profile_meta(player_name)
		var stored_hash: String = meta.get("password_hash", "")
		if stored_hash != "" and _hash_password(password) != stored_hash:
			return false

	current_player_name = player_name
	_current_verification_code = _generate_verification_code(player_name, password)
	_save_profile(player_name, password)
	print("PlayerProfile: Eingeloggt als '%s'" % player_name)
	player_logged_in.emit(player_name)
	return true


## Gibt true zurück, wenn ein Spieler eingeloggt ist.
func is_logged_in() -> bool:
	return not current_player_name.is_empty()


## Gibt den Verifikationscode für Server-Authentifizierung zurück.
func get_verification_code() -> String:
	return _current_verification_code


# ── Passwort ─────────────────────────────────────────────────────────────────

func _hash_password(password: String) -> String:
	if password.is_empty():
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((SALT + password).to_utf8_buffer())
	var hash_bytes := ctx.finish()
	return hash_bytes.hex_encode()


func _generate_verification_code(player_name: String, password: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((player_name + ":" + password).to_utf8_buffer())
	var hash_bytes := ctx.finish()
	return hash_bytes.hex_encode().substr(0, 16)


func verify_password(player_name: String, password: String) -> bool:
	var meta := get_profile_meta(player_name)
	var stored_hash: String = meta.get("password_hash", "")
	if stored_hash.is_empty():
		return true  # No password set
	return _hash_password(password) == stored_hash


func has_password(player_name: String) -> bool:
	var meta := get_profile_meta(player_name)
	return meta.get("password_hash", "") != ""


# ── Profil-Verwaltung ─────────────────────────────────────────────────────────

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


func profile_exists(player_name: String) -> bool:
	if player_name.is_empty():
		return false
	return FileAccess.file_exists(PROFILES_PATH + player_name + ".json")


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


func delete_profile(player_name: String) -> bool:
	var path := PROFILES_PATH + player_name + ".json"
	if not FileAccess.file_exists(path):
		return false
	var err := DirAccess.remove_absolute(path)
	if err == OK:
		print("PlayerProfile: Profil '%s' gelöscht." % player_name)
		if current_player_name == player_name:
			current_player_name = ""
			_current_verification_code = ""
		return true
	return false


func sanitize_name(raw: String) -> String:
	var result := ""
	for i: int in raw.length():
		var code: int = raw.unicode_at(i)
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		var is_safe  := code == 95 or code == 45
		if is_upper or is_lower or is_digit or is_safe:
			result += raw[i]
		if result.length() >= MAX_NAME_LENGTH:
			break
	return result


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

func _save_profile(player_name: String, password: String = "") -> void:
	var path := PROFILES_PATH + player_name + ".json"
	var existing := get_profile_meta(player_name)
	var created_at: float = existing.get("created_at", Time.get_unix_time_from_system()) as float
	var password_hash: String = existing.get("password_hash", "")

	# Only update password hash if a new password is provided
	if not password.is_empty():
		password_hash = _hash_password(password)

	var data := {
		"name":          player_name,
		"password_hash": password_hash,
		"created_at":    created_at,
		"last_login":    Time.get_unix_time_from_system(),
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
