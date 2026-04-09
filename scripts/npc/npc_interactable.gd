## Base class for talkable NPCs.
## Provides: "E to talk" billboard, interact() integration, dialog triggering.
##
## Usage: extend this class, set dialog_path and npc_name_key in the subclass or
## via @export, and override _get_dialog_path() if needed.
class_name NpcInteractable
extends Node3D

@export var dialog_path    : String = ""
@export var npc_name_key   : String = ""
@export var interact_radius : float = 4.0

var _hint          : Label3D = null
var _player_nearby : bool    = false
var _player_ref    : Node3D  = null
var _in_dialog     : bool    = false
var _detect_area   : Area3D  = null


func _ready() -> void:
	add_to_group("npc")
	add_to_group("interactable")
	_build_hint()
	_build_detect_area()
	DialogManager.dialog_ended.connect(_on_dialog_ended)


func _build_hint() -> void:
	_hint = Label3D.new()
	_hint.text             = "[E] " + tr("ACTION_INTERACT")
	_hint.billboard        = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.font_size        = 24
	_hint.pixel_size       = 0.007
	_hint.modulate         = Color(0.95, 0.88, 0.60, 1.0)
	_hint.outline_size     = 5
	_hint.outline_modulate = Color(0.08, 0.05, 0.01, 1.0)
	_hint.visible          = false
	_hint.position         = Vector3(0.0, 2.4, 0.0)
	add_child(_hint)


## Uses an Area3D instead of scanning the player group every frame.
func _build_detect_area() -> void:
	_detect_area = Area3D.new()
	_detect_area.name            = "DetectArea"
	_detect_area.collision_layer = 0
	_detect_area.collision_mask  = 2   # player layer
	_detect_area.monitoring      = true
	_detect_area.monitorable     = false

	var col   := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = interact_radius
	col.shape    = shape
	_detect_area.add_child(col)
	add_child(_detect_area)

	_detect_area.body_entered.connect(_on_body_entered)
	_detect_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	# Only react to the local player.
	if body.has_method("_is_mine") and not body.call("_is_mine"):
		return
	_player_nearby = true
	_player_ref    = body
	_hint.visible  = not _in_dialog


func _on_body_exited(body: Node3D) -> void:
	if body != _player_ref:
		return
	_player_nearby = false
	_player_ref    = null
	_hint.visible  = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or _in_dialog:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interact(_player_ref)


func interact(player: Node3D) -> void:
	if _in_dialog:
		return
	if player == null or not is_instance_valid(player):
		return
	_in_dialog    = true
	_hint.visible = false
	_player_ref   = player

	if player.has_method("enter_dialog"):
		player.enter_dialog()

	var path : String = _get_dialog_path()
	if not path.is_empty():
		DialogManager.start(self, path, player)
	else:
		push_warning("NpcInteractable: no dialog_path set for %s" % name)
		_in_dialog = false


func _get_dialog_path() -> String:
	return dialog_path


func _on_dialog_ended(npc: Node3D) -> void:
	if npc != self:
		return
	_in_dialog = false
	var prev := _player_ref
	if prev != null and is_instance_valid(prev):
		if prev.has_method("exit_dialog"):
			prev.exit_dialog()
		# Keep the reference if the player is still within range so the next
		# E-press works correctly (area_entered won't fire again for a body
		# that is already inside the area).
		if not _detect_area.get_overlapping_bodies().has(prev):
			_player_ref = null
	else:
		_player_ref = null
