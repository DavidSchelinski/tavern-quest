## Bartender NPC — extends NpcInteractable for dialog, keeps proximity greeting bubble.
extends NpcInteractable

const GREET_RADIUS := 5.0

@onready var _speech_bubble : Label3D = $SpeechBubble

var _player_nearby_greet : bool = false


func _ready() -> void:
	dialog_path    = "res://data/dialogs/bartender.json"
	npc_name_key   = "NPC_BARTENDER"
	interact_radius = 4.0
	super._ready()
	_speech_bubble.text = tr("BARTENDER_GREETING")


func _process(delta: float) -> void:
	super._process(delta)
	if _in_dialog:
		if _speech_bubble.visible:
			_show_bubble(false)
		return
	_update_greeting()


func _update_greeting() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node3D
	var nearby := global_position.distance_to(player.global_position) <= GREET_RADIUS
	if nearby == _player_nearby_greet:
		return
	_player_nearby_greet = nearby
	_show_bubble(nearby)


func _show_bubble(visible_state: bool) -> void:
	if visible_state:
		_speech_bubble.scale   = Vector3.ZERO
		_speech_bubble.visible = true
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_speech_bubble, "scale", Vector3.ONE, 0.25)
	else:
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(_speech_bubble, "scale", Vector3.ZERO, 0.18)
		tw.tween_callback(func() -> void: _speech_bubble.visible = false)
