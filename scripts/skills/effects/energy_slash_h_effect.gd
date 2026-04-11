extends Node3D

## Horizontal blue energy blade that sweeps in front of the caster.
## Self-contained: spawns, animates, deals damage, despawns.

var damage : float = 10.0
var skill_level : int = 1

var _lifetime : float = 0.0
const DURATION := 0.6
const SWEEP_ARC := 1.8   # radians of horizontal sweep

var _mesh : MeshInstance3D
var _hitbox : Area3D
var _hit_targets : Dictionary = {}
var _initial_y_rot : float = 0.0


func _ready() -> void:
	_initial_y_rot = global_rotation.y
	_build_visual()
	_build_hitbox()


func _build_visual() -> void:
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.8, 0.08, 0.15)
	_mesh.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = mat
	add_child(_mesh)


func _build_hitbox() -> void:
	_hitbox = Area3D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 6   # layers 2 (players) + 4 (dummies/enemies)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 0.5, 0.5)
	col.shape = shape
	_hitbox.add_child(col)
	add_child(_hitbox)
	_hitbox.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_lifetime += delta
	var t := _lifetime / DURATION

	if t >= 1.0:
		queue_free()
		return

	# Sweep rotation: arc from left to right
	var sweep_angle := lerpf(-SWEEP_ARC / 2.0, SWEEP_ARC / 2.0, t)
	global_rotation.y = _initial_y_rot + sweep_angle

	# Move forward slightly during sweep
	var forward := -global_transform.basis.z.normalized()
	_mesh.position = forward * 0.8

	# Fade out towards end
	var mat := _mesh.material_override as StandardMaterial3D
	if mat and t > 0.7:
		mat.albedo_color.a = lerpf(0.85, 0.0, (t - 0.7) / 0.3)

	# Scale up slightly for impact feel
	var scale_factor := lerpf(0.6, 1.2, minf(t * 3.0, 1.0))
	_mesh.scale = Vector3(scale_factor, scale_factor, scale_factor)


func _on_body_entered(body: Node3D) -> void:
	if _hit_targets.has(body.get_instance_id()):
		return
	_hit_targets[body.get_instance_id()] = true
	if body.has_method("take_damage"):
		body.take_damage(damage)
