extends Node

# ── Signals ───────────────────────────────────────────────────────────────────
signal player_connected(id: int)
signal player_disconnected(id: int)
signal connection_failed()
signal server_disconnected()
signal server_found(ip: String, info: Dictionary)

# ── Constants ─────────────────────────────────────────────────────────────────
const DEFAULT_PORT    := 7777
const MAX_PLAYERS     := 16
const DISCOVERY_PORT  := 7776
const BEACON_INTERVAL := 2.0

# ── State ─────────────────────────────────────────────────────────────────────
var is_hosting : bool = false

# ── Discovery ─────────────────────────────────────────────────────────────────
var _broadcast_peer  : PacketPeerUDP = null
var _broadcast_timer : Timer         = null
var _broadcast_port  : int           = DEFAULT_PORT
var _discovery_peer  : PacketPeerUDP = null


# ── Public API ────────────────────────────────────────────────────────────────

## Start a listen-server on the given port. Returns OK or an Error code.
func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: could not create server – %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	is_hosting = true
	start_broadcast(port)
	return OK


## Connect to an existing server. Returns OK or an Error code.
func join(ip: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_client(ip, port)
	if err != OK:
		push_error("NetworkManager: could not connect – %s" % error_string(err))
		connection_failed.emit()
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	return OK


## Cleanly close the connection and reset all state so a new session can start.
func close() -> void:
	stop_broadcast()
	# Disconnect all multiplayer signals to prevent double-connections on re-host/rejoin
	_safe_disconnect(multiplayer.peer_connected, _on_peer_connected)
	_safe_disconnect(multiplayer.peer_disconnected, _on_peer_disconnected)
	_safe_disconnect(multiplayer.connected_to_server, _on_connected_to_server)
	_safe_disconnect(multiplayer.connection_failed, _on_connection_failed)
	_safe_disconnect(multiplayer.server_disconnected, _on_server_disconnected)
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_hosting = false


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


## Returns the best local LAN IP address, or 127.0.0.1 as fallback.
func get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.168.") or addr.begins_with("10.") \
				or (addr.begins_with("172.") and _is_private_172(addr)):
			return addr
	return "127.0.0.1"


func _is_private_172(addr: String) -> bool:
	var parts := addr.split(".")
	if parts.size() < 2:
		return false
	var second := int(parts[1])
	return second >= 16 and second <= 31


# ── LAN broadcast (host side) ────────────────────────────────────────────────

func start_broadcast(game_port: int = DEFAULT_PORT) -> void:
	stop_broadcast()
	_broadcast_port = game_port
	_broadcast_peer = PacketPeerUDP.new()
	_broadcast_peer.set_broadcast_enabled(true)
	_broadcast_peer.set_dest_address("255.255.255.255", DISCOVERY_PORT)

	_broadcast_timer = Timer.new()
	_broadcast_timer.wait_time = BEACON_INTERVAL
	_broadcast_timer.timeout.connect(_send_beacon)
	add_child(_broadcast_timer)
	_broadcast_timer.start()
	_send_beacon()


func stop_broadcast() -> void:
	if _broadcast_timer:
		_broadcast_timer.stop()
		_broadcast_timer.queue_free()
		_broadcast_timer = null
	if _broadcast_peer:
		_broadcast_peer.close()
		_broadcast_peer = null


func _send_beacon() -> void:
	if _broadcast_peer == null:
		return
	var player_count := 0
	if multiplayer.multiplayer_peer:
		player_count = multiplayer.get_peers().size() + 1
	var host_name := OS.get_environment("COMPUTERNAME")
	if host_name.is_empty():
		host_name = OS.get_environment("HOSTNAME")
	if host_name.is_empty():
		host_name = "Tavern Server"
	var data := {
		"name": host_name,
		"port": _broadcast_port,
		"players": player_count,
		"max_players": MAX_PLAYERS,
	}
	_broadcast_peer.put_packet(JSON.stringify(data).to_utf8_buffer())


# ── LAN discovery (client side) ──────────────────────────────────────────────

func start_discovery() -> void:
	stop_discovery()
	_discovery_peer = PacketPeerUDP.new()
	var err := _discovery_peer.bind(DISCOVERY_PORT)
	if err != OK:
		push_warning("NetworkManager: could not bind discovery port %d" % DISCOVERY_PORT)
		_discovery_peer = null


func stop_discovery() -> void:
	if _discovery_peer:
		_discovery_peer.close()
		_discovery_peer = null


func _process(_delta: float) -> void:
	if _discovery_peer == null:
		return
	while _discovery_peer.get_available_packet_count() > 0:
		var packet := _discovery_peer.get_packet()
		var ip     := _discovery_peer.get_packet_ip()
		var json   := JSON.new()
		if json.parse(packet.get_string_from_utf8()) == OK and json.data is Dictionary:
			var info : Dictionary = json.data
			info["ip"] = ip
			server_found.emit(ip, info)


# ── Internal callbacks ────────────────────────────────────────────────────────

func _on_peer_connected(id: int) -> void:
	player_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	player_disconnected.emit(id)


func _on_connected_to_server() -> void:
	player_connected.emit(multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	connection_failed.emit()


func _on_server_disconnected() -> void:
	server_disconnected.emit()
