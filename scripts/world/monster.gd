class_name Monster
extends CharacterBody3D

# Simple roaming monster. Wanders inside a radius around its spawn point
# and takes damage. Uses NavigationAgent3D when a navmesh is available
# and falls back to walking straight toward the wander target otherwise.

const MAX_HEALTH    : float = 50.0
const MOVE_SPEED    : float = 1.8
const GRAVITY       : float = 20.0
const WANDER_RADIUS : float = 8.0
const RESPAWN_TIME  : float = 10.0

@export var mesh_scene       : PackedScene = null
@export var mesh_scale       : float       = 1.0
@export var mesh_offset      : Vector3     = Vector3.ZERO
@export_range(-180.0, 180.0, 1.0) var mesh_rotation_y_deg : float = 0.0

@onready var _col : CollisionShape3D  = $CollisionShape3D
@onready var _nav : NavigationAgent3D = $NavigationAgent3D

var health       : float = MAX_HEALTH
var _home_pos    : Vector3
var _wander_pos  : Vector3
var _idle_timer  : float = 1.0
var _dead        : bool  = false
var _mesh_root   : Node3D = null
var _anim_player : AnimationPlayer = null
var _walk_anim   : StringName = &""
var _idle_anim   : StringName = &""

enum State { IDLE, WANDER, DEAD }
var _state : State = State.IDLE


func _ready() -> void:
	add_to_group("monster")
	_home_pos   = global_position
	_wander_pos = global_position
	_spawn_mesh()


func _spawn_mesh() -> void:
	# Default to the wolf FBX if no mesh scene was assigned in the inspector.
	var scene := mesh_scene
	if scene == null:
		scene = load("res://assets/models/monsters/wolf/wolf.fbx") as PackedScene
	if scene == null:
		return
	var inst := scene.instantiate() as Node3D
	if inst == null:
		return
	_mesh_root = inst
	inst.scale = Vector3.ONE * mesh_scale
	inst.position = mesh_offset
	inst.rotation = Vector3(0.0, deg_to_rad(mesh_rotation_y_deg), 0.0)
	add_child(inst)
	_setup_animation()


func _setup_animation() -> void:
	if _mesh_root == null:
		return
	_anim_player = _find_animation_player(_mesh_root)
	if _anim_player == null:
		# Wolf FBX has no AnimationPlayer — create one so we can host the
		# external walk animation library on it.
		_anim_player = AnimationPlayer.new()
		_anim_player.name = "AnimationPlayer"
		_mesh_root.add_child(_anim_player)

	_walk_anim = _register_anim_lib(&"wolf_walk",
		"res://assets/models/monsters/wolf/anims/walk.fbx")
	_idle_anim = _register_anim_lib(&"wolf_idle",
		"res://assets/models/monsters/wolf/anims/idle.fbx")


func _register_anim_lib(lib_name: StringName, path: String) -> StringName:
	var lib := load(path) as AnimationLibrary
	if lib == null:
		return &""
	if _anim_player.has_animation_library(lib_name):
		_anim_player.remove_animation_library(lib_name)
	_anim_player.add_animation_library(lib_name, lib)
	var names := lib.get_animation_list()
	if names.size() == 0:
		return &""
	var anim := lib.get_animation(names[0])
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR
	return StringName(String(lib_name) + "/" + String(names[0]))


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := _find_animation_player(c)
		if found != null:
			return found
	return null


func _update_anim() -> void:
	if _anim_player == null:
		return
	var moving := _state == State.WANDER and Vector2(velocity.x, velocity.z).length() > 0.1
	var target : StringName = _walk_anim if moving else _idle_anim
	if target == &"":
		return
	if _anim_player.current_animation != String(target):
		_anim_player.play(target)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if _dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	match _state:
		State.IDLE:   _tick_idle(delta)
		State.WANDER: _tick_wander(delta)

	move_and_slide()
	_update_anim()


func _tick_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_pick_wander_target()
		_state = State.WANDER


func _tick_wander(_delta: float) -> void:
	var dist := global_position.distance_to(_wander_pos)
	if _nav.is_navigation_finished() or dist < 0.8:
		velocity.x  = 0.0
		velocity.z  = 0.0
		_state      = State.IDLE
		_idle_timer = randf_range(2.0, 5.0)
		return

	var next := _nav.get_next_path_position()
	var dir  := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	# Fallback when no navmesh is baked: walk straight toward the target.
	if dir.length_squared() < 0.04:
		dir = Vector3(_wander_pos.x - global_position.x, 0.0, _wander_pos.z - global_position.z)
	if dir.length_squared() > 0.001:
		dir        = dir.normalized()
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED
		_face_dir(dir, 0.12)


func _pick_wander_target() -> void:
	var angle  := randf() * TAU
	var radius := randf_range(2.0, WANDER_RADIUS)
	_wander_pos = _home_pos + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	_nav.set_target_position(_wander_pos)


func _face_dir(dir: Vector3, weight: float) -> void:
	if dir.length_squared() < 0.001:
		return
	basis = basis.slerp(Basis.looking_at(dir, Vector3.UP), weight)


# ─── Damage ───────────────────────────────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func take_damage(amount: float) -> void:
	_apply_damage(amount)


func _apply_damage(amount: float) -> void:
	if _dead:
		return
	health = maxf(0.0, health - amount)
	_spawn_damage_number(amount)
	if health <= 0.0:
		_die()


func _die() -> void:
	_dead   = true
	_state  = State.DEAD
	visible = false
	_col.set_deferred("disabled", true)
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(_respawn)


func _respawn() -> void:
	_dead           = false
	_state          = State.IDLE
	health          = MAX_HEALTH
	_idle_timer     = 1.0
	visible         = true
	global_position = _home_pos
	velocity        = Vector3.ZERO
	_col.set_deferred("disabled", false)


func _spawn_damage_number(damage: float) -> void:
	var label := Label3D.new()
	label.text          = str(int(damage))
	label.font_size     = 72
	label.outline_size  = 8
	label.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate      = Color(1.0, 0.85, 0.2)
	var offset := Vector3(randf_range(-0.3, 0.3), 1.6, randf_range(-0.15, 0.15))
	var parent := get_parent()
	parent.add_child(label)
	label.global_position = global_position + offset
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y",
		label.global_position.y + 1.2, 0.75) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, 0.75).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)
