extends Node

# ── Config ────────────────────────────────────────────────────────────────────
const PLAYER_SCENE      := "res://scenes/player/player.tscn"
const SPAWN_POSITION    := Vector3(0.0, 1.0, 22.0)
const SAFE_CHECK_RADIUS := 0.45
const SAFE_CHECK_HEIGHT := 1.7
const AUTO_SAVE_INTERVAL := 60.0

# ── Refs ──────────────────────────────────────────────────────────────────────
@onready var _players : Node3D = $Players

var _spawner : MultiplayerSpawner

## Maps peer_id → { "name": String, "code": String } for connected players.
var _peer_identities : Dictionary = {}

var _auto_save_timer : Timer


func _ready() -> void:
	# Weltordner sicherstellen (current_world_name wurde vom Hauptmenü gesetzt).
	SaveManager.set_world(SaveManager.current_world_name)

	# Welt-Zustand laden
	var ws := SaveManager.load_world_state()
	if not ws.is_empty():
		WorldState.apply_save_data(ws)

	_setup_spawner()
	_setup_auto_save()

	if not multiplayer.has_multiplayer_peer():
		# ── Single-player ──────────────────────────────────────────────────────
		_spawn_player(1, PlayerProfile.current_player_name)
		return

	# ── Multiplayer ────────────────────────────────────────────────────────────
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

	if multiplayer.is_server():
		var code := PlayerProfile.get_verification_code()
		_peer_identities[1] = { "name": PlayerProfile.current_player_name, "code": code }
		_spawn_player(1, PlayerProfile.current_player_name)
	else:
		rpc_id(1, &"_rpc_request_spawn", PlayerProfile.current_player_name, PlayerProfile.get_verification_code())


# ── Spawner-Setup ─────────────────────────────────────────────────────────────

func _setup_spawner() -> void:
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "Spawner"
	_spawner.add_spawnable_scene(PLAYER_SCENE)
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(_players)
	_spawner.spawned.connect(_on_player_spawned)


# ── Spawn / Despawn ───────────────────────────────────────────────────────────

## Spawnt einen Spieler und lädt alle seine Daten VOR add_child.
## Das verhindert den Gast-Reset-Bug: der MultiplayerSpawner repliziert
## den Node erst, wenn Skills, Inventar und Position bereits korrekt sind.
func _spawn_player(peer_id: int, player_name: String) -> void:
	if _players.has_node(str(peer_id)):
		return
	var scene := load(PLAYER_SCENE) as PackedScene
	if scene == null:
		push_error("GameManager: Spieler-Scene nicht gefunden – '%s'" % PLAYER_SCENE)
		return

	var player: CharacterBody3D = scene.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)

	# ── Save-Daten vollständig laden ──────────────────────────────────────────
	var saved: Dictionary = SaveManager.get_player_data(player_name)
	_apply_all_save_data(player, player_name, saved)

	_log_spawn(peer_id, player_name, player, saved)

	# ── Erst jetzt zum SceneTree → MultiplayerSpawner wird aktiv ──────────────
	_players.add_child(player, true)

	# Client-Sync: Skills + Inventar nach Spawn-Replikation senden.
	if multiplayer.has_multiplayer_peer() and peer_id != 1:
		_sync_all_to_client.call_deferred(peer_id, player)

	_ensure_safe_position.call_deferred(player)


## Wendet alle gespeicherten Daten auf einen frisch instanziierten Player-Node an.
func _apply_all_save_data(player: Node, player_name: String, saved: Dictionary) -> void:
	# Skills + Hotbar + Position
	var skills: Node = player.get_node_or_null("Skills")
	if skills != null:
		skills.set("player_uuid", player_name)
		skills.call("apply_save_data", saved)
		player.set("position", skills.get("last_position"))

	# Inventar
	var inventory: Node = player.get_node_or_null("Inventory")
	if inventory != null and saved.has("inventory") and saved["inventory"] is Array:
		inventory.call("apply_save_data", saved["inventory"] as Array)

	# Equipment
	if inventory != null and saved.has("equipment") and saved["equipment"] is Dictionary:
		inventory.call("apply_equipment_save_data", saved["equipment"] as Dictionary)

	# Stats
	var stats: Node = player.get_node_or_null("Stats")
	if stats != null and saved.has("stats_data") and saved["stats_data"] is Dictionary:
		stats.call("apply_save_data", saved["stats_data"] as Dictionary)

	# Quests
	var quests: Node = player.get_node_or_null("Quests")
	if quests != null and saved.has("quests_data") and saved["quests_data"] is Dictionary:
		quests.call("apply_save_data", saved["quests_data"] as Dictionary)

	# Gildenrang
	var guild: Node = player.get_node_or_null("GuildRank")
	if guild != null and saved.has("guild_data") and saved["guild_data"] is Dictionary:
		guild.call("apply_save_data", saved["guild_data"] as Dictionary)

	# HP + Stamina
	var hp_saved: float = float(saved.get("hp", -1.0))
	if stats != null:
		var max_hp: int = int(stats.call("get_max_hp"))
		var hp_val: float = float(max_hp) if hp_saved < 0 else minf(hp_saved, float(max_hp))
		player.set("health", hp_val)
	var max_stamina: float = 100.0
	if stats != null and stats.has_method("get_max_stamina"):
		max_stamina = float(stats.call("get_max_stamina"))
	var stamina_saved: float = float(saved.get("stamina", max_stamina))
	player.set("_stamina", clampf(stamina_saved, 0.0, max_stamina))


## Sammelt alle zu speichernden Daten eines Spielers.
func _collect_save_data(player: Node) -> Dictionary:
	var data := {}

	var skills: Node = player.get_node_or_null("Skills")
	if skills != null:
		skills.last_position = player.position
		data.merge(skills.get_save_data())

	var inventory: Node = player.get_node_or_null("Inventory")
	if inventory != null:
		data["inventory"] = inventory.get_save_data()
		data["equipment"] = inventory.get_equipment_save_data()

	var stats: Node = player.get_node_or_null("Stats")
	if stats != null:
		data["stats_data"] = stats.get_save_data()

	var quests: Node = player.get_node_or_null("Quests")
	if quests != null:
		data["quests_data"] = quests.get_save_data()

	var guild: Node = player.get_node_or_null("GuildRank")
	if guild != null:
		data["guild_data"] = guild.get_save_data()

	# HP + Stamina direkt aus dem Player-Node
	if player.get("health") != null:
		data["hp"] = float(player.health)
	if player.get("_stamina") != null:
		data["stamina"] = float(player._stamina)

	return data


## Sendet alle Daten (Skills + Inventar) nach der Spawn-Replikation an den Client.
func _sync_all_to_client(peer_id: int, player: Node) -> void:
	if not is_instance_valid(player):
		return

	var skills: Node = player.get_node_or_null("Skills")
	if skills != null:
		skills.sync_skill_data.rpc_id(peer_id, skills.skill_points, skills._unlocked_skills.duplicate())
		skills.force_ui_refresh.rpc_id(peer_id)

	var inventory: Node = player.get_node_or_null("Inventory")
	if inventory != null:
		inventory.sync_inventory.rpc_id(peer_id, inventory.get_save_data())


func _ensure_safe_position(player: CharacterBody3D) -> void:
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	if space == null:
		return

	var shape := CapsuleShape3D.new()
	shape.radius = SAFE_CHECK_RADIUS
	shape.height = SAFE_CHECK_HEIGHT

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape          = shape
	params.exclude        = [player.get_rid()]
	params.collision_mask = 3

	var origin := player.position
	params.transform = Transform3D(Basis.IDENTITY, origin + Vector3(0.0, SAFE_CHECK_HEIGHT * 0.5, 0.0))
	if space.intersect_shape(params, 1).is_empty():
		return

	for radius: float in [1.5, 3.0, 4.5, 6.0, 9.0]:
		for step: int in range(8):
			var angle     := step * TAU / 8.0
			var test_pos  := origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			params.transform = Transform3D(Basis.IDENTITY, test_pos + Vector3(0.0, SAFE_CHECK_HEIGHT * 0.5, 0.0))
			if space.intersect_shape(params, 1).is_empty():
				player.position = test_pos
				return

	player.position = origin + Vector3(2.0, 0.0, 0.0)


# ── RPC ───────────────────────────────────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_spawn(player_name: String, verification_code: String = "") -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()

	# Check for name collision with a different verification code (impersonation)
	for existing_peer: int in _peer_identities:
		var identity: Dictionary = _peer_identities[existing_peer]
		if identity["name"] == player_name and identity["code"] != verification_code:
			push_warning("GameManager: Peer %d abgelehnt – Name '%s' bereits mit anderem Code vergeben." % [peer_id, player_name])
			return

	# Reconnect check: if this name was seen before, verify the code matches
	_peer_identities[peer_id] = { "name": player_name, "code": verification_code }
	_spawn_player(peer_id, player_name)


func _on_player_spawned(node: Node) -> void:
	node.set_multiplayer_authority(int(node.name))


# ── Disconnect / Reconnect ────────────────────────────────────────────────────

func _on_player_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var player := _players.get_node_or_null(str(peer_id))
	if player == null:
		return

	var skills: Node = player.get_node_or_null("Skills")
	var player_name: String = skills.player_uuid if skills != null else ""

	if not player_name.is_empty():
		var data := _collect_save_data(player)
		SaveManager.update_player_data(player_name, data)
		print("GameManager: '%s' (peer %d) gespeichert." % [player_name, peer_id])

	player.queue_free()
	_peer_identities.erase(peer_id)


func _on_server_disconnected() -> void:
	NetworkManager.close()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ── Debug-Hilfe ───────────────────────────────────────────────────────────────

func _log_spawn(peer_id: int, player_name: String, player: Node, saved: Dictionary) -> void:
	var skills: Node    = player.get_node_or_null("Skills")
	var inventory: Node = player.get_node_or_null("Inventory")
	var sp    : int     = int(skills.skill_points) if skills != null else 0
	var items : int     = _count_items(inventory)
	var pos   : Vector3 = player.position
	print("GameManager: Spieler %d ('%s') gespawnt | %d SP | %d Items | Pos %s | Neu=%s" % [
		peer_id, player_name, sp, items, pos,
		str(not SaveManager.player_file_exists(player_name)),
	])


func _count_items(inventory: Node) -> int:
	if inventory == null:
		return 0
	var count: int = 0
	for slot: Variant in inventory.get("slots"):
		if slot != null:
			count += 1
	return count


# ── Auto-Save ────────────────────────────────────────────────────────────────

func _setup_auto_save() -> void:
	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	_auto_save_timer.autostart = true
	_auto_save_timer.timeout.connect(_on_auto_save)
	add_child(_auto_save_timer)


func _on_auto_save() -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		save_all()


## Speichert alle Spieler und den Welt-Zustand.
func save_all() -> void:
	for child: Node in _players.get_children():
		var skills: Node = child.get_node_or_null("Skills")
		var player_name: String = skills.player_uuid if skills != null else ""
		if not player_name.is_empty():
			var data := _collect_save_data(child)
			SaveManager.update_player_data(player_name, data)

	SaveManager.save_world_state(WorldState.get_save_data())
	print("GameManager: Auto-Save abgeschlossen.")
