## Quest board — ray-detected, camera-zoom interaction with parchment UI.
extends Node3D

const QUESTS: Array[Dictionary] = [
	{
		"rank": "E",
		"title_key": "QUEST_MISSING_SWORD",
		"giver_key": "QUEST_MISSING_SWORD_GIVER",
		"desc_key":  "QUEST_MISSING_SWORD_DESC",
		"reward_key": "QUEST_MISSING_SWORD_REWARD",
	},
	{
		"rank": "E",
		"title_key": "QUEST_CELLAR_RATS",
		"giver_key": "QUEST_CELLAR_RATS_GIVER",
		"desc_key":  "QUEST_CELLAR_RATS_DESC",
		"reward_key": "QUEST_CELLAR_RATS_REWARD",
	},
	{
		"rank": "D",
		"title_key": "QUEST_LOST_MERCHANT",
		"giver_key": "QUEST_LOST_MERCHANT_GIVER",
		"desc_key":  "QUEST_LOST_MERCHANT_DESC",
		"reward_key": "QUEST_LOST_MERCHANT_REWARD",
	},
	{
		"rank": "C",
		"title_key": "QUEST_ANCIENT_RUINS",
		"giver_key": "QUEST_ANCIENT_RUINS_GIVER",
		"desc_key":  "QUEST_ANCIENT_RUINS_DESC",
		"reward_key": "QUEST_ANCIENT_RUINS_REWARD",
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
	lines.append("[center][font_size=22][b]%s[/b][/font_size][/center]\n" % tr("QUEST_BOARD_TITLE"))
	for q: Dictionary in QUESTS:
		lines.append("[color=#c8a84b][b][Rank %s]  %s[/b][/color]" % [q["rank"], tr(q["title_key"])])
		lines.append("[color=#6b4f2a]  %s %s[/color]" % [tr("QUEST_POSTED_BY"), tr(q["giver_key"])])
		lines.append("  %s" % tr(q["desc_key"]))
		lines.append("[color=#5a8a3c]  %s %s[/color]\n" % [tr("QUEST_REWARD"), tr(q["reward_key"])])
	lines.append("\n[center][color=#888][i]%s[/i][/color][/center]" % tr("QUEST_CLOSE_HINT"))
	return "\n".join(lines)
