extends Node

# ── Config ────────────────────────────────────────────────────────────────────
const PLAYER_SCENE        := "res://scenes/player/player.tscn"
const SPAWN_POSITION      := Vector3(0.0, 1.0, 22.0)
const SAFE_CHECK_RADIUS   := 0.45
const SAFE_CHECK_HEIGHT   := 1.7
const IDENTITY_PATH       := "user://identity.cfg"
## Separate Identitätsdatei für Debug-Builds: kein PID-Suffix, bleibt über Neustarts stabil.
## Für lokale 2-Spieler-Tests: zweite Datei manuell anlegen oder UUID darin ändern.
const DEBUG_IDENTITY_PATH := "user://debug_identity.cfg"

# ── Refs ──────────────────────────────────────────────────────────────────────
@onready var _players : Node3D = $Players

var _spawner : MultiplayerSpawner


func _ready() -> void:
	# Sicherstellt, dass der Welten-Ordner existiert.
	# current_world_name wurde bereits vom Hauptmenü per SaveManager.set_world() gesetzt.
	# Beim direkten Szenen-Start im Editor läuft das hier mit dem Default-Wert "default".
	SaveManager.set_world(SaveManager.current_world_name)

	_setup_spawner()

	if not multiplayer.has_multiplayer_peer():
		# ── Single-player ──────────────────────────────────────────────────────
		# Leere UUID → SaveManager speichert nach player_solo.json.
		_spawn_player(1, "")
		return

	# ── Multiplayer ────────────────────────────────────────────────────────────
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

	if multiplayer.is_server():
		# Host spawnt sich selbst mit seiner persistenten UUID.
		_spawn_player(1, _get_or_create_uuid())
	else:
		# Client teilt dem Server seine UUID mit und fordert den Spawn an.
		rpc_id(1, &"_rpc_request_spawn", _get_or_create_uuid())


# ── UUID-Identität ────────────────────────────────────────────────────────────

## Liest die persistente Spieler-UUID.
##
## Debug/Editor: Liest aus debug_identity.cfg (kein PID-Suffix → bleibt über Neustarts
## stabil, Saves gehen nicht verloren). Standard-UUID beim ersten Start: "debug_player_1".
## Für lokale 2-Spieler-Tests: debug_identity.cfg manuell editieren oder eine zweite
## Datei unter einem anderen Profilnamen anlegen.
##
## Release: Liest aus identity.cfg, generiert einmalig aus OS.get_unique_id().
func _get_or_create_uuid() -> String:
	if OS.has_feature("editor") or OS.has_feature("debug"):
		var cfg := ConfigFile.new()
		cfg.load(DEBUG_IDENTITY_PATH)
		var uid: String = cfg.get_value("player", "uuid", "") as String
		if uid.is_empty():
			uid = "debug_player_1"
			cfg.set_value("player", "uuid", uid)
			cfg.save(DEBUG_IDENTITY_PATH)
			print("GameManager: Debug-UUID erstellt – '%s'  (änderbar in %s)" \
					% [uid, DEBUG_IDENTITY_PATH])
		else:
			print("GameManager: Debug-UUID geladen – '%s'" % uid)
		return uid

	# Release-Build: persistente UUID aus identity.cfg
	var cfg := ConfigFile.new()
	cfg.load(IDENTITY_PATH)
	var uid: String = cfg.get_value("player", "uuid", "") as String
	if uid.is_empty():
		var base: String = OS.get_unique_id()
		if base.is_empty():
			base = str(randi())
		uid = "%s_%d" % [base, Time.get_unix_time_from_system()]
		cfg.set_value("player", "uuid", uid)
		cfg.save(IDENTITY_PATH)
		print("GameManager: Neue UUID generiert – '%s'" % uid)
	return uid


# ── Spawner setup ─────────────────────────────────────────────────────────────

func _setup_spawner() -> void:
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "Spawner"
	_spawner.add_spawnable_scene(PLAYER_SCENE)
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(_players)
	_spawner.spawned.connect(_on_player_spawned)


# ── Spawn / despawn ───────────────────────────────────────────────────────────

## Spawnt einen Spieler. Setzt alle Save-Daten VOR add_child, damit der
## MultiplayerSpawner den Node erst repliziert, wenn er vollständig initialisiert ist.
## Das verhindert den Gast-Reset-Bug (Client bekommt nie einen "leeren" Node).
func _spawn_player(id: int, uuid: String) -> void:
	if _players.has_node(str(id)):
		return
	var scene := load(PLAYER_SCENE) as PackedScene
	if scene == null:
		push_error("GameManager: Spieler-Scene nicht gefunden – '%s'" % PLAYER_SCENE)
		return

	var player: CharacterBody3D = scene.instantiate()
	player.name = str(id)
	# Authority muss vor add_child gesetzt werden, damit _ready() den richtigen Wert sieht.
	player.set_multiplayer_authority(id)

	# ── Save-Daten VOR add_child anwenden ─────────────────────────────────────
	# Reihenfolge ist kritisch: Erst alle Daten setzen, DANN zum SceneTree hinzufügen.
	# So repliziert der MultiplayerSpawner den Node erst, wenn UUID, Position und
	# Skills bereits gesetzt sind – der Client bekommt nie einen Default-State.
	var skills: Node = player.get_node_or_null("Skills")
	if skills != null:
		skills.player_uuid = uuid
		var saved: Dictionary = SaveManager.get_player_data(uuid)
		skills.apply_save_data(saved)
		player.position = skills.last_position
		print("GameManager: Spieler %d ('%s') initialisiert – %d Skillpunkte, Pos %s." \
				% [id, uuid if not uuid.is_empty() else "solo", skills.skill_points, player.position])
	else:
		player.position = SPAWN_POSITION

	# ── Jetzt erst zum SceneTree → MultiplayerSpawner wird aktiv ──────────────
	_players.add_child(player, true)

	# Für echte Clients (nicht Host): Skill-Sync senden.
	# call_deferred gibt dem Spawner einen Frame Zeit, den Node auf dem Client
	# zu erstellen, bevor die RPC-Daten ankommen.
	if multiplayer.has_multiplayer_peer() and id != 1 and skills != null:
		_sync_skills_to_client.call_deferred(id, player)

	_ensure_safe_position.call_deferred(player)


## Sendet die geladenen Skill-Daten an den Client, nachdem der Spawner
## den Player-Node repliziert hat (deferred, im nächsten Frame).
## Reihenfolge: sync_skill_data setzt die Daten, force_ui_refresh bestätigt
## danach explizit, dass alle Daten angekommen sind → Client-UI refresht sicher.
func _sync_skills_to_client(peer_id: int, player: Node) -> void:
	if not is_instance_valid(player):
		return
	var skills: Node = player.get_node_or_null("Skills")
	if skills == null:
		return
	# 1. Daten senden
	skills.sync_skill_data.rpc_id(peer_id, skills.skill_points, skills._unlocked_skills.duplicate())
	# 2. UI-Refresh-Signal senden – garantiert, dass der Client seinen Zustand vollständig
	#    initialisiert, auch wenn sync_skill_data ihn nicht getriggert hat.
	skills.force_ui_refresh.rpc_id(peer_id)


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
	params.collision_mask = 3   # world (1) + players (2)

	var origin: Vector3 = player.position
	params.transform = Transform3D(Basis.IDENTITY, origin + Vector3(0.0, SAFE_CHECK_HEIGHT * 0.5, 0.0))

	if space.intersect_shape(params, 1).is_empty():
		return

	# Spiralförmig nach außen suchen.
	for radius: float in [1.5, 3.0, 4.5, 6.0, 9.0]:
		for step: int in range(8):
			var angle: float    = step * TAU / 8.0
			var test_pos: Vector3 = origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			params.transform = Transform3D(Basis.IDENTITY, test_pos + Vector3(0.0, SAFE_CHECK_HEIGHT * 0.5, 0.0))
			if space.intersect_shape(params, 1).is_empty():
				player.position = test_pos
				return

	player.position = origin + Vector3(2.0, 0.0, 0.0)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_spawn(uuid: String) -> void:
	if not multiplayer.is_server():
		return
	_spawn_player(multiplayer.get_remote_sender_id(), uuid)


func _on_player_spawned(node: Node) -> void:
	# Wird auf ALLEN Peers aufgerufen, nachdem der Spawner den Node repliziert hat.
	node.set_multiplayer_authority(int(node.name))


func _on_player_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var player := _players.get_node_or_null(str(id))
	if player == null:
		return

	# Position vor dem Entfernen speichern.
	var skills: Node = player.get_node_or_null("Skills")
	if skills != null and not (skills.player_uuid as String).is_empty():
		skills.last_position = player.position
		SaveManager.update_player_data(skills.player_uuid, skills.get_save_data())
		print("GameManager: Spieler %d ('%s') Daten gespeichert." % [id, skills.player_uuid])

	player.queue_free()


func _on_server_disconnected() -> void:
	NetworkManager.close()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
