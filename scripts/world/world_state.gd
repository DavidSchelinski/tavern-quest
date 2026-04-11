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


func get_save_data() -> Dictionary:
	return {
		"dropped_items": dropped_items.duplicate(true),
		"npc_states":    npc_states.duplicate(true),
		"time_of_day":   time_of_day,
	}


func apply_save_data(data: Dictionary) -> void:
	dropped_items = (data.get("dropped_items", []) as Array).duplicate(true)
	npc_states    = (data.get("npc_states", {}) as Dictionary).duplicate(true)
	time_of_day   = float(data.get("time_of_day", 8.0))
	world_state_changed.emit()


func clear() -> void:
	dropped_items.clear()
	npc_states.clear()
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
