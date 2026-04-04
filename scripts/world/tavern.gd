## Attaches a trimesh collision shape to the imported FBX tavern at runtime.
## The StaticBody3D root needs no collision nodes in the scene file —
## this script builds one ConcavePolygonShape3D from all child MeshInstance3Ds.
extends StaticBody3D


func _ready() -> void:
	_build_trimesh_collision()


func _build_trimesh_collision() -> void:
	var faces := PackedVector3Array()
	_collect_faces(self, faces)

	if faces.is_empty():
		push_warning("Tavern: no mesh faces found — collision skipped")
		return

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)

	var cs := CollisionShape3D.new()
	cs.name = "TrimeshCollision"
	cs.shape = shape
	add_child(cs)


## Recursively collects all triangle faces from MeshInstance3D descendants,
## transformed into this StaticBody3D's local space.
func _collect_faces(node: Node, faces: PackedVector3Array) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var xf: Transform3D = global_transform.affine_inverse() * mi.global_transform
			for v in mi.mesh.get_faces():
				faces.append(xf * v)
	for child in node.get_children():
		_collect_faces(child, faces)
