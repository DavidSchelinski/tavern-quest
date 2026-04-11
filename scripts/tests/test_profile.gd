extends Node

## Test-Suite: Spieler-Profil (Passwort, Verifikation, Löschung)

const TEST_PROFILE := "__test_profile__"
const TEST_PW_PROFILE := "__test_pw_profile__"


func run(runner: Node) -> void:
	print("\n[Gruppe] Profil – Basis")
	_test_name_validation(runner)
	_test_name_sanitization(runner)

	print("\n[Gruppe] Profil – Passwort")
	_test_login_without_password(runner)
	_test_login_with_password(runner)
	_test_wrong_password_rejected(runner)
	_test_has_password(runner)

	print("\n[Gruppe] Profil – Verifikationscode")
	_test_verification_code_generated(runner)
	_test_verification_code_deterministic(runner)

	print("\n[Gruppe] Profil – Löschung")
	_test_delete_profile(runner)

	_cleanup()


# ── Name-Validierung ─────────────────────────────────────────────────────────

func _test_name_validation(runner: Node) -> void:
	runner.assert_neq("Name_Empty_Error", PlayerProfile.validate_name(""), "")
	runner.assert_neq("Name_TooShort_Error", PlayerProfile.validate_name("ab"), "")
	runner.assert_eq("Name_Valid_NoError", PlayerProfile.validate_name("Hero_123"), "")
	runner.assert_neq("Name_SpecialChars_Error", PlayerProfile.validate_name("   "), "")


func _test_name_sanitization(runner: Node) -> void:
	runner.assert_eq("Sanitize_Clean", PlayerProfile.sanitize_name("Hero_123"), "Hero_123")
	runner.assert_eq("Sanitize_Specials", PlayerProfile.sanitize_name("He!ro@#$"), "Hero")
	runner.assert_eq("Sanitize_Dash", PlayerProfile.sanitize_name("My-Name"), "My-Name")


# ── Passwort ─────────────────────────────────────────────────────────────────

func _test_login_without_password(runner: Node) -> void:
	var ok: bool = PlayerProfile.login(TEST_PROFILE, "")
	runner.assert_true("Login_NoPW_OK", ok)
	runner.assert_true("Login_NoPW_Exists", PlayerProfile.profile_exists(TEST_PROFILE))


func _test_login_with_password(runner: Node) -> void:
	var ok: bool = PlayerProfile.login(TEST_PW_PROFILE, "geheim123")
	runner.assert_true("Login_WithPW_OK", ok)
	# Verify the password was stored
	runner.assert_true("Login_WithPW_HasPW", PlayerProfile.has_password(TEST_PW_PROFILE))


func _test_wrong_password_rejected(runner: Node) -> void:
	# Try to login with wrong password to a profile that has one
	var ok: bool = PlayerProfile.login(TEST_PW_PROFILE, "falsch")
	runner.assert_true("Login_WrongPW_Rejected", not ok)


func _test_has_password(runner: Node) -> void:
	runner.assert_true("HasPW_Protected", PlayerProfile.has_password(TEST_PW_PROFILE))
	runner.assert_true("HasPW_Unprotected", not PlayerProfile.has_password(TEST_PROFILE))


# ── Verifikationscode ────────────────────────────────────────────────────────

func _test_verification_code_generated(runner: Node) -> void:
	PlayerProfile.login(TEST_PROFILE, "")
	var code: String = PlayerProfile.get_verification_code()
	runner.assert_true("VerCode_NotEmpty", not code.is_empty())
	runner.assert_eq("VerCode_Length", code.length(), 16)


func _test_verification_code_deterministic(runner: Node) -> void:
	PlayerProfile.login(TEST_PROFILE, "test_pw")
	var code1: String = PlayerProfile.get_verification_code()
	PlayerProfile.login(TEST_PROFILE, "test_pw")
	var code2: String = PlayerProfile.get_verification_code()
	runner.assert_eq("VerCode_Deterministic", code1, code2)

	# Different password → different code
	PlayerProfile.login(TEST_PROFILE, "other_pw")
	var code3: String = PlayerProfile.get_verification_code()
	runner.assert_neq("VerCode_DifferentPW", code1, code3)


# ── Löschung ─────────────────────────────────────────────────────────────────

func _test_delete_profile(runner: Node) -> void:
	PlayerProfile.login("__delete_me__", "")
	runner.assert_true("Delete_Exists_Before", PlayerProfile.profile_exists("__delete_me__"))
	var ok: bool = PlayerProfile.delete_profile("__delete_me__")
	runner.assert_true("Delete_Success", ok)
	runner.assert_true("Delete_Gone", not PlayerProfile.profile_exists("__delete_me__"))


# ── Cleanup ──────────────────────────────────────────────────────────────────

func _cleanup() -> void:
	PlayerProfile.delete_profile(TEST_PROFILE)
	PlayerProfile.delete_profile(TEST_PW_PROFILE)
