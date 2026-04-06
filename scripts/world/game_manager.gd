extends Node

# ── Config ────────────────────────────────────────────────────────────────────
const PLAYER_SCENE   := "res://scenes/player/player.tscn"
const SPAWN_POSITION := Vector3(0.0, 1.0, 22.0)

# ── Refs ──────────────────────────────────────────────────────────────────────
@onready var _players : Node3D = $Players

var _spawner : MultiplayerSpawner


func _ready() -> void:
	_setup_spawner()

	if not multiplayer.has_multiplayer_peer():
		# ── Single-player ──────────────────────────────────────────────────────
		_spawn_player(1)
		return

	# ── Multiplayer ────────────────────────────────────────────────────────────
	NetworkManager.player_disconnected.connect(_on_player_disconnected)

	if multiplayer.is_server():
		# Host spawns themselves immediately.
		_spawn_player(1)
	else:
		# Client signals readiness so the server spawns their character.
		rpc_id(1, &"_rpc_request_spawn")


# ── Spawner setup ─────────────────────────────────────────────────────────────

func _setup_spawner() -> void:
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "Spawner"
	_spawner.add_spawnable_scene(PLAYER_SCENE)
	add_child(_spawner)
	# Path relative to spawner → up to GameManager → Players sibling
	_spawner.spawn_path = _spawner.get_path_to(_players)
	_spawner.spawned.connect(_on_player_spawned)


# ── Spawn / despawn ───────────────────────────────────────────────────────────

func _spawn_player(id: int) -> void:
	if _players.has_node(str(id)):
		return
	var player: Node = load(PLAYER_SCENE).instantiate()
	player.name = str(id)
	player.position = SPAWN_POSITION
	# Authority must be set before add_child so _ready() sees the correct value
	# (deferred in player.gd to stay safe).
	player.set_multiplayer_authority(id)
	_players.add_child(player, true)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_spawn() -> void:
	# Only the server should act on this.
	if not multiplayer.is_server():
		return
	_spawn_player(multiplayer.get_remote_sender_id())


func _on_player_spawned(node: Node) -> void:
	# Called on ALL peers after the spawner replicates the node.
	# Ensures authority is set correctly on clients too.
	node.set_multiplayer_authority(int(node.name))


func _on_player_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var player := _players.get_node_or_null(str(id))
	if player:
		player.queue_free()
