extends Node

signal room_created(code: String)   # code = host IP on the LAN
signal room_joined
signal peer_joined
signal peer_left
signal failed(msg: String)
signal message(data: Dictionary)
signal host_found(ip: String)

const PORT := 7777
const DISCOVERY_PORT := 7778
const MAGIC := "SPINDRAW1"

var is_host := false
var active := false
var room := ""
var peer: ENetMultiplayerPeer
var _bcast: PacketPeerUDP
var _listen: PacketPeerUDP
var _bcast_timer := 0.0
var my := {}    # my pick: {"top", "weapon", "ult"}
var opp := {}   # opponent's pick

func stop_broadcast() -> void:
	_bcast = null

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ---------- Host / join ----------

func create_room() -> void:
	leave()
	is_host = true
	peer = ENetMultiplayerPeer.new()
	if peer.create_server(PORT, 1) != OK:
		peer = null
		failed.emit("Could not host (port busy?)")
		return
	multiplayer.multiplayer_peer = peer
	active = true
	room = local_ip()
	_bcast = PacketPeerUDP.new()
	_bcast.set_broadcast_enabled(true)
	_bcast.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	room_created.emit(room)

func join_room(ip: String) -> void:
	leave()
	is_host = false
	peer = ENetMultiplayerPeer.new()
	if peer.create_client(ip.strip_edges(), PORT) != OK:
		peer = null
		failed.emit("Could not connect to " + ip)
		return
	multiplayer.multiplayer_peer = peer
	active = true

func leave() -> void:
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	peer = null
	_bcast = null
	active = false
	room = ""

# ---------- Discovery (guest side) ----------

func start_discovery() -> void:
	stop_discovery()
	_listen = PacketPeerUDP.new()
	if _listen.bind(DISCOVERY_PORT) != OK:
		_listen = null

func stop_discovery() -> void:
	if _listen:
		_listen.close()
	_listen = null

func local_ip() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10."):
			return a
		if a.begins_with("172."):
			var n := int(a.split(".")[1])
			if n >= 16 and n <= 31:
				return a
	return "127.0.0.1"

func _process(delta: float) -> void:
	if _bcast:
		_bcast_timer -= delta
		if _bcast_timer <= 0.0:
			_bcast_timer = 1.0
			_bcast.put_packet(MAGIC.to_utf8_buffer())
	if _listen:
		while _listen.get_available_packet_count() > 0:
			var txt := _listen.get_packet().get_string_from_utf8()
			var ip := _listen.get_packet_ip()
			if txt == MAGIC:
				host_found.emit(ip)

# ---------- Messages ----------

## fast = true for frequent, droppable data (used for snapshots in Stage 2).
func send(data: Dictionary, fast := false) -> void:
	if not active or multiplayer.multiplayer_peer == null:
		return
	if multiplayer.get_peers().is_empty():
		return
	if fast:
		_recv_fast.rpc(JSON.stringify(data))
	else:
		_recv.rpc(JSON.stringify(data))

@rpc("any_peer", "call_remote", "reliable")
func _recv(json: String) -> void:
	_deliver(json)

@rpc("any_peer", "call_remote", "unreliable")
func _recv_fast(json: String) -> void:
	_deliver(json)

func _deliver(json: String) -> void:
	var d = JSON.parse_string(json)
	if typeof(d) == TYPE_DICTIONARY:
		message.emit(d)

# ---------- Connection events ----------

func _on_peer_connected(_id: int) -> void:
	if is_host:
		peer_joined.emit()

func _on_connected_to_server() -> void:
	room_joined.emit()

func _on_peer_disconnected(_id: int) -> void:
	peer_left.emit()

func _on_server_disconnected() -> void:
	leave()
	peer_left.emit()

func _on_connection_failed() -> void:
	leave()
	failed.emit("Connection failed")
