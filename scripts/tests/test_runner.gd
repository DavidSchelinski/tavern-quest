extends Node

## Zentrales Test-Framework für Tavern Quest.
##
## Alle Tests können über das Hauptmenü (Dev-Taste) oder per Kommandozeile
## mit dem Argument "--run-tests" ausgelöst werden.
##
## Ausgabe:
##   [PASS] TEST_NAME
##   [FAIL] TEST_NAME – Grund
##   ─────────────────────────────
##   Ergebnis: X/Y Tests bestanden.

signal all_tests_done(passed: int, total: int)

var _results : Array[Dictionary] = []   # [{name, passed, message}]
var _running  : bool = false


func _ready() -> void:
	if "--run-tests" in OS.get_cmdline_args():
		call_deferred("run_all_tests")


# ── Öffentliche API ───────────────────────────────────────────────────────────

func run_all_tests() -> void:
	if _running:
		push_warning("TestRunner: Tests laufen bereits.")
		return
	_running = true
	_results.clear()

	print("\n╔══════════════════════════════════════════════════╗")
	print("║           TAVERN QUEST – TEST SUITE             ║")
	print("╚══════════════════════════════════════════════════╝\n")

	# Alle Tests importieren und ausführen
	var suite := preload("res://scripts/tests/test_save_load.gd").new()
	suite.name = "TestSaveLoad"
	add_child(suite)
	suite.run(self)
	suite.queue_free()

	_print_summary()
	_running = false
	all_tests_done.emit(_count_passed(), _results.size())


# ── Test-Registrierung (wird von Test-Klassen aufgerufen) ─────────────────────

func record(test_name: String, passed: bool, message: String = "") -> void:
	_results.append({"name": test_name, "passed": passed, "message": message})
	var prefix := "[PASS]" if passed else "[FAIL]"
	var suffix := "" if message.is_empty() else " – %s" % message
	print("  %s %s%s" % [prefix, test_name, suffix])


func assert_true(test_name: String, condition: bool, fail_msg: String = "") -> bool:
	record(test_name, condition, "" if condition else fail_msg)
	return condition


func assert_eq(test_name: String, actual: Variant, expected: Variant) -> bool:
	var ok: bool = actual == expected
	record(test_name, ok, "" if ok else "Erwartet: %s | Erhalten: %s" % [str(expected), str(actual)])
	return ok


func assert_neq(test_name: String, actual: Variant, not_expected: Variant) -> bool:
	var ok: bool = actual != not_expected
	record(test_name, ok, "" if ok else "Sollte nicht sein: %s" % str(not_expected))
	return ok


func assert_has_key(test_name: String, dict: Dictionary, key: String) -> bool:
	var ok: bool = dict.has(key)
	record(test_name, ok, "" if ok else "Schlüssel '%s' fehlt im Dictionary" % key)
	return ok


# ── Intern ────────────────────────────────────────────────────────────────────

func _count_passed() -> int:
	var n := 0
	for r: Dictionary in _results:
		if r["passed"] as bool:
			n += 1
	return n


func _print_summary() -> void:
	var passed := _count_passed()
	var total  := _results.size()
	print("\n──────────────────────────────────────────────────")
	if passed == total:
		print("  ALLE TESTS BESTANDEN: %d/%d  ✓" % [passed, total])
	else:
		print("  Ergebnis: %d/%d bestanden  ✗" % [passed, total])
		print("\n  Fehlgeschlagene Tests:")
		for r: Dictionary in _results:
			if not r["passed"] as bool:
				print("    • %s  (%s)" % [r["name"], r["message"]])
	print("──────────────────────────────────────────────────\n")
