extends Node

## Startet die Tests automatisch wenn diese Szene geöffnet wird.
## Verwendung: Szene "scenes/run_tests.tscn" direkt im Editor starten.

func _ready() -> void:
	# Einen Frame warten damit alle Autoloads bereit sind
	await get_tree().process_frame
	TestRunner.all_tests_done.connect(_on_done)
	TestRunner.run_all_tests()


func _on_done(passed: int, total: int) -> void:
	await get_tree().process_frame
	if passed == total:
		print("TEST_RESULT: ALL_PASSED %d/%d" % [passed, total])
	else:
		print("TEST_RESULT: FAILED %d/%d" % [passed, total])
	# Prozess läuft weiter damit get_debug_output die Logs lesen kann
