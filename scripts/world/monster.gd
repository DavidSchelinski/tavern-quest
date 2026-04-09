class_name Monster
extends CharacterBody3D

# Simple roaming monster. Wanders inside a radius around its spawn point
# and takes damage. Uses NavigationAgent3D when a navmesh is available
# and falls back to walking straight toward the wander target otherwise.

const GRAVITY      : float = 20.0
const RESPAWN_TIME : float = 10.0

@export_file("*.fbx", "*.glb", "*.gltf", "*.tscn", "*.scn") var mesh_path : String = "res://assets/models/monsters/wolf/wolf.fbx"
@export_file("*.fbx", "*.res") var anim_path : String = "res://assets/models/monsters/wolf/anims/wolf-anims.fbx"
@export var mesh_scale       : float   = 1.0
@export var mesh_offset      : Vector3 = Vector3.ZERO
@export_range(-180.0, 180.0, 1.0) var mesh_rotation_y_deg : float = 0.0
@export var max_health       : float   = 50.0
@export var move_speed       : float   = 1.8
@export var wander_radius    : float   = 8.0
## Optional explicit animation names (must exist in the anim library).
## When empty, the script picks one by keyword match.
@export var walk_anim_name   : String  = ""
@export var idle_anim_name   : String  = ""
@export var anim_blend_time  : float   = 0.35

@onready var _col : CollisionShape3D  = $CollisionShape3D
@onready var _nav : NavigationAgent3D = $NavigationAgent3D

var health       : float = 50.0
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
	health      = max_health
	_home_pos   = global_position
	_wander_pos = global_position
	_spawn_mesh()


func _spawn_mesh() -> void:
	if mesh_path == "":
		return
	var scene := load(mesh_path) as PackedScene
	if scene == null:
		push_warning("[Monster] failed to load mesh scene at " + mesh_path)
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
	if _mesh_root == null or anim_path == "":
		return
	_anim_player = _find_animation_player(_mesh_root)
	if _anim_player == null:
		# Source FBX has no AnimationPlayer — create one so we can host
		# the external animation library on it.
		_anim_player = AnimationPlayer.new()
		_anim_player.name = "AnimationPlayer"
		_mesh_root.add_child(_anim_player)

	var lib := load(anim_path) as AnimationLibrary
	if lib == null:
		push_warning("[Monster] failed to load animation library at " + anim_path)
		return
	# Unique library name per source file so multiple monsters don't collide.
	var lib_name := StringName(anim_path.get_file().get_basename())
	if _anim_player.has_animation_library(lib_name):
		_anim_player.remove_animation_library(lib_name)
	_anim_player.add_animation_library(lib_name, lib)

	_walk_anim = _resolve_anim(lib, lib_name, walk_anim_name, "walk", &"")
	_idle_anim = _resolve_anim(lib, lib_name, idle_anim_name, "idle", _walk_anim)
	if _idle_anim == &"":
		push_warning("[Monster] no real idle animation found in " + anim_path
			+ " — rat-style rigs need a dedicated idle action exported from Blender")


const MIN_ANIM_LENGTH : float = 0.1

## Resolve an animation from a library by (in order):
##   1) an explicit name provided in the inspector
##   2) a keyword match (e.g. "idle" / "walk"), skipping stub clips
##   3) any non-stub animation that isn't `exclude` (idle fallback when the
##      rig only ships a walk clip and no dedicated idle).
func _resolve_anim(lib: AnimationLibrary, lib_name: StringName,
		explicit: String, keyword: String, exclude: StringName) -> StringName:
	var names := lib.get_animation_list()

	if explicit != "":
		for n in names:
			if String(n) == explicit:
				return _finalize_anim(lib, lib_name, n)

	var key := keyword.to_lower()
	for n in names:
		if String(n).to_lower().contains(key) and _is_real_anim(lib, n):
			return _finalize_anim(lib, lib_name, n)

	for n in names:
		if not _is_real_anim(lib, n):
			continue
		var full := StringName(String(lib_name) + "/" + String(n))
		if full != exclude:
			return _finalize_anim(lib, lib_name, n)

	return &""


func _is_real_anim(lib: AnimationLibrary, anim_name: StringName) -> bool:
	var anim := lib.get_animation(anim_name)
	return anim != null and anim.length >= MIN_ANIM_LENGTH and anim.get_track_count() > 0


func _finalize_anim(lib: AnimationLibrary, lib_name: StringName, anim_name: StringName) -> StringName:
	var anim := lib.get_animation(anim_name)
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR
	return StringName(String(lib_name) + "/" + String(anim_name))


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
		# No animation to switch to — fade the current clip out so we don't
		# keep walking in place when the monster has no idle clip.
		if _anim_player.is_playing():
			_anim_player.stop()
		return
	if _anim_player.current_animation != String(target):
		_anim_player.play(target, anim_blend_time)


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
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		_face_dir(dir, 0.12)


func _pick_wander_target() -> void:
	var angle  := randf() * TAU
	var radius := randf_range(2.0, wander_radius)
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
	health          = max_health
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
