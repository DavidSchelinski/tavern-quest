class_name PickableItem
extends RigidBody3D

@export var item_data : ItemData = null
@export var interact_radius : float = 3.0

var _hint        : Label3D
var _mesh        : MeshInstance3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("pickable")

	# Physics setup — small bouncy object.
	mass = 0.5
	gravity_scale = 1.0
	collision_layer = 1
	collision_mask  = 1

	# Collision shape.
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.35, 0.35, 0.35)
	col.shape = shape
	add_child(col)

	# Visual mesh — colored box placeholder.
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	_mesh.mesh = box
	_mesh.position = Vector3.ZERO
	add_child(_mesh)

	# Billboard hint.
	_hint = Label3D.new()
	_hint.text = "[E] Pick up"
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.font_size = 20
	_hint.pixel_size = 0.007
	_hint.modulate = Color(0.95, 0.88, 0.60, 1)
	_hint.outline_size = 5
	_hint.outline_modulate = Color(0.08, 0.05, 0.01, 1)
	_hint.visible = false
	_hint.position = Vector3(0, 0.6, 0)
	add_child(_hint)

	_apply_item_color()

	# Small bobbing tween for visibility.
	var tw := create_tween().set_loops()
	tw.tween_property(_mesh, "position:y", 0.08, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_mesh, "position:y", -0.02, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _apply_item_color() -> void:
	if item_data == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = item_data.mesh_color
	mat.emission_enabled = true
	mat.emission = item_data.mesh_color.lightened(0.3)
	mat.emission_energy_multiplier = 0.4
	_mesh.material_override = mat

	if not item_data.display_name.is_empty():
		_hint.text = "[E] " + item_data.display_name


func interact(actor: Node3D) -> void:
	_pickup(actor)


func on_look_at() -> void:
	_hint.visible = true


func on_look_away() -> void:
	_hint.visible = false


func _pickup(actor: Node3D) -> void:
	if item_data == null:
		queue_free()
		return
	var leftover: int = actor.get_node("Inventory").add_item(item_data, 1)
	if leftover == 0:
		queue_free()
