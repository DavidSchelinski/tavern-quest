## Base class for talkable NPCs.
## Provides: "E to talk" billboard, interact() integration, dialog triggering.
##
## Usage: extend this class, set dialog_path and npc_name_key in the subclass or
## via @export, and override _get_dialog_path() if needed.
class_name NpcInteractable
extends Node3D

## Path to the dialog JSON file (e.g. "res://data/dialogs/bartender.json")
@export var dialog_path : String = ""

## Translation key for the NPC's display name
@export var npc_name_key : String = ""

## How close the player must be to see the interact hint
@export var interact_radius : float = 4.0

var _hint           : Label3D
var _player_nearby  : bool   = false
var _player_ref     : Node3D = null
var _in_dialog      : bool   = false


func _ready() -> void:
	add_to_group("npc")
	add_to_group("interactable")
	_build_hint()
	DialogManager.dialog_ended.connect(_on_dialog_ended)


func _build_hint() -> void:
	_hint = Label3D.new()
	_hint.text        = "[E] " + tr("ACTION_INTERACT")
	_hint.billboard   = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.font_size   = 24
	_hint.pixel_size  = 0.007
	_hint.modulate    = Color(0.95, 0.88, 0.60, 1)
	_hint.outline_size     = 5
	_hint.outline_modulate = Color(0.08, 0.05, 0.01, 1)
	_hint.visible     = false
	_hint.position    = Vector3(0, 2.4, 0)
	add_child(_hint)


func _process(_delta: float) -> void:
	if _in_dialog:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	# Find nearest local player
	var nearest : Node3D = null
	var nearest_dist := INF
	for p in players:
		var d := global_position.distance_to(p.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = p

	var nearby := nearest_dist <= interact_radius
	if nearby == _player_nearby:
		return

	_player_nearby = nearby
	_player_ref    = nearest if nearby else null
	_hint.visible  = nearby and not _in_dialog


func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or _in_dialog:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interact(_player_ref)


## Called when the player interacts (raycast or proximity).
func interact(player: Node3D) -> void:
	if _in_dialog:
		return
	_in_dialog = true
	_hint.visible = false
	_player_ref = player

	# Put player into dialog state
	if player.has_method("enter_dialog"):
		player.enter_dialog()

	# Start dialog
	var path := _get_dialog_path()
	if not path.is_empty():
		DialogManager.start(self, path)
	else:
		push_warning("NpcInteractable: no dialog_path set for %s" % name)
		_in_dialog = false


## Override in subclass to dynamically choose a dialog file.
func _get_dialog_path() -> String:
	return dialog_path


func _on_dialog_ended(npc: Node3D) -> void:
	if npc != self:
		return
	_in_dialog = false
	if _player_ref and _player_ref.has_method("exit_dialog"):
		_player_ref.exit_dialog()
	_player_ref = null
