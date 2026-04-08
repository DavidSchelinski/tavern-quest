## Guild Leader NPC — grants promotion quests when the player has
## accumulated enough quest points for their current rank.
extends NpcInteractable


func _ready() -> void:
	npc_name_key    = "NPC_GUILD_LEADER"
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
	var rank      : String = GuildRankManager.get_rank()
	var pts       : int    = GuildRankManager.get_points()
	var needed    : int    = GuildRankManager.get_points_needed()
	var promo_key : String = GuildRankManager.get_promo_quest_key()
	var is_max    : bool   = GuildRankManager.is_max_rank()
	var is_ready  : bool   = GuildRankManager.is_promotion_ready()
	var promo_active : bool = not promo_key.is_empty() and QuestManager.is_quest_active(promo_key)

	if is_max:
		return _dialog_max_rank()
	if promo_active:
		return _dialog_promo_active()
	if is_ready:
		return _dialog_offer_promo(rank, promo_key)
	return _dialog_not_ready(rank, pts, needed)


func _dialog_max_rank() -> Dictionary:
	return { "nodes": { "start": {
		"speaker": "NPC_GUILD_LEADER",
		"text":    "GUILD_LEADER_MAX_RANK",
		"next":    ""
	} } }


func _dialog_promo_active() -> Dictionary:
	return { "nodes": { "start": {
		"speaker": "NPC_GUILD_LEADER",
		"text":    "GUILD_LEADER_PROMO_ACTIVE",
		"next":    ""
	} } }


func _dialog_not_ready(rank: String, pts: int, needed: int) -> Dictionary:
	var text : String = tr("GUILD_LEADER_NOT_READY_FMT") % [rank, needed - pts]
	return { "nodes": { "start": {
		"speaker": "NPC_GUILD_LEADER",
		"text":    text,
		"next":    ""
	} } }


func _dialog_offer_promo(rank: String, promo_key: String) -> Dictionary:
	var next_rank : String = GuildRankManager.RANKS[GuildRankManager.get_rank_index() + 1]
	var offer_text : String = tr("GUILD_LEADER_PROMO_OFFER_FMT") % next_rank

	var promo_quest : Dictionary = {
		"source":     "promotion",
		"rank":       rank,
		"title_key":  promo_key,
		"giver_key":  "NPC_GUILD_LEADER",
		"desc_key":   "QUEST_PROMO_DESC",
		"reward_key": "QUEST_PROMO_REWARD_FMT",
	}

	return { "nodes": {
		"start": {
			"speaker": "NPC_GUILD_LEADER",
			"text":    offer_text,
			"choices": [
				{ "text": "GUILD_LEADER_ACCEPT_PROMO", "next": "give_promo" },
				{ "text": "DIALOG_GOODBYE",            "next": ""           }
			]
		},
		"give_promo": {
			"speaker":    "NPC_GUILD_LEADER",
			"text":       "GUILD_LEADER_PROMO_GIVEN",
			"give_quest": promo_quest,
			"next":       ""
		}
	} }
