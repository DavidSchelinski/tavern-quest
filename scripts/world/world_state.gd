extends Node

## Sammelt und verwaltet den persistierbaren Welt-Zustand:
## Dropped Items, NPC-States, Tageszeit, etc.
## Wird als Autoload registriert: WorldState

signal world_state_changed


## Dropped items on the ground: Array of { "item_id": String, "count": int, "position": { "x", "y", "z" } }
var dropped_items : Array = []

## NPC states: npc_id → Dictionary with arbitrary state data
var npc_states : Dictionary = {}

## Day/night time of day (0.0 - 24.0)
var time_of_day : float = 8.0

## Node paths of items permanently removed from the world (picked up, consumed, etc.)
var removed_items : Array[String] = []


func get_save_data() -> Dictionary:
	return {
		"dropped_items": dropped_items.duplicate(true),
		"npc_states":    npc_states.duplicate(true),
		"time_of_day":   time_of_day,
		"removed_items": removed_items.duplicate(),
	}


func apply_save_data(data: Dictionary) -> void:
	dropped_items = (data.get("dropped_items", []) as Array).duplicate(true)
	npc_states    = (data.get("npc_states", {}) as Dictionary).duplicate(true)
	time_of_day   = float(data.get("time_of_day", 8.0))
	if data.has("removed_items") and data["removed_items"] is Array:
		removed_items.clear()
		for entry: Variant in data["removed_items"]:
			removed_items.append(str(entry))
	world_state_changed.emit()


func clear() -> void:
	dropped_items.clear()
	npc_states.clear()
	removed_items.clear()
	time_of_day = 8.0


## Registers a dropped item in the world state for persistence.
func register_dropped_item(item_id: String, count: int, pos: Vector3) -> void:
	dropped_items.append({
		"item_id": item_id,
		"count": count,
		"position": { "x": pos.x, "y": pos.y, "z": pos.z },
	})


## Removes a dropped item entry (e.g. when picked up).
func remove_dropped_item(index: int) -> void:
	if index >= 0 and index < dropped_items.size():
		dropped_items.remove_at(index)


## Sets arbitrary state for an NPC.
func set_npc_state(npc_id: String, state: Dictionary) -> void:
	npc_states[npc_id] = state


## Gets NPC state, or empty dict if none stored.
func get_npc_state(npc_id: String) -> Dictionary:
	return npc_states.get(npc_id, {}) as Dictionary


## Registers a world item (by node path) as permanently removed.
func register_removed_item(node_path: NodePath) -> void:
	var path_str := str(node_path)
	if path_str not in removed_items:
		removed_items.append(path_str)


## Returns true if the given item path was removed from the world.
func is_item_removed(node_path: String) -> bool:
	return node_path in removed_items


## Removes all tracked picked-up items from the scene tree. Call on guest join.
func apply_removed_items(scene_tree: SceneTree) -> void:
	for path_str: String in removed_items:
		var node := scene_tree.root.get_node_or_null(path_str)
		if node != null:
			node.queue_free()
