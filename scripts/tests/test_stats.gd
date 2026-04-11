extends Node

## Test-Suite: Stats-Komponente inkl. Stamina und abgeleitete Werte


func run(runner: Node) -> void:
	print("\n[Gruppe] Stats – Grundlagen")
	_test_spend_point(runner)
	_test_spend_point_no_points(runner)

	print("\n[Gruppe] Stats – Stamina")
	_test_stamina_stat_exists(runner)
	_test_max_stamina_scaling(runner)

	print("\n[Gruppe] Stats – Abgeleitete Werte")
	_test_derived_max_hp(runner)
	_test_derived_damage_multiplier(runner)
	_test_derived_damage_reduction(runner)

	print("\n[Gruppe] Stats – Save/Load")
	_test_stats_save_load(runner)


# ── Grundlagen ───────────────────────────────────────────────────────────────

func _test_spend_point(runner: Node) -> void:
	var stats: Node = _make_stats()
	stats.set("stat_points", 3)
	var ok: bool = stats.call("spend_point", "strength") as bool
	runner.assert_true("Stats_SpendPoint_OK", ok)
	runner.assert_eq("Stats_SpendPoint_Value", int((stats.get("stats") as Dictionary)["strength"]), 2)
	runner.assert_eq("Stats_SpendPoint_Remaining", int(stats.get("stat_points")), 2)
	stats.queue_free()


func _test_spend_point_no_points(runner: Node) -> void:
	var stats: Node = _make_stats()
	stats.set("stat_points", 0)
	var ok: bool = stats.call("spend_point", "strength") as bool
	runner.assert_true("Stats_NoPoints_Rejected", not ok)
	runner.assert_eq("Stats_NoPoints_Unchanged", int((stats.get("stats") as Dictionary)["strength"]), 1)
	stats.queue_free()


# ── Stamina ──────────────────────────────────────────────────────────────────

func _test_stamina_stat_exists(runner: Node) -> void:
	var stats: Node = _make_stats()
	var st: Dictionary = stats.get("stats") as Dictionary
	runner.assert_true("Stats_Stamina_Exists", st.has("stamina"))
	runner.assert_eq("Stats_Stamina_Default", int(st.get("stamina", 0)), 1)
	stats.queue_free()


func _test_max_stamina_scaling(runner: Node) -> void:
	var stats: Node = _make_stats()
	# Default stamina=1 → 100.0
	var max_stam: float = stats.call("get_max_stamina") as float
	runner.assert_eq("Stats_MaxStamina_Base", max_stam, 100.0)

	# Set stamina to 5 → 100 + 4*10 = 140
	(stats.get("stats") as Dictionary)["stamina"] = 5
	max_stam = stats.call("get_max_stamina") as float
	runner.assert_eq("Stats_MaxStamina_Lv5", max_stam, 140.0)
	stats.queue_free()


# ── Abgeleitete Werte ────────────────────────────────────────────────────────

func _test_derived_max_hp(runner: Node) -> void:
	var stats: Node = _make_stats()
	# endurance=1 → 100 HP
	runner.assert_eq("Stats_MaxHP_Base", int(stats.call("get_max_hp")), 100)
	# endurance=4 → 100 + 3*20 = 160
	(stats.get("stats") as Dictionary)["endurance"] = 4
	runner.assert_eq("Stats_MaxHP_Lv4", int(stats.call("get_max_hp")), 160)
	stats.queue_free()


func _test_derived_damage_multiplier(runner: Node) -> void:
	var stats: Node = _make_stats()
	# strength=1 → 1.0
	runner.assert_eq("Stats_DmgMult_Base", stats.call("get_damage_multiplier") as float, 1.0)
	# strength=3 → 1.0 + 2*0.10 = 1.2
	(stats.get("stats") as Dictionary)["strength"] = 3
	var mult: float = stats.call("get_damage_multiplier") as float
	runner.assert_true("Stats_DmgMult_Lv3", absf(mult - 1.2) < 0.001)
	stats.queue_free()


func _test_derived_damage_reduction(runner: Node) -> void:
	var stats: Node = _make_stats()
	# defense=1 → 0.0
	runner.assert_eq("Stats_DmgRed_Base", stats.call("get_damage_reduction") as float, 0.0)
	# defense=16 → min(15*0.05, 0.75) = 0.75 cap
	(stats.get("stats") as Dictionary)["defense"] = 16
	runner.assert_eq("Stats_DmgRed_Cap", stats.call("get_damage_reduction") as float, 0.75)
	stats.queue_free()


# ── Save/Load ────────────────────────────────────────────────────────────────

func _test_stats_save_load(runner: Node) -> void:
	var stats: Node = _make_stats()
	(stats.get("stats") as Dictionary)["strength"] = 5
	(stats.get("stats") as Dictionary)["stamina"] = 3
	stats.set("stat_points", 2)

	var data: Dictionary = stats.call("get_save_data") as Dictionary
	var stats2: Node = _make_stats()
	stats2.call("apply_save_data", data)

	var st2: Dictionary = stats2.get("stats") as Dictionary
	runner.assert_eq("StatsSL_Strength", int(st2.get("strength", 0)), 5)
	runner.assert_eq("StatsSL_Stamina", int(st2.get("stamina", 0)), 3)
	runner.assert_eq("StatsSL_Points", int(stats2.get("stat_points")), 2)
	# Unmodified stats should still be default
	runner.assert_eq("StatsSL_Defense_Default", int(st2.get("defense", 0)), 1)

	stats.queue_free()
	stats2.queue_free()


# ── Helpers ──────────────────────────────────────────────────────────────────

func _make_stats() -> Node:
	var s: Node = preload("res://scripts/player/stats_component.gd").new()
	add_child(s)
	return s
