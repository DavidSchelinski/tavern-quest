## Quest board — ray-detected, camera-zoom interaction with parchment UI.
extends Node3D

const QUESTS: Array[Dictionary] = [
	{
		"rank": "E",
		"title": "The Missing Sword",
		"giver": "Aldric the Blacksmith",
		"desc":  "My finest blade was stolen three nights past. Find the thief and return it.",
		"reward": "50 gold",
	},
	{
		"rank": "E",
		"title": "Cellar Rat Infestation",
		"giver": "Mara the Innkeeper",
		"desc":  "Rats have overrun the cellar. Clear them before they eat our winter stores.",
		"reward": "20 gold + free lodging",
	},
	{
		"rank": "D",
		"title": "The Lost Merchant",
		"giver": "Town Guard Captain",
		"desc":  "Merchant Darius vanished on the northern forest road three days ago. Find him.",
		"reward": "100 gold",
	},
	{
		"rank": "C",
		"title": "Ancient Ruins",
		"giver": "Scholar Elara",
		"desc":  "Strange lights flicker in the old ruins east of town each night. Investigate.",
		"reward": "150 gold + rare scroll",
	},
]

@onready var _prompt      : Label3D    = $Prompt
@onready var _board_cam   : Camera3D   = $BoardCamera
@onready var _ui          : CanvasLayer = $BoardUI
@onready var _quest_label : RichTextLabel = $BoardUI/Panel/Margin/QuestText

var _player: Node3D = null


func _ready() -> void:
	_ui.visible = false
	_board_cam.fov = 90.0
	_quest_label.text = _build_quest_bbcode()


# ── Interactable interface ────────────────────────────────────────────────────

func on_look_at() -> void:
	_prompt.visible = true


func on_look_away() -> void:
	_prompt.visible = false


func interact(player: Node3D) -> void:
	_player = player
	_prompt.visible = false
	player.enter_board_view(_board_cam)

	# Camera zoom-in tween, then reveal parchment
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_board_cam, "fov", 52.0, 0.55)
	tween.tween_callback(func() -> void: _ui.visible = true)


func on_interact_exit() -> void:
	_ui.visible = false
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_board_cam, "fov", 90.0, 0.3)
	_player = null


# ── Helpers ───────────────────────────────────────────────────────────────────

func _build_quest_bbcode() -> String:
	var lines: PackedStringArray = []
	lines.append("[center][font_size=22][b]── QUEST BOARD ──[/b][/font_size][/center]\n")
	for q: Dictionary in QUESTS:
		lines.append("[color=#c8a84b][b][Rank %s]  %s[/b][/color]" % [q["rank"], q["title"]])
		lines.append("[color=#6b4f2a]  Posted by: %s[/color]" % q["giver"])
		lines.append("  %s" % q["desc"])
		lines.append("[color=#5a8a3c]  ★ Reward: %s[/color]\n" % q["reward"])
	lines.append("\n[center][color=#888][i][ F ] or [ Esc ] to close[/i][/color][/center]")
	return "\n".join(lines)
