class_name Enemy
extends CharacterBody3D

# ─── Constants ────────────────────────────────────────────────────────────────
const MAX_HEALTH      : float = 30.0
const RESPAWN_TIME    : float = 8.0
const MOVE_SPEED      : float = 2.2   # patrol speed  m/s
const CHASE_SPEED     : float = 4.2   # chase speed   m/s
const GRAVITY         : float = 20.0
const ATTACK_DAMAGE   : float = 8.0
const ATTACK_COOLDOWN : float = 1.8   # seconds between hits
const ATTACK_RANGE    : float = 1.8   # metres – start/keep attacking
const LEASH_RANGE     : float = 20.0  # metres – give up chase
const PATROL_RADIUS   : float = 7.0   # metres – wander radius from home

@export var drop_item : ItemData = null

# ─── State machine ────────────────────────────────────────────────────────────
enum State { IDLE, PATROL, CHASE, ATTACK, DEAD }

# ─── Node refs ────────────────────────────────────────────────────────────────
@onready var _mesh        : MeshInstance3D    = $Mesh
@onready var _light       : OmniLight3D       = $OmniLight3D
@onready var _col         : CollisionShape3D  = $CollisionShape3D
@onready var _nav         : NavigationAgent3D = $NavigationAgent3D
@onready var _detect_area : Area3D            = $DetectArea

# ─── Runtime state ────────────────────────────────────────────────────────────
var health        : float  = MAX_HEALTH
var _state        : State  = State.IDLE
var _dead         : bool   = false
var _target       : Node3D = null
var _home_pos     : Vector3
var _patrol_pos   : Vector3
var _attack_timer : float  = 0.0
var _idle_timer   : float  = 1.5
var _hurt_area    : Area3D = null


func _ready() -> void:
	add_to_group("enemy")
	_home_pos   = global_position
	_patrol_pos = global_position
	_setup_hurt_area()
	_update_glow()
	_detect_area.body_entered.connect(_on_detect_entered)
	_detect_area.body_exited.connect(_on_detect_exited)


func _setup_hurt_area() -> void:
	_hurt_area                 = Area3D.new()
	_hurt_area.name            = "HurtArea"
	_hurt_area.collision_layer = 4
	_hurt_area.collision_mask  = 0
	_hurt_area.monitorable     = true
	_hurt_area.monitoring      = false
	var col   := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.0, 1.0)
	col.shape  = shape
	col.position = Vector3(0.0, 0.9, 0.0)
	_hurt_area.add_child(col)
	add_child(_hurt_area)


# ─── Physics loop ─────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	# Gravity always applies
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if _dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if _is_authority():
		match _state:
			State.IDLE:   _tick_idle(delta)
			State.PATROL: _tick_patrol(delta)
			State.CHASE:  _tick_chase(delta)
			State.ATTACK: _tick_attack(delta)

	move_and_slide()


# ── IDLE ──────────────────────────────────────────────────────────────────────

func _tick_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_pick_patrol_target()
		_state = State.PATROL


# ── PATROL ────────────────────────────────────────────────────────────────────

func _tick_patrol(_delta: float) -> void:
	var dist_to_target := global_position.distance_to(_patrol_pos)
	if _nav.is_navigation_finished() or dist_to_target < 0.8:
		velocity.x  = 0.0
		velocity.z  = 0.0
		_state      = State.IDLE
		_idle_timer = randf_range(1.5, 4.0)
		return

	var next := _nav.get_next_path_position()
	var dir  := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	# Fallback: NavigationAgent returns the agent's own position when no navmesh
	# exists yet – in that case navigate straight toward the patrol target.
	if dir.length_squared() < 0.04:
		dir = Vector3(_patrol_pos.x - global_position.x, 0.0, _patrol_pos.z - global_position.z)
	if dir.length_squared() > 0.001:
		dir        = dir.normalized()
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED
		_face_dir(dir, 0.10)


# ── CHASE ─────────────────────────────────────────────────────────────────────

func _tick_chase(_delta: float) -> void:
	if not is_instance_valid(_target):
		_lose_target()
		return

	var dist := global_position.distance_to(_target.global_position)

	if dist > LEASH_RANGE:
		_lose_target()
		return

	if dist <= ATTACK_RANGE:
		_state        = State.ATTACK
		_attack_timer = 0.5   # brief wind-up before first hit
		velocity.x    = 0.0
		velocity.z    = 0.0
		return

	_nav.set_target_position(_target.global_position)
	var next := _nav.get_next_path_position()
	var dir  := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	# Fallback: if navmesh not ready yet, go straight toward the player.
	if dir.length_squared() < 0.04:
		dir = Vector3(_target.global_position.x - global_position.x, 0.0, _target.global_position.z - global_position.z)
	if dir.length_squared() > 0.001:
		dir        = dir.normalized()
		velocity.x = dir.x * CHASE_SPEED
		velocity.z = dir.z * CHASE_SPEED
		_face_dir(dir, 0.18)


# ── ATTACK ────────────────────────────────────────────────────────────────────

func _tick_attack(delta: float) -> void:
	if not is_instance_valid(_target):
		_lose_target()
		return

	var dist := global_position.distance_to(_target.global_position)
	if dist > ATTACK_RANGE * 1.5:
		_state = State.CHASE
		return

	var dir := Vector3(
		_target.global_position.x - global_position.x,
		0.0,
		_target.global_position.z - global_position.z
	)
	if dir.length_squared() > 0.001:
		_face_dir(dir.normalized(), 0.25)

	velocity.x = 0.0
	velocity.z = 0.0

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = ATTACK_COOLDOWN
		_do_attack()


func _do_attack() -> void:
	if not is_instance_valid(_target):
		return
	if _target.has_method("take_damage"):
		if multiplayer.has_multiplayer_peer():
			_target.take_damage.rpc_id(1, ATTACK_DAMAGE)
		else:
			_target.take_damage(ATTACK_DAMAGE)
	_flash_attack()


# ─── Navigation helpers ───────────────────────────────────────────────────────

func _pick_patrol_target() -> void:
	var angle   := randf() * TAU
	var radius  := randf_range(2.0, PATROL_RADIUS)
	_patrol_pos  = _home_pos + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	_nav.set_target_position(_patrol_pos)


func _lose_target() -> void:
	_target = null
	_pick_patrol_target()
	_state  = State.PATROL


func _face_dir(dir: Vector3, weight: float) -> void:
	if dir.length_squared() < 0.001:
		return
	basis = basis.slerp(Basis.looking_at(dir, Vector3.UP), weight)


# ─── Detection ────────────────────────────────────────────────────────────────

func _on_detect_entered(body: Node3D) -> void:
	if _dead or not _is_authority() or _target != null:
		return
	if body.is_in_group("player"):
		_target = body
		if _state == State.IDLE or _state == State.PATROL:
			_state = State.CHASE


func _on_detect_exited(_body: Node3D) -> void:
	pass   # leash range handles dropping the target


# ─── Damage entry point ───────────────────────────────────────────────────────
# Single-player  → called directly:         enemy.take_damage(dmg)
# Multiplayer    → called via RPC on server: enemy.take_damage.rpc_id(1, dmg)

@rpc("any_peer", "call_remote", "reliable")
func take_damage(amount: float) -> void:
	if not _is_authority():
		return
	_apply_damage(amount)


func _apply_damage(amount: float) -> void:
	if _dead:
		return
	health = maxf(0.0, health - amount)

	# Aggro on hit even if player was not inside detect area
	if (_state == State.IDLE or _state == State.PATROL) and _target == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_target = players[0]
			_state  = State.CHASE

	if multiplayer.has_multiplayer_peer():
		_net_hit.rpc(health, amount)
	else:
		_show_hit(health, amount)

	if health <= 0.0:
		if multiplayer.has_multiplayer_peer():
			_net_destroy.rpc()
		else:
			_show_destroy()
		get_tree().create_timer(RESPAWN_TIME).timeout.connect(_do_respawn)


# ── Visual helpers (run on every peer) ───────────────────────────────────────

func _show_hit(new_health: float, damage: float = 0.0) -> void:
	health = new_health
	_update_glow()
	_flash_white()
	if damage > 0.0:
		_spawn_damage_number(damage)


func _show_destroy() -> void:
	_dead   = true
	_state  = State.DEAD
	visible = false
	_col.set_deferred("disabled", true)
	_drop_loot()


func _show_respawn() -> void:
	_dead           = false
	_state          = State.IDLE
	health          = MAX_HEALTH
	_target         = null
	_idle_timer     = 2.0
	visible         = true
	global_position = _home_pos
	velocity        = Vector3.ZERO
	_col.set_deferred("disabled", false)
	_update_glow()


func _drop_loot() -> void:
	if drop_item == null:
		return
	var scene := load("res://scenes/world/pickable_item.tscn") as PackedScene
	if scene == null:
		return
	var inst := scene.instantiate() as Node3D
	inst.set("item_data", drop_item)
	get_parent().add_child(inst)
	inst.global_position = global_position + Vector3(0, 0.5, 0)


# ── Multiplayer broadcasts ────────────────────────────────────────────────────

@rpc("authority", "call_local", "unreliable_ordered")
func _net_hit(new_health: float, damage: float = 0.0) -> void:
	_show_hit(new_health, damage)


@rpc("authority", "call_local", "reliable")
func _net_destroy() -> void:
	_show_destroy()


@rpc("authority", "call_local", "reliable")
func _net_respawn() -> void:
	_show_respawn()


func _do_respawn() -> void:
	if not _is_authority():
		return
	if multiplayer.has_multiplayer_peer():
		_net_respawn.rpc()
	else:
		_show_respawn()


# ── Damage numbers ────────────────────────────────────────────────────────────

func _spawn_damage_number(damage: float) -> void:
	var label := Label3D.new()
	label.text          = str(int(damage))
	label.font_size     = 72
	label.outline_size  = 8
	label.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate      = Color(1.0, 0.25, 0.1)
	var offset := Vector3(randf_range(-0.3, 0.3), 1.8, randf_range(-0.15, 0.15))
	var level_parent := get_parent()
	level_parent.add_child(label)
	label.global_position = global_position + offset
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y",
		label.global_position.y + 1.2, 0.75) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, 0.75).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


# ── Glow / flash ──────────────────────────────────────────────────────────────

func _update_glow() -> void:
	if not is_inside_tree():
		return
	var t   : float = health / MAX_HEALTH
	var col : Color = Color(0.9, 0.12 * t, 0.04, 1.0)
	var mat := _mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat:
		mat.emission = col
	_light.light_color = col


func _flash_white() -> void:
	var mat := _mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat == null:
		return
	var t          : float = health / MAX_HEALTH
	var target_col : Color = Color(0.9, 0.12 * t, 0.04, 1.0)
	mat.emission = Color(3.0, 3.0, 3.0, 1.0)
	create_tween().tween_property(mat, "emission", target_col, 0.25)


func _flash_attack() -> void:
	var mat := _mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat == null:
		return
	var t          : float = health / MAX_HEALTH
	var target_col : Color = Color(0.9, 0.12 * t, 0.04, 1.0)
	mat.emission = Color(3.0, 1.0, 0.0, 1.0)
	create_tween().tween_property(mat, "emission", target_col, 0.35)


func _is_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
