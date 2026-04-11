extends Node

## Test-Suite: Welt-Zustand (Persistence, Dropped Items, NPC States)

const TEST_WORLD := "_test_ws_world_"


func run(runner: Node) -> void:
	print("\n[Gruppe] WorldState – Basis")
	_test_save_load_roundtrip(runner)
	_test_dropped_items(runner)
	_test_npc_states(runner)

	print("\n[Gruppe] SaveManager – Welt-Löschung")
	_test_world_deletion(runner)

	_cleanup()


func _test_save_load_roundtrip(runner: Node) -> void:
	WorldState.clear()
	WorldState.time_of_day = 18.5
	WorldState.register_dropped_item("gold_coin", 10, Vector3(1.0, 0.0, 5.0))

	var data: Dictionary = WorldState.get_save_data()
	runner.assert_eq("WS_TimeOfDay", data.get("time_of_day"), 18.5)
	runner.assert_eq("WS_DroppedCount", (data.get("dropped_items") as Array).size(), 1)

	# Clear and reload
	WorldState.clear()
	runner.assert_eq("WS_AfterClear_Time", WorldState.time_of_day, 8.0)

	WorldState.apply_save_data(data)
	runner.assert_eq("WS_Loaded_Time", WorldState.time_of_day, 18.5)
	runner.assert_eq("WS_Loaded_DroppedCount", WorldState.dropped_items.size(), 1)


func _test_dropped_items(runner: Node) -> void:
	WorldState.clear()
	WorldState.register_dropped_item("potion", 3, Vector3(2.0, 0.0, 3.0))
	WorldState.register_dropped_item("sword", 1, Vector3(5.0, 1.0, 8.0))

	runner.assert_eq("WS_Dropped_Count2", WorldState.dropped_items.size(), 2)

	var item0: Dictionary = WorldState.dropped_items[0] as Dictionary
	runner.assert_eq("WS_Dropped_0_ID", item0["item_id"], "potion")
	runner.assert_eq("WS_Dropped_0_Count", int(item0["count"]), 3)

	WorldState.remove_dropped_item(0)
	runner.assert_eq("WS_Dropped_AfterRemove", WorldState.dropped_items.size(), 1)
	runner.assert_eq("WS_Dropped_Remaining_ID", (WorldState.dropped_items[0] as Dictionary)["item_id"], "sword")


func _test_npc_states(runner: Node) -> void:
	WorldState.clear()
	WorldState.set_npc_state("merchant_01", {"mood": "happy", "gold": 500})
	WorldState.set_npc_state("guard_01", {"alert": true})

	var merchant: Dictionary = WorldState.get_npc_state("merchant_01")
	runner.assert_eq("WS_NPC_Merchant_Mood", merchant.get("mood"), "happy")
	runner.assert_eq("WS_NPC_Merchant_Gold", int(merchant.get("gold", 0)), 500)

	var guard: Dictionary = WorldState.get_npc_state("guard_01")
	runner.assert_true("WS_NPC_Guard_Alert", guard.get("alert", false) as bool)

	# Non-existent NPC → empty dict
	var unknown: Dictionary = WorldState.get_npc_state("nobody")
	runner.assert_eq("WS_NPC_Unknown_Empty", unknown.size(), 0)


func _test_world_deletion(runner: Node) -> void:
	SaveManager.set_world(TEST_WORLD)
	SaveManager.update_player_data("__delete_test__", {"x": 1})
	runner.assert_true("WS_Delete_WorldExists", TEST_WORLD in SaveManager.list_available_worlds())

	var ok: bool = SaveManager.delete_world(TEST_WORLD)
	runner.assert_true("WS_Delete_Success", ok)
	runner.assert_true("WS_Delete_Gone", TEST_WORLD not in SaveManager.list_available_worlds())


func _cleanup() -> void:
	WorldState.clear()
	# Ensure test world is cleaned up
	if TEST_WORLD in SaveManager.list_available_worlds():
		SaveManager.delete_world(TEST_WORLD)
