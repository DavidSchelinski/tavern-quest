extends Node

signal slot_changed(index: int)
signal inventory_changed

const SLOT_COUNT := 30  # 6 columns x 5 rows

## Each slot is either null (empty) or { "item": ItemData, "count": int }.
var slots : Array = []


func _ready() -> void:
	slots.resize(SLOT_COUNT)
	slots.fill(null)


## Try to add an item. Returns the number of items that could NOT be added (0 = all added).
func add_item(item: ItemData, count: int = 1) -> int:
	var remaining := count

	# First pass: stack into existing slots that hold the same item.
	if item.stackable:
		for i in SLOT_COUNT:
			if remaining <= 0:
				break
			var slot = slots[i]
			if slot == null:
				continue
			if slot["item"].id != item.id:
				continue
			var space : int = item.max_stack - slot["count"]
			if space <= 0:
				continue
			var to_add : int = mini(remaining, space)
			slot["count"] += to_add
			remaining -= to_add
			slot_changed.emit(i)

	# Second pass: fill empty slots.
	for i in SLOT_COUNT:
		if remaining <= 0:
			break
		if slots[i] != null:
			continue
		var to_add : int = mini(remaining, item.max_stack) if item.stackable else 1
		slots[i] = { "item": item, "count": to_add }
		remaining -= to_add
		slot_changed.emit(i)

	if remaining < count:
		inventory_changed.emit()
	return remaining


## Remove `count` of item by id. Returns actual number removed.
func remove_item_by_id(item_id: String, count: int = 1) -> int:
	var remaining := count
	for i in SLOT_COUNT:
		if remaining <= 0:
			break
		var slot = slots[i]
		if slot == null or slot["item"].id != item_id:
			continue
		var to_remove : int = mini(remaining, slot["count"])
		slot["count"] -= to_remove
		remaining -= to_remove
		if slot["count"] <= 0:
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
		and data["item"].id == old["item"].id \
		and data["item"].stackable:
		var space : int = data["item"].max_stack - old["count"]
		var to_add : int = mini(data["count"], space)
		old["count"] += to_add
		data["count"] -= to_add
		slot_changed.emit(index)
		inventory_changed.emit()
		return data if data["count"] > 0 else null

	slots[index] = data
	slot_changed.emit(index)
	inventory_changed.emit()
	return old


func get_slot(index: int) -> Variant:
	if index < 0 or index >= SLOT_COUNT:
		return null
	return slots[index]
