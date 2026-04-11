extends Node

signal slot_changed(index: int)
signal inventory_changed

const SLOT_COUNT : int = 30   # 6 columns × 5 rows

## Each slot is either null (empty) or { "item": ItemData, "count": int }.
var slots : Array = []


func _ready() -> void:
	if slots.size() == 0: # Nur wenn das Array noch gar nicht existiert
		slots.resize(SLOT_COUNT)
		slots.fill(null)
	# Wenn slots.size() bereits 30 ist (weil apply_save_data es gesetzt hat), 
	# tun wir hier GAR NICHTS und behalten die Items.


## Try to add an item. Returns the number that could NOT be added (0 = all added).
func add_item(item: ItemData, count: int = 1) -> int:
	var remaining : int = count

	# First pass: stack into existing slots that hold the same item.
	if item.stackable:
		for i : int in SLOT_COUNT:
			if remaining <= 0:
				break
			var slot = slots[i]
			if slot == null or (slot as Dictionary)["item"].id != item.id:
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
		slots[i] = { "item": item, "count": to_add }
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
		if slot == null or (slot as Dictionary)["item"].id != item_id:
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
		and (data as Dictionary)["item"].id == (old as Dictionary)["item"].id \
		and (data as Dictionary)["item"].stackable:
		var space   : int = (data as Dictionary)["item"].max_stack - (old as Dictionary)["count"]
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
		if slot != null and (slot as Dictionary)["item"].id == item_id:
			return true
	return false


func get_slot(index: int) -> Variant:
	if index < 0 or index >= SLOT_COUNT:
		return null
	return slots[index]

# ── Save & Load ───────────────────────────────────────────────────────────────

func get_save_data() -> Array:
	var saved_slots = []
	for slot in slots:
		if slot == null:
			saved_slots.append(null)
		else:
			# Wir speichern nur die Text-Werte, nicht die Ressource selbst!
			var item_dict = slot as Dictionary
			saved_slots.append({
				"item_id": item_dict["item"].id,
				"count": item_dict["count"]
			})
	return saved_slots

func apply_save_data(saved_data: Array) -> void:
	for i in range(mini(slots.size(), saved_data.size())):
		var data = saved_data[i]
		if data == null:
			slots[i] = null
		else:
			var item_id = data["item_id"]
			var count = data["count"]
			
			# ACHTUNG: Passe diesen Pfad an den echten Ordner deiner Item-Ressourcen an!
			# Beispiel: "res://items/resources/" + item_id + ".tres"
			var item_path = "res://data/items/" + item_id + ".tres"
			
			if ResourceLoader.exists(item_path):
				var item_resource = load(item_path) as ItemData
				slots[i] = { "item": item_resource, "count": count }
			else:
				push_error("InventoryLoad: Item-Datei nicht gefunden: " + item_path)
				slots[i] = null
				
		slot_changed.emit(i)
	inventory_changed.emit()

# Diese Funktion wird vom Server aufgerufen, um dem Gast beim Start sein Inventar zu geben
@rpc("authority", "call_remote", "reliable")
func sync_inventory(saved_data: Array) -> void:
	apply_save_data(saved_data)
