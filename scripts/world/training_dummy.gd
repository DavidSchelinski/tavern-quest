extends StaticBody3D

const MAX_HEALTH   : float = 15.0
const RESPAWN_TIME : float = 5.0
const BOB_HEIGHT   : float = 0.25   # metres
const BOB_SPEED    : float = 1.3    # cycles per second
const SPIN_SPEED   : float = 0.6    # rotations per second

@export var drop_item : ItemData = null

var health : float = MAX_HEALTH

@onready var _mesh  : MeshInstance3D   = $Mesh
@onready var _light : OmniLight3D      = $OmniLight3D
@onready var _col   : CollisionShape3D = $CollisionShape3D

var _base_y    : float  = 0.0
var _dead      : bool   = false
var _hurt_area : Area3D = null


func _ready() -> void:
	add_to_group("dummy")
	_base_y = position.y + 1.2
	_update_glow()
	_setup_hurt_area()


func _setup_hurt_area() -> void:
	_hurt_area = Area3D.new()
	_hurt_area.name             = "HurtArea"
	_hurt_area.collision_layer  = 4
	_hurt_area.collision_mask   = 0
	_hurt_area.monitorable      = true
	_hurt_area.monitoring       = false
	var col   := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 0.8, 0.8)
	col.shape  = shape
	_hurt_area.add_child(col)
	add_child(_hurt_area)


func _process(delta: float) -> void:
	if _dead:
		return
	var t : float = Time.get_ticks_msec() * 0.001
	position.y  = _base_y + sin(t * BOB_SPEED * TAU) * BOB_HEIGHT
	rotation.y += SPIN_SPEED * TAU * delta


# ─────────────────────────────────────────────────────────────────────────────
# Damage entry point
#   Single-player  → called directly:         body.take_damage(dmg)
#   Multiplayer    → called via RPC on server: body.take_damage.rpc_id(1, dmg)
# ─────────────────────────────────────────────────────────────────────────────
@rpc("any_peer", "call_remote", "reliable")
func take_damage(amount: float) -> void:
	if not _is_authority():
		return
	_apply_damage(amount)


func _apply_damage(amount: float) -> void:
	if _dead:
		return
	health = maxf(0.0, health - amount)

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
	visible = false
	_col.set_deferred("disabled", true)
	_drop_loot()


func _drop_loot() -> void:
	if drop_item == null:
		return
	var scene := load("res://scenes/world/pickable_item.tscn") as PackedScene
	if scene == null:
		return
	var inst : Node3D = scene.instantiate()
	inst.set("item_data", drop_item)
	get_parent().add_child(inst)
	inst.global_position = global_position + Vector3(0, 0.5, 0)


func _show_respawn() -> void:
	_dead   = false
	health  = MAX_HEALTH
	visible = true
	_col.set_deferred("disabled", false)
	_update_glow()


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


# ── Respawn (server/SP only) ──────────────────────────────────────────────────

func _do_respawn() -> void:
	if not _is_authority():
		return
	if multiplayer.has_multiplayer_peer():
		_net_respawn.rpc()
	else:
		_show_respawn()


# ── Damage numbers ───────────────────────────────────────────────────────────

func _spawn_damage_number(damage: float) -> void:
	var label := Label3D.new()
	label.text         = str(int(damage))
	label.font_size    = 72
	label.outline_size = 8
	label.billboard    = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate     = Color(1.0, 0.25, 0.1)

	var offset := Vector3(
		randf_range(-0.3, 0.3),
		1.8,
		randf_range(-0.15, 0.15)
	)

	# Add to our own parent (the level/world node) so the label isn't in the
	# scene-tree root and gets cleaned up with the level.
	var level_parent : Node = get_parent()
	level_parent.add_child(label)
	label.global_position = global_position + offset

	var tween : Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y",
		label.global_position.y + 1.2, 0.75) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, 0.75) \
		.set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


# ── Glow / flash ─────────────────────────────────────────────────────────────

func _update_glow() -> void:
	if not is_inside_tree():
		return
	var t   : float = health / MAX_HEALTH
	var col : Color = Color(1.0 - t, t * 0.85 + 0.1, 0.15, 1.0)
	var mat := _mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat:
		mat.emission = col
	_light.light_color = col


func _flash_white() -> void:
	var mat := _mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat == null:
		return
	var t          : float = health / MAX_HEALTH
	var target_col : Color = Color(1.0 - t, t * 0.85 + 0.1, 0.15, 1.0)
	mat.emission = Color(3.0, 3.0, 3.0, 1.0)
	var tw : Tween = create_tween()
	tw.tween_property(mat, "emission", target_col, 0.25)


func _is_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
