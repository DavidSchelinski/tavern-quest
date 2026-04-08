## Bartender NPC — extends NpcInteractable for dialog, keeps proximity greeting bubble.
extends NpcInteractable

const GREET_RADIUS : float = 5.0

@onready var _speech_bubble : Label3D = $SpeechBubble

var _player_nearby_greet : bool    = false
var _greet_area          : Area3D  = null


func _ready() -> void:
	dialog_path     = "res://data/dialogs/bartender.json"
	npc_name_key    = "NPC_BARTENDER"
	interact_radius = 4.0
	super._ready()
	_speech_bubble.text = tr("BARTENDER_GREETING")
	_build_greet_area()


func _build_greet_area() -> void:
	_greet_area = Area3D.new()
	_greet_area.name            = "GreetArea"
	_greet_area.collision_layer = 0
	_greet_area.collision_mask  = 2   # player layer
	_greet_area.monitoring      = true
	_greet_area.monitorable     = false

	var col   := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = GREET_RADIUS
	col.shape    = shape
	_greet_area.add_child(col)
	add_child(_greet_area)

	_greet_area.body_entered.connect(_on_greet_entered)
	_greet_area.body_exited.connect(_on_greet_exited)


func _on_greet_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _player_nearby_greet:
		return
	_player_nearby_greet = true
	if not _in_dialog:
		_show_bubble(true)


func _on_greet_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	# Only hide if no other player is still inside.
	if _greet_area.get_overlapping_bodies().any(func(b: Node3D) -> bool:
		return b.is_in_group("player") and b != body
	):
		return
	_player_nearby_greet = false
	_show_bubble(false)


func _on_dialog_ended_bartender(npc: Node3D) -> void:
	# Re-show greeting bubble if a player is still in range after dialog ends.
	if npc != self:
		return
	if _player_nearby_greet:
		_show_bubble(true)


func _show_bubble(show: bool) -> void:
	if show:
		_speech_bubble.scale   = Vector3.ZERO
		_speech_bubble.visible = true
		var tw : Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_speech_bubble, "scale", Vector3.ONE, 0.25)
	else:
		var tw : Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(_speech_bubble, "scale", Vector3.ZERO, 0.18)
		tw.tween_callback(func() -> void: _speech_bubble.visible = false)
