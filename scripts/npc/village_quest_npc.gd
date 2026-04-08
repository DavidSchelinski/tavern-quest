## Dorf-NPC: Quest-Kontext, Quest-Abgabe und gemütliches Umherwandern.
## Konfiguration über @export vars in der Szene — keine Unterklasse nötig.
extends NpcInteractable

# ── Quest-Dialog ──────────────────────────────────────────────────────────────
@export var quest_title_key : String = ""
@export var speaker_key     : String = ""
@export var greet_key       : String = ""
@export var context_key     : String = ""
@export var active_key      : String = ""
@export var turnin_key      : String = ""
@export var done_key        : String = ""

# ── Wandern ───────────────────────────────────────────────────────────────────
@export var wander_radius : float = 4.5
@export var wander_speed  : float = 1.1   # m/s
@export var pause_min     : float = 2.0   # Sekunden Pause am Wegpunkt (min)
@export var pause_max     : float = 5.5   # Sekunden Pause am Wegpunkt (max)

var _home_pos     : Vector3
var _wander_tween : Tween = null


func _ready() -> void:
	npc_name_key = speaker_key
	super._ready()
	_home_pos = global_position
	# Leicht versetzt starten damit nicht alle NPCs gleichzeitig loslaufen
	_schedule_wander(randf_range(0.5, pause_max))


# ── Wandern ───────────────────────────────────────────────────────────────────

func _schedule_wander(wait_override : float = -1.0) -> void:
	if not is_inside_tree():
		return
	var wait := wait_override if wait_override >= 0.0 else randf_range(pause_min, pause_max)
	get_tree().create_timer(wait).timeout.connect(_do_wander, CONNECT_ONE_SHOT)


func _do_wander() -> void:
	if _in_dialog or not is_inside_tree():
		_schedule_wander()
		return

	# Zufälligen Punkt innerhalb des Wanderradius wählen
	var angle  := randf() * TAU
	var dist   := randf_range(1.5, wander_radius)
	var target := Vector3(
		_home_pos.x + cos(angle) * dist,
		_home_pos.y,
		_home_pos.z + sin(angle) * dist
	)

	# NPC zur Bewegungsrichtung drehen
	var dir := (target - global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		var target_yaw := atan2(dir.x, dir.z)
		var rot_tween  := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rot_tween.tween_property(self, "rotation:y", target_yaw, 0.25)

	# Zum Wegpunkt gleiten
	var travel_time : float = global_position.distance_to(target) / maxf(wander_speed, 0.1)
	if _wander_tween:
		_wander_tween.kill()
	_wander_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wander_tween.tween_property(self, "global_position", target, travel_time)
	_wander_tween.tween_callback(_schedule_wander.bind(-1.0))


# ── Dialog / Interaktion ──────────────────────────────────────────────────────

## Override: Dialog aus Daten starten + Wandern pausieren.
func interact(player: Node3D) -> void:
	if _in_dialog:
		return
	if player == null or not is_instance_valid(player):
		return

	# Wandern anhalten
	if _wander_tween:
		_wander_tween.kill()
		_wander_tween = null

	_in_dialog    = true
	_hint.visible = false
	_player_ref   = player
	if player.has_method("enter_dialog"):
		player.enter_dialog()
	DialogManager.start_from_data(self, _build_dialog())


## Nach Dialog-Ende Wandern wieder aufnehmen.
func _on_dialog_ended(npc: Node3D) -> void:
	super._on_dialog_ended(npc)
	if npc == self:
		_schedule_wander(1.5)   # kurze Pause, dann weiter


# ── Dialog-Aufbau ─────────────────────────────────────────────────────────────

func _build_dialog() -> Dictionary:
	var is_active : bool = QuestManager.is_quest_active(quest_title_key)
	var is_done   : bool = QuestManager.is_quest_completed(quest_title_key)
	var nodes     : Dictionary = {}

	if is_done:
		nodes["start"] = {
			"speaker": speaker_key,
			"text":    done_key,
			"next":    ""
		}
	elif is_active:
		nodes["start"] = {
			"speaker": speaker_key,
			"text":    active_key,
			"choices": [
				{ "text": "CHOICE_TASK_DONE", "next": "turnin" },
				{ "text": "CHOICE_TELL_MORE",  "next": "context" },
				{ "text": "DIALOG_GOODBYE",    "next": "" }
			]
		}
		nodes["turnin"] = {
			"speaker":       speaker_key,
			"text":          turnin_key,
			"turn_in_quest": { "quest_id": quest_title_key, "item_id": "", "fail": "not_yet" },
			"next":          ""
		}
		nodes["not_yet"] = {
			"speaker": speaker_key,
			"text":    active_key,
			"next":    ""
		}
		nodes["context"] = {
			"speaker": speaker_key,
			"text":    context_key,
			"next":    "start"
		}
	else:
		nodes["start"] = {
			"speaker": speaker_key,
			"text":    greet_key,
			"choices": [
				{ "text": "CHOICE_TELL_MORE", "next": "context" },
				{ "text": "DIALOG_GOODBYE",   "next": "" }
			]
		}
		nodes["context"] = {
			"speaker": speaker_key,
			"text":    context_key,
			"next":    ""
		}

	return { "nodes": nodes }
