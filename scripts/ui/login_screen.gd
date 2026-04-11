extends Control

## Login-Screen: Spieler gibt Namen und optional Passwort ein.
## Emittiert login_confirmed(player_name) wenn der Spieler bestätigt hat.

signal login_confirmed(player_name: String)

@onready var _name_input     : LineEdit = $Center/Panel/Margin/VBox/NameInput
@onready var _password_input : LineEdit = $Center/Panel/Margin/VBox/PasswordInput
@onready var _confirm_btn    : Button   = $Center/Panel/Margin/VBox/ButtonRow/ConfirmButton
@onready var _delete_btn     : Button   = $Center/Panel/Margin/VBox/ButtonRow/DeleteButton
@onready var _profile_list   : ItemList = $Center/Panel/Margin/VBox/ProfileList
@onready var _error_label    : Label    = $Center/Panel/Margin/VBox/ErrorLabel
@onready var _list_label     : Label    = $Center/Panel/Margin/VBox/ProfilesLabel

var _delete_confirm_panel : Panel = null


func _ready() -> void:
	_confirm_btn.pressed.connect(_on_confirm)
	_delete_btn.pressed.connect(_on_delete_pressed)
	_name_input.text_submitted.connect(func(_t: String) -> void: _on_confirm())
	_password_input.text_submitted.connect(func(_t: String) -> void: _on_confirm())
	_profile_list.item_selected.connect(_on_profile_selected)
	_profile_list.item_activated.connect(func(_i: int) -> void: _on_confirm())
	_refresh_profiles()

	if PlayerProfile.is_logged_in():
		_name_input.text = PlayerProfile.current_player_name

	_name_input.grab_focus()
	_delete_btn.visible = false


func _refresh_profiles() -> void:
	_profile_list.clear()
	var profiles := PlayerProfile.list_profiles()
	if profiles.is_empty():
		_list_label.text = "Noch keine Profile vorhanden – einfach Namen eingeben!"
		_list_label.modulate = Color(0.6, 0.6, 0.6)
	else:
		_list_label.text = "Vorhandene Profile (klicken zum Auswählen):"
		_list_label.modulate = Color(0.75, 0.75, 0.75)
		for name_str: String in profiles:
			var meta := PlayerProfile.get_profile_meta(name_str)
			var last_login := _fmt_date(meta.get("last_login", 0.0) as float)
			var has_pw := " 🔒" if meta.get("password_hash", "") != "" else ""
			_profile_list.add_item("%s%s   (zuletzt: %s)" % [name_str, has_pw, last_login])
			_profile_list.set_item_metadata(_profile_list.item_count - 1, name_str)


func _on_profile_selected(idx: int) -> void:
	var profile_name: String = _profile_list.get_item_metadata(idx) as String
	_name_input.text = profile_name
	_password_input.text = ""
	_error_label.text = ""
	_delete_btn.visible = true

	# Show password hint if profile has password
	if PlayerProfile.has_password(profile_name):
		_password_input.placeholder_text = "Passwort erforderlich..."
	else:
		_password_input.placeholder_text = "Passwort (optional)..."


func _on_confirm() -> void:
	var raw := _name_input.text.strip_edges()
	var password := _password_input.text
	var clean := PlayerProfile.sanitize_name(raw)
	var error := PlayerProfile.validate_name(raw)

	if not error.is_empty():
		_error_label.text = error
		return

	# Try to log in (handles password verification internally)
	var success := PlayerProfile.login(clean, password)
	if not success:
		_error_label.text = "Falsches Passwort!"
		return

	_error_label.text = ""
	login_confirmed.emit(clean)


func _on_delete_pressed() -> void:
	var raw := _name_input.text.strip_edges()
	var clean := PlayerProfile.sanitize_name(raw)
	if clean.is_empty() or not PlayerProfile.profile_exists(clean):
		_error_label.text = "Kein Profil zum Löschen ausgewählt."
		return

	# Show confirmation dialog
	_close_delete_confirm()
	_delete_confirm_panel = Panel.new()
	_delete_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := UITheme.make_panel_style(UITheme.BG_DARK, UITheme.CANCEL_COLOR)
	_delete_confirm_panel.add_theme_stylebox_override("panel", style)
	add_child(_delete_confirm_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(16, 12)
	vbox.add_theme_constant_override("separation", 8)
	_delete_confirm_panel.add_child(vbox)

	var msg := Label.new()
	msg.text = "Profil '%s' wirklich löschen?" % clean
	msg.add_theme_font_size_override("font_size", 14)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(msg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	var yes_btn := Button.new()
	yes_btn.text = "Ja, löschen"
	yes_btn.custom_minimum_size = Vector2(120, 36)
	yes_btn.pressed.connect(func() -> void:
		PlayerProfile.delete_profile(clean)
		_close_delete_confirm()
		_name_input.text = ""
		_password_input.text = ""
		_delete_btn.visible = false
		_refresh_profiles()
	)
	row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "Abbrechen"
	no_btn.custom_minimum_size = Vector2(120, 36)
	no_btn.pressed.connect(_close_delete_confirm)
	row.add_child(no_btn)

	_delete_confirm_panel.size = Vector2(320, 100)
	var vp := get_viewport().get_visible_rect().size
	_delete_confirm_panel.position = Vector2(
		(vp.x - 320) / 2.0, (vp.y - 100) / 2.0
	)


func _close_delete_confirm() -> void:
	if _delete_confirm_panel != null:
		_delete_confirm_panel.queue_free()
		_delete_confirm_panel = null


func _fmt_date(unix: float) -> String:
	if unix <= 0.0:
		return "nie"
	var dt := Time.get_datetime_dict_from_unix_time(int(unix))
	return "%02d.%02d.%d" % [int(dt["day"]), int(dt["month"]), int(dt["year"])]
