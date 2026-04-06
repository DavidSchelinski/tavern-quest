extends Node

# ── Signals ───────────────────────────────────────────────────────────────────
signal player_connected(id: int)
signal player_disconnected(id: int)
signal connection_failed()
signal server_disconnected()

# ── Constants ─────────────────────────────────────────────────────────────────
const DEFAULT_PORT := 7777
const MAX_PLAYERS  := 16

# ── State ─────────────────────────────────────────────────────────────────────
var is_hosting : bool = false


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


## Cleanly close the connection.
func close() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_hosting = false


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
