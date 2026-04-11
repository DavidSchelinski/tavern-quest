extends Node

## Server-authoritative adventure group manager.
## Groups persist in memory during a session. Handles formation, applications,
## shared quests, and reward splitting.

signal groups_changed
signal applications_changed

## Group data: group_name → { "leader": String, "members": Array[String],
##   "applications": Array[String], "shared_quest": String or "" }
var _groups : Dictionary = {}

## Player → group_name mapping for quick lookup
var _player_group : Dictionary = {}


# ── Public queries ───────────────────────────────────────────────────────────

func get_all_groups() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for group_name: String in _groups:
		var g: Dictionary = _groups[group_name]
		result.append({
			"name": group_name,
			"leader": g["leader"],
			"members": (g["members"] as Array).duplicate(),
			"member_count": (g["members"] as Array).size(),
			"has_applications": not (g["applications"] as Array).is_empty(),
			"shared_quest": g.get("shared_quest", ""),
		})
	return result


func get_player_group(player_name: String) -> String:
	return _player_group.get(player_name, "") as String


func get_group_members(group_name: String) -> Array:
	if not _groups.has(group_name):
		return []
	return (_groups[group_name]["members"] as Array).duplicate()


func get_group_applications(group_name: String) -> Array:
	if not _groups.has(group_name):
		return []
	return (_groups[group_name]["applications"] as Array).duplicate()


func is_leader(player_name: String) -> bool:
	var gn := get_player_group(player_name)
	if gn.is_empty():
		return false
	return (_groups[gn]["leader"] as String) == player_name


func get_shared_quest(group_name: String) -> String:
	if not _groups.has(group_name):
		return ""
	return _groups[group_name].get("shared_quest", "") as String


# ── Server-side mutations ────────────────────────────────────────────────────

func create_group(group_name: String, leader_name: String) -> bool:
	if _groups.has(group_name):
		return false
	if _player_group.has(leader_name):
		return false
	_groups[group_name] = {
		"leader": leader_name,
		"members": [leader_name],
		"applications": [],
		"shared_quest": "",
	}
	_player_group[leader_name] = group_name
	groups_changed.emit()
	return true


func apply_to_group(group_name: String, player_name: String) -> bool:
	if not _groups.has(group_name):
		return false
	if _player_group.has(player_name):
		return false
	var apps: Array = _groups[group_name]["applications"]
	if player_name in apps:
		return false
	apps.append(player_name)
	applications_changed.emit()
	return true


func accept_application(group_name: String, player_name: String) -> bool:
	if not _groups.has(group_name):
		return false
	var g: Dictionary = _groups[group_name]
	var apps: Array = g["applications"]
	if player_name not in apps:
		return false
	apps.erase(player_name)
	(g["members"] as Array).append(player_name)
	_player_group[player_name] = group_name
	groups_changed.emit()
	applications_changed.emit()
	return true


func reject_application(group_name: String, player_name: String) -> void:
	if not _groups.has(group_name):
		return
	(_groups[group_name]["applications"] as Array).erase(player_name)
	applications_changed.emit()


func leave_group(player_name: String) -> void:
	var gn := get_player_group(player_name)
	if gn.is_empty():
		return
	var g: Dictionary = _groups[gn]
	(g["members"] as Array).erase(player_name)
	_player_group.erase(player_name)

	if (g["members"] as Array).is_empty():
		# Dissolve empty group
		_groups.erase(gn)
	elif (g["leader"] as String) == player_name:
		# Transfer leadership
		g["leader"] = (g["members"] as Array)[0]
	groups_changed.emit()


func set_shared_quest(group_name: String, quest_key: String) -> void:
	if not _groups.has(group_name):
		return
	_groups[group_name]["shared_quest"] = quest_key
	groups_changed.emit()


func clear_shared_quest(group_name: String) -> void:
	set_shared_quest(group_name, "")


## Splits reward XP/gold among group members. Returns per-player share.
func calculate_split(total: int, group_name: String) -> int:
	if not _groups.has(group_name):
		return total
	var member_count: int = (_groups[group_name]["members"] as Array).size()
	if member_count <= 0:
		return total
	@warning_ignore("integer_division")
	return maxi(1, total / member_count)


# ── RPC: Client requests ─────────────────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func rpc_create_group(group_name: String, leader_name: String) -> void:
	if not multiplayer.is_server():
		return
	create_group(group_name, leader_name)
	_broadcast_groups()


@rpc("any_peer", "call_remote", "reliable")
func rpc_apply_to_group(group_name: String, player_name: String) -> void:
	if not multiplayer.is_server():
		return
	apply_to_group(group_name, player_name)
	_broadcast_groups()


@rpc("any_peer", "call_remote", "reliable")
func rpc_accept_application(group_name: String, player_name: String) -> void:
	if not multiplayer.is_server():
		return
	accept_application(group_name, player_name)
	_broadcast_groups()


@rpc("any_peer", "call_remote", "reliable")
func rpc_leave_group(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	leave_group(player_name)
	_broadcast_groups()


@rpc("any_peer", "call_remote", "reliable")
func rpc_set_shared_quest(group_name: String, quest_key: String) -> void:
	if not multiplayer.is_server():
		return
	set_shared_quest(group_name, quest_key)
	_broadcast_groups()


## Server → all clients: sync the full group state
func _broadcast_groups() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	var data := _serialize_groups()
	_rpc_sync_groups.rpc(data)


@rpc("authority", "call_local", "reliable")
func _rpc_sync_groups(data: Dictionary) -> void:
	_deserialize_groups(data)
	groups_changed.emit()
	applications_changed.emit()


func _serialize_groups() -> Dictionary:
	return {
		"groups": _groups.duplicate(true),
		"player_group": _player_group.duplicate(),
	}


func _deserialize_groups(data: Dictionary) -> void:
	if data.has("groups"):
		_groups = (data["groups"] as Dictionary).duplicate(true)
	if data.has("player_group"):
		_player_group = (data["player_group"] as Dictionary).duplicate()
