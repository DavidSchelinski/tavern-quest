extends Node

## Test-Suite: Speichern & Laden
##
## Hinweis: Alle Hilfsfunktionen geben Node zurück, weshalb alle
## Methodenaufrufe über .call() / .get() laufen, um Typ-Inferenzfehler
## in GDScript zu vermeiden.

const TEST_WORLD := "_test_world_"
const HOST_NAME  := "Host_Gamer"
const GUEST_NAME := "Gast_1"


func run(runner: Node) -> void:
	print("\n[Gruppe] SaveManager – Basis")
	_test_save_manager_write_read(runner)
	_test_save_manager_default_data(runner)
	_test_save_manager_list_worlds(runner)

	print("\n[Gruppe] Inventar-Persistenz")
	_test_inventory_persist_items(runner)
	_test_inventory_empty_slots(runner)

	print("\n[Gruppe] Skill-Persistenz")
	_test_skill_persist(runner)
	_test_skill_points_persist(runner)
	_test_hotbar_persist(runner)

	print("\n[Gruppe] Stats-Persistenz")
	_test_stats_persist(runner)

	print("\n[Gruppe] Quest-Persistenz")
	_test_quest_persist_active(runner)
	_test_quest_persist_completed(runner)

	print("\n[Gruppe] Gildenrang-Persistenz")
	_test_guild_rank_persist(runner)

	print("\n[Gruppe] HP/Stamina-Persistenz")
	_test_hp_stamina_persist(runner)

	print("\n[Gruppe] Vollständiges Szenario: Host_Gamer + Gast_1")
	_test_full_multiplayer_scenario(runner)

	_cleanup_test_world()


# ══════════════════════════════════════════════════════════════════════════════
#  SAVEMANAGER – BASIS
# ══════════════════════════════════════════════════════════════════════════════

func _test_save_manager_write_read(runner: Node) -> void:
	SaveManager.set_world(TEST_WORLD)
	var original: Dictionary = {"test_key": "test_value", "number": 42}
	SaveManager.update_player_data("__test_rw__", original)
	var loaded: Dictionary = SaveManager.get_player_data("__test_rw__")

	runner.assert_eq("SM_WriteRead_key",    loaded.get("test_key"), "test_value")
	runner.assert_eq("SM_WriteRead_number", int(loaded.get("number", 0)), 42)


func _test_save_manager_default_data(runner: Node) -> void:
	SaveManager.set_world(TEST_WORLD)
	var data: Dictionary = SaveManager.get_player_data("__nonexistent__")

	runner.assert_has_key("SM_Default_skills",    data, "skills")
	runner.assert_has_key("SM_Default_inventory", data, "inventory")
	runner.assert_has_key("SM_Default_stats",     data, "stats_data")
	runner.assert_has_key("SM_Default_quests",    data, "quests_data")
	runner.assert_has_key("SM_Default_guild",     data, "guild_data")
	runner.assert_eq("SM_Default_points", int(data.get("points", -1)), 5)


func _test_save_manager_list_worlds(runner: Node) -> void:
	SaveManager.set_world(TEST_WORLD)
	SaveManager.update_player_data("__list_test__", {"x": 1})
	var worlds: Array[String] = SaveManager.list_available_worlds()
	runner.assert_true("SM_ListWorlds_contains_test", TEST_WORLD in worlds)


# ══════════════════════════════════════════════════════════════════════════════
#  INVENTAR
# ══════════════════════════════════════════════════════════════════════════════

func _test_inventory_persist_items(runner: Node) -> void:
	var inv: Node = _make_inventory()
	var slots: Array = inv.get("slots") as Array
	slots[0] = {"id": "health_potion", "count": 5}
	slots[3] = {"id": "gold_coin",     "count": 42}

	var save_data: Array = inv.call("get_save_data") as Array

	var inv2: Node = _make_inventory()
	inv2.call("apply_save_data", save_data)
	var slots2: Array = inv2.get("slots") as Array

	runner.assert_true("Inv_Slot0_NotNull",  slots2[0] != null)
	runner.assert_eq("Inv_Slot0_ID",
		(slots2[0] as Dictionary).get("id"),         "health_potion")
	runner.assert_eq("Inv_Slot0_Count",
		int((slots2[0] as Dictionary).get("count", 0)), 5)
	runner.assert_eq("Inv_Slot3_ID",
		(slots2[3] as Dictionary).get("id"),         "gold_coin")
	runner.assert_eq("Inv_Slot3_Count",
		int((slots2[3] as Dictionary).get("count", 0)), 42)
	runner.assert_true("Inv_Slot1_Null", slots2[1] == null)


func _test_inventory_empty_slots(runner: Node) -> void:
	var inv: Node = _make_inventory()
	var save_data: Array = inv.call("get_save_data") as Array
	var inv2: Node = _make_inventory()
	inv2.call("apply_save_data", save_data)
	var slots2: Array = inv2.get("slots") as Array

	runner.assert_eq("Inv_Empty_SlotCount", slots2.size(), 30)
	runner.assert_true("Inv_Empty_AllNull", _all_null(slots2))


# ══════════════════════════════════════════════════════════════════════════════
#  SKILLS
# ══════════════════════════════════════════════════════════════════════════════

func _test_skill_persist(runner: Node) -> void:
	var skills: Node = _make_skills()
	var unlocked: Dictionary = skills.get("_unlocked_skills") as Dictionary
	unlocked["skill_1"] = 2
	unlocked["skill_3"] = 1

	var data: Dictionary = skills.call("get_save_data") as Dictionary
	var skills2: Node = _make_skills()
	skills2.call("apply_save_data", data)
	var unlocked2: Dictionary = skills2.get("_unlocked_skills") as Dictionary

	runner.assert_eq("Skill_Persist_Skill1_Level", int(unlocked2.get("skill_1", 0)), 2)
	runner.assert_eq("Skill_Persist_Skill3_Level", int(unlocked2.get("skill_3", 0)), 1)
	runner.assert_eq("Skill_Persist_Missing",      int(unlocked2.get("skill_99", 0)), 0)


func _test_skill_points_persist(runner: Node) -> void:
	var skills: Node = _make_skills()
	skills.set("skill_points", 3)

	var data: Dictionary = skills.call("get_save_data") as Dictionary
	var skills2: Node = _make_skills()
	skills2.call("apply_save_data", data)

	runner.assert_eq("Skill_Points_Persist", int(skills2.get("skill_points")), 3)


func _test_hotbar_persist(runner: Node) -> void:
	var skills: Node = _make_skills()
	var hotbar: Array = skills.get("_hotbar") as Array
	hotbar[0] = "fireball"
	hotbar[2] = "heal"

	var data: Dictionary = skills.call("get_save_data") as Dictionary
	var skills2: Node = _make_skills()
	skills2.call("apply_save_data", data)
	var hotbar2: Array = skills2.get("_hotbar") as Array

	runner.assert_eq("Hotbar_Slot0", hotbar2[0], "fireball")
	runner.assert_eq("Hotbar_Slot2", hotbar2[2], "heal")
	runner.assert_eq("Hotbar_Slot1", hotbar2[1], "")


# ══════════════════════════════════════════════════════════════════════════════
#  STATS
# ══════════════════════════════════════════════════════════════════════════════

func _test_stats_persist(runner: Node) -> void:
	var stats: Node = _make_stats()
	var st: Dictionary = stats.get("stats") as Dictionary
	st["strength"] = 3
	st["agility"]  = 2
	stats.set("stat_points", 1)

	var data: Dictionary = stats.call("get_save_data") as Dictionary
	var stats2: Node = _make_stats()
	stats2.call("apply_save_data", data)
	var st2: Dictionary = stats2.get("stats") as Dictionary

	runner.assert_eq("Stats_Strength", int(st2.get("strength", 0)), 3)
	runner.assert_eq("Stats_Agility",  int(st2.get("agility",  0)), 2)
	runner.assert_eq("Stats_Points",   int(stats2.get("stat_points")), 1)
	runner.assert_eq("Stats_Defense",  int(st2.get("defense",  0)), 1)


# ══════════════════════════════════════════════════════════════════════════════
#  QUESTS
# ══════════════════════════════════════════════════════════════════════════════

func _test_quest_persist_active(runner: Node) -> void:
	var quests: Node = _make_quests()
	quests.call("accept_quest", {"title_key": "QUEST_001", "rank": "F", "source": "board"})
	quests.call("accept_quest", {"title_key": "QUEST_002", "rank": "E", "source": "board"})

	var data: Dictionary = quests.call("get_save_data") as Dictionary
	var quests2: Node = _make_quests()
	quests2.call("apply_save_data", data)

	runner.assert_eq("Quest_Active_Count", int(quests2.call("get_active_count")), 2)
	runner.assert_true("Quest_Active_001", quests2.call("is_quest_active", "QUEST_001") as bool)
	runner.assert_true("Quest_Active_002", quests2.call("is_quest_active", "QUEST_002") as bool)
	runner.assert_true("Quest_Not_003",    not (quests2.call("is_quest_active", "QUEST_003") as bool))


func _test_quest_persist_completed(runner: Node) -> void:
	var quests: Node = _make_quests()
	quests.call("accept_quest",  {"title_key": "QUEST_DONE", "rank": "F", "source": "board"})
	quests.call("complete_quest", "QUEST_DONE")

	var data: Dictionary = quests.call("get_save_data") as Dictionary
	var quests2: Node = _make_quests()
	quests2.call("apply_save_data", data)

	var completed: Array[Dictionary] = quests2.call("get_completed_quests") as Array[Dictionary]
	runner.assert_eq("Quest_Completed_Count",   completed.size(), 1)
	runner.assert_true("Quest_Completed_DONE",  quests2.call("is_quest_completed", "QUEST_DONE") as bool)
	runner.assert_true("Quest_Not_Active_DONE", not (quests2.call("is_quest_active", "QUEST_DONE") as bool))


# ══════════════════════════════════════════════════════════════════════════════
#  GILDENRANG
# ══════════════════════════════════════════════════════════════════════════════

func _test_guild_rank_persist(runner: Node) -> void:
	var guild: Node = _make_guild()
	guild.set("_rank_index", 2)   # Rang D
	guild.set("_points",     7)

	var data: Dictionary = guild.call("get_save_data") as Dictionary
	var guild2: Node = _make_guild()
	guild2.call("apply_save_data", data)

	runner.assert_eq("Guild_RankIndex", int(guild2.get("_rank_index")),           2)
	runner.assert_eq("Guild_Rank",      guild2.call("get_rank") as String,        "D")
	runner.assert_eq("Guild_Points",    int(guild2.get("_points")),               7)


# ══════════════════════════════════════════════════════════════════════════════
#  HP / STAMINA
# ══════════════════════════════════════════════════════════════════════════════

func _test_hp_stamina_persist(runner: Node) -> void:
	SaveManager.set_world(TEST_WORLD)
	var data: Dictionary = SaveManager.get_player_data("__vital_test__")
	data["hp"]      = 75.0
	data["stamina"] = 50.0
	SaveManager.update_player_data("__vital_test__", data)

	var loaded: Dictionary = SaveManager.get_player_data("__vital_test__")
	runner.assert_eq("HP_Persist",      float(loaded.get("hp",      -1.0)), 75.0)
	runner.assert_eq("Stamina_Persist", float(loaded.get("stamina", -1.0)), 50.0)


# ══════════════════════════════════════════════════════════════════════════════
#  VOLLSTÄNDIGES MULTIPLAYER-SZENARIO
# ══════════════════════════════════════════════════════════════════════════════

func _test_full_multiplayer_scenario(runner: Node) -> void:
	SaveManager.set_world(TEST_WORLD)

	print("  → Schritt 1: Host_Gamer Welt erstellen")
	var host_initial: Dictionary = SaveManager.get_player_data(HOST_NAME)
	runner.assert_has_key("Scenario_Host_HasSkills",    host_initial, "skills")
	runner.assert_has_key("Scenario_Host_HasInventory", host_initial, "inventory")

	print("  → Schritt 2: Gast_1 tritt bei – Item und Skill erhalten")
	var guest_inv: Node    = _make_inventory()
	var guest_skills: Node = _make_skills()

	var g_slots: Array = guest_inv.get("slots") as Array
	g_slots[0] = {"id": "health_potion", "count": 3}
	g_slots[1] = {"id": "iron_sword",    "count": 1}

	var g_unlocked: Dictionary = guest_skills.get("_unlocked_skills") as Dictionary
	g_unlocked["skill_1"] = 1
	guest_skills.set("skill_points", 4)

	print("  → Schritt 3: Gast_1 trennt – Save wird geschrieben")
	var save_data: Dictionary = {}
	save_data.merge(guest_skills.call("get_save_data") as Dictionary)
	save_data["inventory"]   = guest_inv.call("get_save_data") as Array
	save_data["stats_data"]  = {"stats": {"strength":1,"agility":1,"defense":1,"endurance":1,"charisma":1}, "stat_points": 5}
	save_data["quests_data"] = {"active": [], "completed": []}
	save_data["guild_data"]  = {"rank_index": 0, "points": 0}
	save_data["hp"]          = 100.0
	save_data["stamina"]     = 100.0
	SaveManager.update_player_data(GUEST_NAME, save_data)

	runner.assert_true("Scenario_GuestFileSaved",
		SaveManager.player_file_exists(GUEST_NAME))

	print("  → Schritt 4: Gast_1 tritt erneut bei – Daten laden")
	var loaded: Dictionary = SaveManager.get_player_data(GUEST_NAME)

	print("  → Schritt 5: Verifikation")

	var inv_data: Array = loaded.get("inventory", []) as Array
	runner.assert_true("Scenario_GuestInv_HasItems", inv_data.size() > 0)

	if inv_data.size() > 0:
		var slot0: Dictionary = inv_data[0] as Dictionary
		runner.assert_eq("Scenario_GuestInv_Slot0_ID",    slot0.get("id"),           "health_potion")
		runner.assert_eq("Scenario_GuestInv_Slot0_Count", int(slot0.get("count", 0)), 3)
	if inv_data.size() > 1:
		var slot1: Dictionary = inv_data[1] as Dictionary
		runner.assert_eq("Scenario_GuestInv_Slot1_ID", slot1.get("id"), "iron_sword")

	var skills_saved: Dictionary = loaded.get("skills", {}) as Dictionary
	runner.assert_eq("Scenario_GuestSkill1_Level",
		int(skills_saved.get("skill_1", 0)), 1)
	runner.assert_eq("Scenario_GuestSkillPoints",
		int(loaded.get("points", -1)), 4)

	runner.assert_eq("Scenario_GuestHP",      float(loaded.get("hp",      -1.0)), 100.0)
	runner.assert_eq("Scenario_GuestStamina", float(loaded.get("stamina", -1.0)), 100.0)

	runner.assert_has_key("Scenario_Has_stats_data",  loaded, "stats_data")
	runner.assert_has_key("Scenario_Has_quests_data", loaded, "quests_data")
	runner.assert_has_key("Scenario_Has_guild_data",  loaded, "guild_data")

	print("  ✓ Szenario abgeschlossen.")


# ══════════════════════════════════════════════════════════════════════════════
#  HILFSMETHODEN
# ══════════════════════════════════════════════════════════════════════════════

func _make_inventory() -> Node:
	var inv: Node = preload("res://scripts/inventory/inventory_component.gd").new()
	add_child(inv)
	return inv


func _make_skills() -> Node:
	var s: Node = preload("res://scripts/player/skills_component.gd").new()
	add_child(s)
	return s


func _make_stats() -> Node:
	var s: Node = preload("res://scripts/player/stats_component.gd").new()
	add_child(s)
	return s


func _make_quests() -> Node:
	var q: Node = preload("res://scripts/world/quest_component.gd").new()
	add_child(q)
	return q


func _make_guild() -> Node:
	# GuildRankComponent._ready() ruft get_parent().get_node("Quests") auf.
	# Struktur: container → Quests (stub mit echtem Signal) + GuildRank
	var container: Node = Node.new()
	add_child(container)

	var stub: Node = preload("res://scripts/tests/quest_stub.gd").new()
	stub.name = "Quests"
	container.add_child(stub)

	var guild: Node = preload("res://scripts/world/guild_rank_component.gd").new()
	container.add_child(guild)
	return guild


func _all_null(arr: Array) -> bool:
	for item: Variant in arr:
		if item != null:
			return false
	return true


func _cleanup_test_world() -> void:
	var test_path: String = "user://saves/%s/" % TEST_WORLD
	if DirAccess.dir_exists_absolute(test_path):
		_delete_dir_recursive(test_path)
	print("  [Cleanup] Testwelt '%s' gelöscht." % TEST_WORLD)


func _delete_dir_recursive(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = path + entry
		if dir.current_is_dir():
			_delete_dir_recursive(full + "/")
			dir.remove(full)
		else:
			dir.remove(full)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
