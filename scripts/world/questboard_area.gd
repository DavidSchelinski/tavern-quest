## Proximity-based interaction zone for the quest board.
## Shows a hint label when the player is within range and triggers the QuestBoard
## interaction when they press [F].
extends Node3D

const INTERACT_RADIUS := 3.5

var _player_in_range : bool    = false
var _player_ref      : Node3D  = null
var _hint            : Label3D


func _ready() -> void:
	_build_hint_label()


func _build_hint_label() -> void:
	_hint = Label3D.new()
	_hint.text        = "[ F ]  View Quest Board"
	_hint.billboard   = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.font_size   = 26
	_hint.pixel_size  = 0.007
	_hint.modulate    = Color(0.95, 0.88, 0.60, 1)
	_hint.outline_size     = 5
	_hint.outline_modulate = Color(0.08, 0.05, 0.01, 1)
	_hint.visible     = false
	# Position above the collision box centre (box is at roughly Y=2.5, Z=-8.5).
	# Since this node is at the Tavern root origin, use the world-space offset directly.
	_hint.position    = Vector3(0.0, 3.6, -8.5)
	add_child(_hint)


func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node3D

	# Use the collision shape's world position as the board centre.
	var area    := get_node_or_null("Area3D") as Area3D
	var centre  := global_position  # fallback
	if area:
		var shape_node := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape_node:
			centre = shape_node.global_position

	var nearby := player.global_position.distance_to(centre) <= INTERACT_RADIUS
	if nearby == _player_in_range:
		return

	_player_in_range = nearby
	_player_ref      = player if nearby else null
	_hint.visible    = nearby


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if not event.is_action_pressed("interact"):
		return

	var board := get_node_or_null("../QuestBoard")
	if board == null or not board.has_method("interact"):
		push_warning("QuestboardArea: QuestBoard node not found or missing interact().")
		return

	# Set the player's current interactable so exit_board_view can call on_interact_exit.
	if _player_ref:
		_player_ref._current_interactable = board
		board.interact(_player_ref)
		get_viewport().set_input_as_handled()
