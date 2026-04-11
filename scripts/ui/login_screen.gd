extends Control

## Login-Screen: Spieler gibt seinen Namen ein oder wählt ein vorhandenes Profil.
## Emittiert login_confirmed(player_name) wenn der Spieler bestätigt hat.
##
## Alle Labels, Buttons und Felder sind als Nodes in der Szene definiert
## und können im Editor bearbeitet werden.

signal login_confirmed(player_name: String)

# ── Node-Referenzen (per @onready aus der Szene) ──────────────────────────────
@onready var _name_input    : LineEdit  = $Center/Panel/Margin/VBox/NameInput
@onready var _confirm_btn   : Button    = $Center/Panel/Margin/VBox/ConfirmButton
@onready var _profile_list  : ItemList  = $Center/Panel/Margin/VBox/ProfileList
@onready var _error_label   : Label     = $Center/Panel/Margin/VBox/ErrorLabel
@onready var _list_label    : Label     = $Center/Panel/Margin/VBox/ProfilesLabel


func _ready() -> void:
	_confirm_btn.pressed.connect(_on_confirm)
	_name_input.text_submitted.connect(func(_t: String) -> void: _on_confirm())
	_profile_list.item_selected.connect(_on_profile_selected)
	_profile_list.item_activated.connect(func(_i: int) -> void: _on_confirm())
	_refresh_profiles()

	# Falls bereits eingeloggt (z.B. nach Weltauswahl zurückgekehrt)
	if PlayerProfile.is_logged_in():
		_name_input.text = PlayerProfile.current_player_name

	_name_input.grab_focus()


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
			_profile_list.add_item("%s   (zuletzt: %s)" % [name_str, last_login])
			_profile_list.set_item_metadata(_profile_list.item_count - 1, name_str)


func _on_profile_selected(idx: int) -> void:
	var profile_name: String = _profile_list.get_item_metadata(idx) as String
	_name_input.text = profile_name
	_error_label.text = ""


func _on_confirm() -> void:
	var raw := _name_input.text.strip_edges()
	var clean := PlayerProfile.sanitize_name(raw)
	var error := PlayerProfile.validate_name(raw)

	if not error.is_empty():
		_error_label.text = error
		return

	_error_label.text = ""
	PlayerProfile.login(clean)
	login_confirmed.emit(clean)


func _fmt_date(unix: float) -> String:
	if unix <= 0.0:
		return "nie"
	var dt := Time.get_datetime_dict_from_unix_time(int(unix))
	return "%02d.%02d.%d" % [int(dt["day"]), int(dt["month"]), int(dt["year"])]
