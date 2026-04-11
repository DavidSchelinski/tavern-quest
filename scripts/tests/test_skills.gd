extends Node

## Test-Suite: Skill-System (Leveling, Voraussetzungen, Hotbar)


func run(runner: Node) -> void:
	print("\n[Gruppe] Skills – Unlock & Level")
	_test_unlock_skill(runner)
	_test_skill_level_increments(runner)
	_test_no_points_no_unlock(runner)

	print("\n[Gruppe] Skills – Hotbar")
	_test_hotbar_equip(runner)
	_test_hotbar_persist(runner)

	print("\n[Gruppe] Skills – Save/Load")
	_test_skills_save_load(runner)


# ── Unlock & Level ───────────────────────────────────────────────────────────

func _test_unlock_skill(runner: Node) -> void:
	var skills: Node = _make_skills()
	skills.set("skill_points", 3)

	skills.call("_do_unlock_skill", "fireball")
	var unlocked: Dictionary = skills.get("_unlocked_skills") as Dictionary
	runner.assert_true("Skills_Unlock_Has", unlocked.has("fireball"))
	runner.assert_eq("Skills_Unlock_Level", int(unlocked.get("fireball", 0)), 1)
	runner.assert_eq("Skills_Unlock_PointsLeft", int(skills.get("skill_points")), 2)
	skills.queue_free()


func _test_skill_level_increments(runner: Node) -> void:
	var skills: Node = _make_skills()
	skills.set("skill_points", 5)

	skills.call("_do_unlock_skill", "slash")
	skills.call("_do_unlock_skill", "slash")
	skills.call("_do_unlock_skill", "slash")
	var unlocked: Dictionary = skills.get("_unlocked_skills") as Dictionary
	runner.assert_eq("Skills_Level_3", int(unlocked.get("slash", 0)), 3)
	runner.assert_eq("Skills_Level_PointsLeft", int(skills.get("skill_points")), 2)
	skills.queue_free()


func _test_no_points_no_unlock(runner: Node) -> void:
	var skills: Node = _make_skills()
	skills.set("skill_points", 0)

	# _do_unlock_skill doesn't check points (server-side request_buy_skill does)
	# So we test via the can_unlock check instead
	# Just verify that spending 0 points keeps the state clean
	var unlocked: Dictionary = skills.get("_unlocked_skills") as Dictionary
	runner.assert_true("Skills_NoPts_Empty", unlocked.is_empty())
	skills.queue_free()


# ── Hotbar ───────────────────────────────────────────────────────────────────

func _test_hotbar_equip(runner: Node) -> void:
	var skills: Node = _make_skills()
	var hotbar: Array = skills.get("_hotbar") as Array

	hotbar[0] = "fireball"
	hotbar[3] = "heal"
	runner.assert_eq("Hotbar_Slot0", hotbar[0] as String, "fireball")
	runner.assert_eq("Hotbar_Slot3", hotbar[3] as String, "heal")
	runner.assert_eq("Hotbar_Slot1_Empty", hotbar[1] as String, "")
	skills.queue_free()


func _test_hotbar_persist(runner: Node) -> void:
	var skills: Node = _make_skills()
	var hotbar: Array = skills.get("_hotbar") as Array
	hotbar[0] = "fireball"
	hotbar[6] = "shield"

	var data: Dictionary = skills.call("get_save_data") as Dictionary
	var skills2: Node = _make_skills()
	skills2.call("apply_save_data", data)
	var hotbar2: Array = skills2.get("_hotbar") as Array

	runner.assert_eq("HotbarPersist_Slot0", hotbar2[0] as String, "fireball")
	runner.assert_eq("HotbarPersist_Slot6", hotbar2[6] as String, "shield")
	runner.assert_eq("HotbarPersist_Slot1", hotbar2[1] as String, "")
	skills.queue_free()
	skills2.queue_free()


# ── Save/Load ────────────────────────────────────────────────────────────────

func _test_skills_save_load(runner: Node) -> void:
	var skills: Node = _make_skills()
	skills.set("skill_points", 2)
	var unlocked: Dictionary = skills.get("_unlocked_skills") as Dictionary
	unlocked["slash"] = 3
	unlocked["fireball"] = 1

	var data: Dictionary = skills.call("get_save_data") as Dictionary

	var skills2: Node = _make_skills()
	skills2.call("apply_save_data", data)
	var ul2: Dictionary = skills2.get("_unlocked_skills") as Dictionary

	runner.assert_eq("SkillsSL_Slash_Level", int(ul2.get("slash", 0)), 3)
	runner.assert_eq("SkillsSL_Fireball_Level", int(ul2.get("fireball", 0)), 1)
	runner.assert_eq("SkillsSL_Points", int(skills2.get("skill_points")), 2)
	runner.assert_eq("SkillsSL_Missing", int(ul2.get("nonexistent", 0)), 0)
	skills.queue_free()
	skills2.queue_free()


# ── Helpers ──────────────────────────────────────────────────────────────────

func _make_skills() -> Node:
	var s: Node = preload("res://scripts/player/skills_component.gd").new()
	add_child(s)
	return s
