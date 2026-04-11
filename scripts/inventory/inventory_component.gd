extends Node

signal slot_changed(index: int)
signal inventory_changed

const SLOT_COUNT : int = 30   # 6 columns × 5 rows

## Each slot is either null (empty) or { "id": String, "count": int }.
var slots : Array = []

## Equipment: slot_name → null or { "id": String, "count": 1 }.
var equipment : Dictionary = {
	"helm": null, "torso": null, "pants": null,
	"shoes": null, "left_hand": null, "right_hand": null, "neck": null,
}


func _ready() -> void:
	if slots.size() == 0:
		slots.resize(SLOT_COUNT)
		slots.fill(null)


## Try to add an item. Returns the number that could NOT be added (0 = all added).
func add_item(item: ItemData, count: int = 1) -> int:
	var remaining : int = count

	# First pass: stack into existing slots that hold the same item.
	if item.stackable:
		for i : int in SLOT_COUNT:
			if remaining <= 0:
				break
			var slot = slots[i]
			if slot == null or (slot as Dictionary)["id"] != item.id:
				continue
			var space : int = item.max_stack - (slot as Dictionary)["count"]
			if space <= 0:
				continue
			var to_add : int = mini(remaining, space)
			(slot as Dictionary)["count"] += to_add
			remaining -= to_add
			slot_changed.emit(i)

	# Second pass: fill empty slots.
	for i : int in SLOT_COUNT:
		if remaining <= 0:
			break
		if slots[i] != null:
			continue
		var to_add : int = mini(remaining, item.max_stack) if item.stackable else 1
		slots[i] = { "id": item.id, "count": to_add }
		remaining -= to_add
		slot_changed.emit(i)

	if remaining < count:
		inventory_changed.emit()
	return remaining


## Remove `count` of item by id. Returns actual number removed.
func remove_item_by_id(item_id: String, count: int = 1) -> int:
	var remaining : int = count
	for i : int in SLOT_COUNT:
		if remaining <= 0:
			break
		var slot = slots[i]
		if slot == null or (slot as Dictionary)["id"] != item_id:
			continue
		var to_remove : int = mini(remaining, (slot as Dictionary)["count"])
		(slot as Dictionary)["count"] -= to_remove
		remaining -= to_remove
		if (slot as Dictionary)["count"] <= 0:
			slots[i] = null
		slot_changed.emit(i)

	if remaining < count:
		inventory_changed.emit()
	return count - remaining


## Remove all items from a specific slot, returning the slot data (or null).
func take_slot(index: int) -> Variant:
	if index < 0 or index >= SLOT_COUNT:
		return null
	var data = slots[index]
	slots[index] = null
	if data != null:
		slot_changed.emit(index)
		inventory_changed.emit()
	return data


## Place slot data into a slot. Returns whatever was there previously.
func put_slot(index: int, data: Variant) -> Variant:
	if index < 0 or index >= SLOT_COUNT:
		return data
	var old = slots[index]

	# If both hold the same stackable item, merge stacks.
	if data != null and old != null \
		and (data as Dictionary)["id"] == (old as Dictionary)["id"]:
		var _item_res := load("res://data/items/" + (data as Dictionary)["id"] + ".tres") as ItemData
		if _item_res != null and _item_res.stackable:
			var space   : int = _item_res.max_stack - (old as Dictionary)["count"]
			var to_add  : int = mini((data as Dictionary)["count"], space)
			(old as Dictionary)["count"]  += to_add
			(data as Dictionary)["count"] -= to_add
			slot_changed.emit(index)
			inventory_changed.emit()
			return data if (data as Dictionary)["count"] > 0 else null

	slots[index] = data
	slot_changed.emit(index)
	inventory_changed.emit()
	return old


func has_item(item_id: String) -> bool:
	for slot in slots:
		if slot != null and (slot as Dictionary)["id"] == item_id:
			return true
	return false


func get_slot(index: int) -> Variant:
	if index < 0 or index >= SLOT_COUNT:
		return null
	return slots[index]


# ── Equipment ─────────────────────────────────────────────────────────────────

func get_equipment_slot(slot_name: String) -> Variant:
	return equipment.get(slot_name)


func equip_item(slot_name: String, inv_index: int) -> void:
	if not equipment.has(slot_name):
		return
	if inv_index < 0 or inv_index >= SLOT_COUNT or slots[inv_index] == null:
		return
	# Unequip current if occupied
	if equipment[slot_name] != null:
		var old: Dictionary = equipment[slot_name]
		# Find empty slot for old equipment
		for i: int in SLOT_COUNT:
			if slots[i] == null:
				slots[i] = old
				slot_changed.emit(i)
				break
	equipment[slot_name] = slots[inv_index]
	slots[inv_index] = null
	slot_changed.emit(inv_index)
	inventory_changed.emit()


func unequip_item(slot_name: String) -> bool:
	if not equipment.has(slot_name) or equipment[slot_name] == null:
		return false
	# Find empty inventory slot
	for i: int in SLOT_COUNT:
		if slots[i] == null:
			slots[i] = equipment[slot_name]
			equipment[slot_name] = null
			slot_changed.emit(i)
			inventory_changed.emit()
			return true
	return false  # No space


func get_equipment_save_data() -> Dictionary:
	var saved := {}
	for slot_name: String in equipment:
		if equipment[slot_name] == null:
			saved[slot_name] = null
		else:
			saved[slot_name] = {
				"id": (equipment[slot_name] as Dictionary)["id"],
				"count": (equipment[slot_name] as Dictionary)["count"],
			}
	return saved


func apply_equipment_save_data(data: Dictionary) -> void:
	for slot_name: String in data:
		if not equipment.has(slot_name):
			continue
		if data[slot_name] == null:
			equipment[slot_name] = null
		else:
			var entry: Dictionary = data[slot_name] as Dictionary
			equipment[slot_name] = {
				"id": entry["id"] as String,
				"count": int(entry.get("count", 1)),
			}
	inventory_changed.emit()


# ── Save / Load ───────────────────────────────────────────────────────────────

## Serialisiert alle Slots als JSON-fähiges Array.
## Leere Slots werden als null gespeichert (Index-Erhalt für die UI).
func get_save_data() -> Array:
	var result: Array = []
	for slot: Variant in slots:
		if slot == null:
			result.append(null)
		else:
			result.append({
				"id":    (slot as Dictionary)["id"],
				"count": (slot as Dictionary)["count"],
			})
	return result


## Stellt Inventar-Zustand aus gespeichertem Array wieder her.
## JSON lädt Zahlen als float → cast auf int nötig.
func apply_save_data(data: Array) -> void:
	slots.resize(SLOT_COUNT)
	slots.fill(null)
	for i: int in mini(data.size(), SLOT_COUNT):
		var entry: Variant = data[i]
		if entry == null:
			slots[i] = null
		elif entry is Dictionary and entry.has("id") and entry.has("count"):
			slots[i] = {
				"id":    (entry as Dictionary)["id"] as String,
				"count": int((entry as Dictionary)["count"]),
			}
	inventory_changed.emit()


## Server → Client: überträgt den vollständigen Inventar-Stand nach dem Spawn.
## "any_peer" statt "authority": Die Node-Authority liegt beim Client,
## aber der Server muss senden können (identisch zur Skills-Architektur).
@rpc("any_peer", "call_local", "reliable")
func sync_inventory(data: Array) -> void:
	apply_save_data(data)
