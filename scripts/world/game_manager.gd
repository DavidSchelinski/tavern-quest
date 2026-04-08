extends Node

# ── Config ────────────────────────────────────────────────────────────────────
const PLAYER_SCENE   := "res://scenes/player/player.tscn"
const SPAWN_POSITION := Vector3(0.0, 1.0, 22.0)
const SAFE_CHECK_RADIUS := 0.45
const SAFE_CHECK_HEIGHT := 1.7

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
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

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
	var scene := load(PLAYER_SCENE) as PackedScene
	if scene == null:
		push_error("GameManager: could not load player scene '%s'" % PLAYER_SCENE)
		return
	var player : CharacterBody3D = scene.instantiate()
	player.name     = str(id)
	player.position = SPAWN_POSITION
	# Authority must be set before add_child so _ready() sees the correct value.
	player.set_multiplayer_authority(id)
	_players.add_child(player, true)
	_ensure_safe_position.call_deferred(player)


func _ensure_safe_position(player: CharacterBody3D) -> void:
	var space : PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	if space == null:
		return

	var shape := CapsuleShape3D.new()
	shape.radius = SAFE_CHECK_RADIUS
	shape.height = SAFE_CHECK_HEIGHT

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape          = shape
	params.exclude        = [player.get_rid()]
	params.collision_mask = 3   # world (1) + players (2)

	var origin : Vector3 = player.position
	params.transform = Transform3D(Basis.IDENTITY, origin + Vector3(0.0, SAFE_CHECK_HEIGHT * 0.5, 0.0))

	if space.intersect_shape(params, 1).is_empty():
		return

	# Spiral outward to find a clear spot.
	for radius : float in [1.5, 3.0, 4.5, 6.0, 9.0]:
		for step : int in range(8):
			var angle    : float   = step * TAU / 8.0
			var test_pos : Vector3 = origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			params.transform = Transform3D(Basis.IDENTITY, test_pos + Vector3(0.0, SAFE_CHECK_HEIGHT * 0.5, 0.0))
			if space.intersect_shape(params, 1).is_empty():
				player.position = test_pos
				return

	player.position = origin + Vector3(2.0, 0.0, 0.0)


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


func _on_server_disconnected() -> void:
	NetworkManager.close()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
