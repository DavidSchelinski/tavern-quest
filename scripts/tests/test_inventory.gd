extends Node

## Test-Suite: Inventar & Equipment


func run(runner: Node) -> void:
	print("\n[Gruppe] Inventar – Stacking & Slots")
	_test_add_item_stacking(runner)
	_test_remove_item(runner)
	_test_take_and_put_slot(runner)

	print("\n[Gruppe] Equipment")
	_test_equip_item(runner)
	_test_unequip_item(runner)
	_test_equipment_save_load(runner)


# ── Stacking ─────────────────────────────────────────────────────────────────

func _test_add_item_stacking(runner: Node) -> void:
	var inv: Node = _make_inventory()
	var slots: Array = inv.get("slots") as Array

	# Simulate adding stackable items
	slots[0] = {"id": "potion", "count": 10}
	slots[1] = {"id": "potion", "count": 5}

	runner.assert_eq("Stack_Slot0_Count", int((slots[0] as Dictionary)["count"]), 10)
	runner.assert_eq("Stack_Slot1_Count", int((slots[1] as Dictionary)["count"]), 5)

	inv.queue_free()


func _test_remove_item(runner: Node) -> void:
	var inv: Node = _make_inventory()
	var slots: Array = inv.get("slots") as Array
	slots[0] = {"id": "potion", "count": 5}

	var removed: int = inv.call("remove_item_by_id", "potion", 3) as int
	runner.assert_eq("Remove_Count", removed, 3)

	var remaining: int = int((slots[0] as Dictionary)["count"])
	runner.assert_eq("Remove_Remaining", remaining, 2)

	# Remove more than available
	var removed2: int = inv.call("remove_item_by_id", "potion", 10) as int
	runner.assert_eq("Remove_Capped", removed2, 2)
	runner.assert_true("Remove_SlotNull", slots[0] == null)

	inv.queue_free()


func _test_take_and_put_slot(runner: Node) -> void:
	var inv: Node = _make_inventory()
	var slots: Array = inv.get("slots") as Array
	slots[0] = {"id": "sword", "count": 1}

	var taken: Variant = inv.call("take_slot", 0)
	runner.assert_true("Take_NotNull", taken != null)
	runner.assert_eq("Take_ID", (taken as Dictionary)["id"], "sword")
	runner.assert_true("Take_SlotEmpty", slots[0] == null)

	var old: Variant = inv.call("put_slot", 2, taken)
	runner.assert_true("Put_OldNull", old == null)
	runner.assert_true("Put_SlotFilled", slots[2] != null)
	runner.assert_eq("Put_ID", (slots[2] as Dictionary)["id"], "sword")

	inv.queue_free()


# ── Equipment ────────────────────────────────────────────────────────────────

func _test_equip_item(runner: Node) -> void:
	var inv: Node = _make_inventory()
	var slots: Array = inv.get("slots") as Array
	slots[0] = {"id": "iron_helm", "count": 1}

	inv.call("equip_item", "helm", 0)
	runner.assert_true("Equip_SlotCleared", slots[0] == null)

	var equipped: Variant = inv.call("get_equipment_slot", "helm")
	runner.assert_true("Equip_NotNull", equipped != null)
	runner.assert_eq("Equip_ID", (equipped as Dictionary)["id"], "iron_helm")

	inv.queue_free()


func _test_unequip_item(runner: Node) -> void:
	var inv: Node = _make_inventory()
	var equipment: Dictionary = inv.get("equipment") as Dictionary
	equipment["torso"] = {"id": "leather_armor", "count": 1}

	var ok: bool = inv.call("unequip_item", "torso") as bool
	runner.assert_true("Unequip_Success", ok)
	runner.assert_true("Unequip_SlotNull", equipment["torso"] == null)

	# Item should be in inventory
	var slots: Array = inv.get("slots") as Array
	var found := false
	for slot: Variant in slots:
		if slot != null and (slot as Dictionary)["id"] == "leather_armor":
			found = true
			break
	runner.assert_true("Unequip_InInventory", found)

	inv.queue_free()


func _test_equipment_save_load(runner: Node) -> void:
	var inv: Node = _make_inventory()
	var equipment: Dictionary = inv.get("equipment") as Dictionary
	equipment["helm"] = {"id": "iron_helm", "count": 1}
	equipment["left_hand"] = {"id": "iron_sword", "count": 1}

	var save_data: Dictionary = inv.call("get_equipment_save_data") as Dictionary
	runner.assert_true("EqSave_HasHelm", save_data.has("helm"))
	runner.assert_true("EqSave_HelmNotNull", save_data["helm"] != null)
	runner.assert_eq("EqSave_HelmID", (save_data["helm"] as Dictionary)["id"], "iron_helm")

	# Load into fresh inventory
	var inv2: Node = _make_inventory()
	inv2.call("apply_equipment_save_data", save_data)
	var eq2: Dictionary = inv2.get("equipment") as Dictionary
	runner.assert_true("EqLoad_HelmNotNull", eq2["helm"] != null)
	runner.assert_eq("EqLoad_HelmID", (eq2["helm"] as Dictionary)["id"], "iron_helm")
	runner.assert_eq("EqLoad_LeftHandID", (eq2["left_hand"] as Dictionary)["id"], "iron_sword")
	runner.assert_true("EqLoad_TorsoNull", eq2["torso"] == null)

	inv.queue_free()
	inv2.queue_free()


# ── Helpers ──────────────────────────────────────────────────────────────────

func _make_inventory() -> Node:
	var inv: Node = preload("res://scripts/inventory/inventory_component.gd").new()
	add_child(inv)
	return inv
