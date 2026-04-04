## Bartender NPC — greets the player when they step within 5 m.
## Uses distance polling instead of Area3D so it works regardless of collision layers.
extends Node3D

const GREET_RADIUS := 5.0

@onready var _speech_bubble : Label3D = $SpeechBubble

var _player_nearby : bool = false


func _ready() -> void:
	add_to_group("npc")


func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node3D
	var nearby := global_position.distance_to(player.global_position) <= GREET_RADIUS
	if nearby == _player_nearby:
		return
	_player_nearby = nearby
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
