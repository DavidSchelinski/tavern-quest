extends Node

signal quests_changed
signal quest_completed(quest: Dictionary)
signal group_reward_received(quest: Dictionary, gold_share: int)

## A quest Dictionary must contain:
##   "title_key"  : String  – translation key for the title
##   "giver_key"  : String  – translation key for the NPC name
##   "desc_key"   : String  – translation key for the description
##   "reward_key" : String  – translation key for the reward text
##   "rank"       : String  – rank letter (F / E / D / C / B / A / S / S+ / S++)

var _active_quests    : Array[Dictionary] = []
var _completed_quests : Array[Dictionary] = []


func _ready() -> void:
	pass


# ── Public API ────────────────────────────────────────────────────────────────

## Accept a quest. Returns false if already active or completed.
## If the player is in a group, the quest is shared with all group members.
func accept_quest(quest: Dictionary) -> bool:
	var id : String = _quest_id(quest)
	if id.is_empty() or is_quest_active(id) or is_quest_completed(id):
		return false
	_active_quests.append(quest.duplicate())
	quests_changed.emit()

	# Sync to server if we're a guest
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_rpc_server_accept_quest.rpc_id(1, quest.duplicate())

	# Group quest sharing: if in a group, share with all members via server
	var player_name := _get_player_name()
	if not player_name.is_empty():
		var group_name := AdventureGroupManager.get_player_group(player_name)
		if not group_name.is_empty():
			var group_quest := quest.duplicate()
			group_quest["group_quest"] = true
			# Mark our own copy as group quest too
			for i : int in _active_quests.size():
				if _quest_id(_active_quests[i]) == id:
					_active_quests[i]["group_quest"] = true
					break
			quests_changed.emit()
			if multiplayer.has_multiplayer_peer():
				if multiplayer.is_server():
					_distribute_group_quest(group_name, player_name, group_quest)
				else:
					_rpc_share_quest_with_group.rpc_id(1, group_quest)

	return true


## Mark an active quest as completed. Returns false if not found.
func complete_quest(quest_id: String) -> bool:
	for i : int in _active_quests.size():
		if _quest_id(_active_quests[i]) == quest_id:
			var q : Dictionary = _active_quests[i]
			_active_quests.remove_at(i)
			_completed_quests.append(q)
			quest_completed.emit(q)
			quests_changed.emit()

			# If this was a group quest, notify server to reward all members
			if q.get("group_quest", false) and multiplayer.has_multiplayer_peer():
				if multiplayer.is_server():
					_handle_group_quest_completion(q)
				else:
					_rpc_complete_group_quest.rpc_id(1, q.duplicate())

			return true
	return false


func is_quest_active(quest_id: String) -> bool:
	for q : Dictionary in _active_quests:
		if _quest_id(q) == quest_id:
			return true
	return false


func is_quest_completed(quest_id: String) -> bool:
	for q : Dictionary in _completed_quests:
		if _quest_id(q) == quest_id:
			return true
	return false


func get_active_quests() -> Array[Dictionary]:
	return _active_quests


func get_completed_quests() -> Array[Dictionary]:
	return _completed_quests


func get_active_count() -> int:
	return _active_quests.size()


## Returns completed board quests whose reward has not yet been collected.
func get_unrewarded_board_quests() -> Array[Dictionary]:
	var result : Array[Dictionary] = []
	for q : Dictionary in _completed_quests:
		if q.get("source", "") == "board" and not q.get("rewarded", false):
			result.append(q)
	return result


## Returns true if any completed board quest still has an uncollected reward.
func has_uncollected_board_rewards() -> bool:
	for q : Dictionary in _completed_quests:
		if q.get("source", "") == "board" and not q.get("rewarded", false):
			return true
	return false


## Marks all completed board quests as rewarded.
func mark_all_board_rewards_collected() -> void:
	var changed : bool = false
	for i : int in _completed_quests.size():
		if _completed_quests[i].get("source", "") == "board" \
				and not _completed_quests[i].get("rewarded", false):
			_completed_quests[i]["rewarded"] = true
			changed = true
	if changed:
		quests_changed.emit()


# ── Multiplayer RPCs ─────────────────────────────────────────────────────────

## Server → Client: sync full quest state on join.
@rpc("any_peer", "call_local", "reliable")
func sync_quests(data: Dictionary) -> void:
	apply_save_data(data)


## Guest → Server: sync quest acceptance so the server copy stays up to date.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_server_accept_quest(quest: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id : String = _quest_id(quest)
	if id.is_empty() or is_quest_active(id) or is_quest_completed(id):
		return
	_active_quests.append(quest.duplicate())
	quests_changed.emit()


## Guest → Server: share a quest with all group members.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_share_quest_with_group(quest: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var player_name := _get_player_name()
	var group_name := AdventureGroupManager.get_player_group(player_name)
	if group_name.is_empty():
		return
	_distribute_group_quest(group_name, player_name, quest)


## Guest → Server: notify that a group quest was completed.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_complete_group_quest(quest: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	# Also complete on the server's copy of this player
	var id := _quest_id(quest)
	if is_quest_active(id):
		for i : int in _active_quests.size():
			if _quest_id(_active_quests[i]) == id:
				var q := _active_quests[i]
				_active_quests.remove_at(i)
				_completed_quests.append(q)
				break
	_handle_group_quest_completion(quest)


## Server → Client: give a quest from a group member.
@rpc("any_peer", "call_local", "reliable")
func _rpc_receive_group_quest(quest: Dictionary) -> void:
	var id : String = _quest_id(quest)
	if id.is_empty() or is_quest_active(id) or is_quest_completed(id):
		return
	var q := quest.duplicate()
	q["group_quest"] = true
	_active_quests.append(q)
	quests_changed.emit()


## Server → Client: notify group quest reward.
@rpc("any_peer", "call_local", "reliable")
func _rpc_receive_group_reward(quest: Dictionary, gold_share: int) -> void:
	# Complete the quest locally if still active
	var id := _quest_id(quest)
	if is_quest_active(id):
		for i : int in _active_quests.size():
			if _quest_id(_active_quests[i]) == id:
				var q := _active_quests[i]
				_active_quests.remove_at(i)
				_completed_quests.append(q)
				quests_changed.emit()
				break

	# Add gold reward
	if gold_share > 0:
		var inventory : Node = get_parent().get_node_or_null("Inventory")
		if inventory != null:
			inventory.add_gold(gold_share)

	group_reward_received.emit(quest, gold_share)


# ── Server-side group quest logic ────────────────────────────────────────────

## Distribute a quest to all group members except the one who accepted it.
func _distribute_group_quest(group_name: String, acceptor_name: String, quest: Dictionary) -> void:
	var members := AdventureGroupManager.get_group_members(group_name)
	var players_node := get_parent().get_parent()  # GameManager/Players
	if players_node == null:
		return

	for child : Node in players_node.get_children():
		var skills : Node = child.get_node_or_null("Skills")
		if skills == null:
			continue
		var name : String = skills.player_uuid
		if name == acceptor_name or name not in members:
			continue
		var quests : Node = child.get_node_or_null("Quests")
		if quests == null:
			continue

		# Accept on server copy
		var id := _quest_id(quest)
		if not quests.is_quest_active(id) and not quests.is_quest_completed(id):
			var q := quest.duplicate()
			q["group_quest"] = true
			quests._active_quests.append(q)
			quests.quests_changed.emit()

		# Sync to client
		var peer_id := int(str(child.name))
		if peer_id != 1:
			quests._rpc_receive_group_quest.rpc_id(peer_id, quest)


## Handle group quest completion: reward all group members.
func _handle_group_quest_completion(quest: Dictionary) -> void:
	var player_name := _get_player_name()
	var group_name := AdventureGroupManager.get_player_group(player_name)
	if group_name.is_empty():
		return

	var members := AdventureGroupManager.get_group_members(group_name)
	var member_count := members.size()
	if member_count <= 0:
		return

	# Parse gold reward from reward_key (e.g. "10 Gold, 50 XP")
	var gold_total := _parse_gold_reward(quest)
	@warning_ignore("integer_division")
	var gold_share : int = maxi(1, gold_total / member_count) if gold_total > 0 else 0

	var players_node := get_parent().get_parent()
	if players_node == null:
		return

	for child : Node in players_node.get_children():
		var skills : Node = child.get_node_or_null("Skills")
		if skills == null:
			continue
		var name : String = skills.player_uuid
		if name == player_name or name not in members:
			continue
		var quests : Node = child.get_node_or_null("Quests")
		if quests == null:
			continue

		# Complete on server copy
		var id := _quest_id(quest)
		if quests.is_quest_active(id):
			for i : int in quests._active_quests.size():
				if quests._quest_id(quests._active_quests[i]) == id:
					var q := quests._active_quests[i]
					quests._active_quests.remove_at(i)
					quests._completed_quests.append(q)
					quests.quests_changed.emit()
					break

		# Add gold on server copy
		if gold_share > 0:
			var inv : Node = child.get_node_or_null("Inventory")
			if inv != null:
				inv.add_gold(gold_share)

		# Notify client
		var peer_id := int(str(child.name))
		if peer_id != 1:
			quests._rpc_receive_group_reward.rpc_id(peer_id, quest, gold_share)
		else:
			# Host player: add gold and emit signal directly
			var inv : Node = child.get_node_or_null("Inventory")
			if inv != null and gold_share > 0:
				inv.add_gold(gold_share)
			quests.group_reward_received.emit(quest, gold_share)


## Try to parse a gold amount from the reward translation key.
func _parse_gold_reward(quest: Dictionary) -> int:
	var reward_text := tr(quest.get("reward_key", "") as String)
	# Look for patterns like "10 Gold" or "10G"
	var regex := RegEx.new()
	regex.compile("(\\d+)\\s*[Gg]old")
	var result := regex.search(reward_text)
	if result != null:
		return int(result.get_string(1))
	return 0


# ── Save / Load ───────────────────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	return {
		"active":    _active_quests.duplicate(true),
		"completed": _completed_quests.duplicate(true),
	}


func apply_save_data(data: Dictionary) -> void:
	_active_quests.clear()
	_completed_quests.clear()
	if data.has("active") and data["active"] is Array:
		for q: Variant in (data["active"] as Array):
			if q is Dictionary:
				_active_quests.append(q as Dictionary)
	if data.has("completed") and data["completed"] is Array:
		for q: Variant in (data["completed"] as Array):
			if q is Dictionary:
				_completed_quests.append(q as Dictionary)
	quests_changed.emit()


# ── Internal ──────────────────────────────────────────────────────────────────

func _quest_id(quest: Dictionary) -> String:
	return quest.get("title_key", "") as String


func _get_player_name() -> String:
	var skills : Node = get_parent().get_node_or_null("Skills")
	if skills != null:
		return skills.player_uuid
	return ""
