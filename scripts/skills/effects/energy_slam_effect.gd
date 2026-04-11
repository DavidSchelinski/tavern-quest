extends Node3D

## Blue energy blade that falls from above.
## Self-contained: spawns above the target area, falls down, deals AoE damage.

var damage : float = 20.0
var skill_level : int = 1

var _lifetime : float = 0.0
const FALL_DURATION := 0.35
const LINGER_DURATION := 0.4
const TOTAL_DURATION := 0.75   # FALL + LINGER
const FALL_HEIGHT := 6.0

var _blade_mesh : MeshInstance3D
var _impact_mesh : MeshInstance3D
var _hitbox : Area3D
var _hit_targets : Dictionary = {}
var _target_pos : Vector3
var _has_impacted : bool = false


func _ready() -> void:
	_target_pos = global_position
	global_position = _target_pos + Vector3(0, FALL_HEIGHT, 0)
	_build_blade()
	_build_impact()
	_build_hitbox()


func _build_blade() -> void:
	_blade_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 0.06, 0.2)
	_blade_mesh.mesh = box
	# Rotate blade to be vertical (falling edge-down)
	_blade_mesh.rotation.z = deg_to_rad(90)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.45, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.55, 1.0)
	mat.emission_energy_multiplier = 3.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_blade_mesh.material_override = mat
	add_child(_blade_mesh)


func _build_impact() -> void:
	_impact_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.5
	cyl.bottom_radius = 1.5
	cyl.height = 0.05
	_impact_mesh.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 1.0, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_impact_mesh.material_override = mat
	_impact_mesh.visible = false
	add_child(_impact_mesh)


func _build_hitbox() -> void:
	_hitbox = Area3D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 6
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.8
	shape.height = 2.0
	col.shape = shape
	_hitbox.add_child(col)
	_hitbox.monitoring = false
	add_child(_hitbox)
	_hitbox.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_lifetime += delta

	if _lifetime < FALL_DURATION:
		# Falling phase
		var t := _lifetime / FALL_DURATION
		var ease_t := t * t   # accelerate
		global_position = _target_pos + Vector3(0, FALL_HEIGHT * (1.0 - ease_t), 0)
		# Blade visible during fall
		_blade_mesh.visible = true
	elif not _has_impacted:
		# Impact frame
		_has_impacted = true
		global_position = _target_pos
		_blade_mesh.visible = false
		_impact_mesh.visible = true
		_impact_mesh.global_position = _target_pos
		# Enable hitbox on impact
		_hitbox.global_position = _target_pos
		_hitbox.monitoring = true
	else:
		# Linger phase — fade out impact ring
		var linger_t := (_lifetime - FALL_DURATION) / LINGER_DURATION
		if linger_t >= 1.0:
			queue_free()
			return
		var mat := _impact_mesh.material_override as StandardMaterial3D
		if mat:
			var alpha := lerpf(0.7, 0.0, linger_t)
			mat.albedo_color.a = alpha
		# Expand the impact ring
		var ring_scale := lerpf(1.0, 2.0, linger_t)
		_impact_mesh.scale = Vector3(ring_scale, 1.0, ring_scale)


func _on_body_entered(body: Node3D) -> void:
	if _hit_targets.has(body.get_instance_id()):
		return
	_hit_targets[body.get_instance_id()] = true
	if body.has_method("take_damage"):
		body.take_damage(damage)
