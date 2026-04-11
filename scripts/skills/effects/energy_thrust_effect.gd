extends Node3D

## Blue energy thrust — a piercing lance that shoots forward.
## Self-contained: spawns, moves forward, deals damage, despawns.

var damage : float = 15.0
var skill_level : int = 1

var _lifetime : float = 0.0
const DURATION := 0.5
const THRUST_SPEED := 18.0

var _mesh : MeshInstance3D
var _hitbox : Area3D
var _hit_targets : Dictionary = {}
var _forward : Vector3


func _ready() -> void:
	_forward = -global_transform.basis.z.normalized()
	_build_visual()
	_build_hitbox()


func _build_visual() -> void:
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 2.2)
	_mesh.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.4, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.5, 1.0)
	mat.emission_energy_multiplier = 4.0
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
	shape.size = Vector3(0.4, 0.4, 2.4)
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

	# Move forward
	global_position += _forward * THRUST_SPEED * delta

	# Trail effect: elongate over time then shrink
	var stretch := lerpf(0.5, 1.0, minf(t * 4.0, 1.0))
	_mesh.scale.z = stretch

	# Fade out at end
	var mat := _mesh.material_override as StandardMaterial3D
	if mat and t > 0.6:
		mat.albedo_color.a = lerpf(0.9, 0.0, (t - 0.6) / 0.4)


func _on_body_entered(body: Node3D) -> void:
	if _hit_targets.has(body.get_instance_id()):
		return
	_hit_targets[body.get_instance_id()] = true
	if body.has_method("take_damage"):
		body.take_damage(damage)
