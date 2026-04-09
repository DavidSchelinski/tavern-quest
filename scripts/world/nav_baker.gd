extends NavigationRegion3D
## Automatically bakes the NavigationMesh at runtime.
## Attached to the NavigationRegion3D node in main.tscn.
## Waits two physics frames so that CSGShape3D nodes have finished
## creating their StaticBody3D collision shapes before baking.

func _ready() -> void:
	var nm := NavigationMesh.new()
	nm.agent_radius    = 0.5
	nm.agent_height    = 2.0
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 45.0
	# 1 = PARSED_GEOMETRY_STATIC_COLLIDERS → bakes from StaticBody3D shapes
	# (CSGShape3D with use_collision=true creates StaticBody3D at runtime)
	nm.set("geometry/parsed_geometry_type", 1)
	nm.set("geometry/collision_mask", 1)   # layer 1 = world geometry
	nm.set("cell/size", 0.25)
	nm.set("cell/height", 0.25)
	navigation_mesh = nm

	# Two physics frames: CSG shapes need at least one frame to register.
	await get_tree().physics_frame
	await get_tree().physics_frame
	bake_navigation_mesh(true)   # true = threaded, won't freeze the frame
