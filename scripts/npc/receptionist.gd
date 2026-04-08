## Receptionist NPC — shows the player's guild rank and distributes
## rewards for quests accepted at the quest board.
extends NpcInteractable


func _ready() -> void:
	npc_name_key    = "NPC_RECEPTIONIST"
	interact_radius = 3.5
	super._ready()


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
	DialogManager.start_from_data(self, _build_dialog_data())


# ── Dialog construction ───────────────────────────────────────────────────────

func _build_dialog_data() -> Dictionary:
	var choices : Array = []

	# Always offer rank overview.
	choices.append({ "text": "RECEPTIONIST_CHOICE_RANK", "next": "rank_info" })

	# Reward collection if applicable.
	if not QuestManager.get_unrewarded_board_quests().is_empty():
		choices.append({ "text": "RECEPTIONIST_COLLECT_ALL", "next": "collect" })

	choices.append({ "text": "DIALOG_GOODBYE", "next": "" })

	var nodes : Dictionary = {
		"start": {
			"speaker": "NPC_RECEPTIONIST",
			"text":    "RECEPTIONIST_GREETING",
			"choices": choices
		},
		"rank_info": {
			"speaker": "NPC_RECEPTIONIST",
			"text":    _build_rank_text(),
			"next":    ""
		},
		"collect": {
			"speaker":                  "NPC_RECEPTIONIST",
			"text":                     "RECEPTIONIST_REWARD_GIVEN",
			"collect_all_board_rewards": true,
			"next":                     ""
		}
	}

	return { "nodes": nodes }


func _build_rank_text() -> String:
	var rank     : String = GuildRankManager.get_rank()
	var pts      : int    = GuildRankManager.get_points()
	var needed   : int    = GuildRankManager.get_points_needed()
	var is_max   : bool   = GuildRankManager.is_max_rank()
	var is_ready : bool   = GuildRankManager.is_promotion_ready()
	var active   : bool   = QuestManager.is_quest_active(GuildRankManager.get_promo_quest_key())

	var lines : PackedStringArray = []
	lines.append(tr("RECEPTIONIST_RANK_INFO_FMT") % [rank, pts, needed if not is_max else pts])

	if is_max:
		lines.append(tr("RECEPTIONIST_RANK_MAX"))
	elif active:
		lines.append(tr("RECEPTIONIST_PROMO_ACTIVE"))
	elif is_ready:
		lines.append(tr("RECEPTIONIST_RANK_READY"))
	else:
		lines.append(tr("RECEPTIONIST_RANK_PROGRESS") % [needed - pts])

	return "\n".join(lines)
