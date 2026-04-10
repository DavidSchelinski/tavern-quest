extends Node

## Tracks which skills the player has unlocked and their current levels,
## plus the 7-slot active-skill hotbar.
##
## Multiplayer-Architektur:
##   - Clients rufen request_buy_skill.rpc_id(1, skill_id) auf.
##   - Der Server validiert, aktualisiert, speichert und sendet sync_skill_data zurück.
##   - Singleplayer: _do_unlock_skill() wird direkt aufgerufen.

# Key: skill id (String) → Value: current level (int)
var _unlocked_skills: Dictionary = {}

# 7 hotbar slots, each holds a skill id or "" for empty.
var _hotbar: Array = ["", "", "", "", "", "", ""]

@export var skill_points: int = 5

## Eindeutige Spieler-ID (NICHT die Netzwerk-Peer-ID!) für Save/Load.
## Im Solo-Modus bleibt diese leer ("") → speichert nach player_solo.json.
var player_uuid: String = ""

## Letzte gespeicherte Weltposition (wird vom GameManager vor dem Speichern gesetzt).
var last_position: Vector3 = Vector3(0.0, 1.0, 22.0)

## Wird emittiert, wenn der Server neue Skill-Daten synchronisiert hat.
signal skill_data_synced

## Wird emittiert, wenn der Server explizit bestätigt, dass alle Daten vollständig
## übertragen wurden (nach sync_skill_data). Sicherer Zeitpunkt für UI-Initialisierung.
signal skill_initialized


func can_unlock_skill(skill_data: SkillData, current_player_level: int) -> bool:
	if skill_points <= 0:
		return false
	if current_player_level < skill_data.required_player_level:
		return false
	var current_level: int = _unlocked_skills.get(skill_data.id, 0) as int
	if current_level >= skill_data.max_level:
		return false
	for prereq_id: String in skill_data.prerequisite_skills:
		if not _unlocked_skills.has(prereq_id):
			return false
	return true


## Interne Kauf-Logik. Nur direkt aufrufen in Singleplayer oder auf dem Server.
func _do_unlock_skill(skill_id: String) -> void:
	var current_level: int = _unlocked_skills.get(skill_id, 0) as int
	_unlocked_skills[skill_id] = current_level + 1
	skill_points -= 1


## Client sendet diese RPC-Anfrage an den Server (rpc_id(1, ...)).
## Der Server validiert, aktualisiert und sendet die Daten via sync_skill_data zurück.
## call_local: Läuft auch lokal, aber der is_server()-Guard verhindert doppelte Ausführung beim Client.
@rpc("any_peer", "call_local", "reliable")
func request_buy_skill(skill_id: String) -> void:
	if not multiplayer.is_server():
		return

	# Guard: Im Multiplayer muss die UUID gesetzt sein, bevor ein Kauf erlaubt wird.
	# Verhindert Käufe eines noch nicht vollständig initialisierten Clients.
	# Die Save-Datei darf dabei noch nicht existieren (neue Welt, erster Kauf) –
	# update_player_data() legt sie beim ersten Speichern automatisch an.
	if multiplayer.has_multiplayer_peer() and player_uuid.is_empty():
		push_warning("SkillsComponent: request_buy_skill abgelehnt – UUID noch nicht gesetzt.")
		return

	# Serverseitige Validierung (Basis-Check: Punkte vorhanden, Skill nicht über Level-Cap)
	if skill_points <= 0:
		push_warning("SkillsComponent: Kein Skillpunkt für '%s' – Anfrage abgelehnt." % skill_id)
		return
	var current_level: int = _unlocked_skills.get(skill_id, 0) as int
	if current_level >= 99:
		return

	# Kauf ausführen
	_unlocked_skills[skill_id] = current_level + 1
	skill_points -= 1

	# Authoritative Daten zurück an den anfragenden Client senden.
	# get_remote_sender_id() = 0 wenn lokal aufgerufen (Host), dann kein RPC nötig.
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != 0:
		sync_skill_data.rpc_id(sender_id, skill_points, _unlocked_skills.duplicate())

	# Persistieren (nur Server speichert)
	if player_uuid != "":
		SaveManager.update_player_data(player_uuid, get_save_data())


## Server sendet die autoritativen Skill-Daten an einen Client.
## Hinweis: "any_peer" statt "authority", weil die Node-Authority die Peer-ID des Spielers ist,
## nicht die des Servers – der Server muss aber senden können.
## call_local: Wenn der Server es lokal aufruft, ist es ein harmloser No-op (Daten sind gleich).
@rpc("any_peer", "call_local", "reliable")
func sync_skill_data(points: int, unlocked: Dictionary) -> void:
	skill_points     = points
	_unlocked_skills = unlocked
	skill_data_synced.emit()


## Wird vom Server gesendet, NACHDEM sync_skill_data angekommen ist.
## Garantiert dem Client, dass alle Daten übertragen sind und das UI sicher
## initialisiert werden kann. Reliable RPCs kommen in Sendreihenfolge an.
@rpc("any_peer", "call_local", "reliable")
func force_ui_refresh() -> void:
	skill_data_synced.emit()
	skill_initialized.emit()


func get_skill_level(skill_id: String) -> int:
	return _unlocked_skills.get(skill_id, 0) as int


func equip_skill(skill_id: String, hotbar_index: int) -> void:
	if hotbar_index < 0 or hotbar_index > 6:
		return
	_hotbar[hotbar_index] = skill_id


# ── Save / Load ───────────────────────────────────────────────────────────────

## Gibt alle relevanten Daten für den SaveManager zurück.
## last_position muss vom GameManager vor diesem Aufruf gesetzt werden.
func get_save_data() -> Dictionary:
	return {
		"skills":        _unlocked_skills.duplicate(),
		"hotbar":        _hotbar.duplicate(),
		"points":        skill_points,
		"last_position": {"x": last_position.x, "y": last_position.y, "z": last_position.z},
	}


## Überschreibt die lokalen Werte mit geladenen Save-Daten.
func apply_save_data(data: Dictionary) -> void:
	if data.has("skills") and data["skills"] is Dictionary:
		_unlocked_skills = data["skills"] as Dictionary
	if data.has("hotbar") and data["hotbar"] is Array:
		_hotbar = data["hotbar"] as Array
	if data.has("points") and data["points"] is float:
		# JSON lädt Zahlen als float, daher cast zu int
		skill_points = int(data["points"])
	elif data.has("points") and data["points"] is int:
		skill_points = data["points"] as int
	if data.has("last_position") and data["last_position"] is Dictionary:
		var lp: Dictionary = data["last_position"] as Dictionary
		last_position = Vector3(
			float(lp.get("x", 0.0)),
			float(lp.get("y", 1.0)),
			float(lp.get("z", 22.0)),
		)
	skill_data_synced.emit()
