extends Control

## Hauptmenü-Controller.
## Alle visuellen Nodes sind in der Szene (scenes/main_menu.tscn) definiert
## und können im Godot-Editor bearbeitet werden – ohne in diesen Code zu schauen.
##
## Flow: LoginScreen → MenuRoot (Buttons) → WorldSelectionMenu → Spiel

const SETTINGS_PATH := "user://settings.cfg"
const GAME_SCENE    := "res://scenes/main.tscn"
const DEFAULT_PORT  := 7777

const ACTIONS : Dictionary = {
	"move_forward" : "ACTION_FORWARD",
	"move_back"    : "ACTION_BACK",
	"move_left"    : "ACTION_LEFT",
	"move_right"   : "ACTION_RIGHT",
	"jump"         : "ACTION_JUMP",
	"sprint"       : "ACTION_SPRINT",
	"interact"     : "ACTION_INTERACT",
	"pickup"       : "ACTION_PICKUP",
}

const LOCALES := [
	{ "code": "de", "key": "LANG_DE" },
	{ "code": "en", "key": "LANG_EN" },
]

# ── Node-Refs ─────────────────────────────────────────────────────────────────

# Login-Screen (Unter-Szene)
@onready var _login_screen : Control = $LoginScreen

# Haupt-Menü
@onready var _menu_root         : Control = $MenuRoot
@onready var _player_name_label : Label   = $MenuRoot/Center/Column/PlayerNameLabel
@onready var _fps_label         : Label   = $MenuRoot/FPSLabel
@onready var _solo_btn          : Button  = $MenuRoot/Center/Column/SoloButton
@onready var _host_btn          : Button  = $MenuRoot/Center/Column/HostButton
@onready var _join_btn_main     : Button  = $MenuRoot/Center/Column/JoinButton
@onready var _settings_btn      : Button  = $MenuRoot/Center/Column/SettingsButton
@onready var _change_player_btn : Button  = $MenuRoot/Center/Column/ChangePlayerButton
@onready var _run_tests_btn     : Button  = $MenuRoot/Center/Column/RunTestsButton
@onready var _quit_btn          : Button  = $MenuRoot/Center/Column/QuitButton

# Einstellungen-Overlay
@onready var _settings_overlay   : Control      = $MenuRoot/SettingsOverlay
@onready var _master_slider      : HSlider      = $MenuRoot/SettingsOverlay/Center/Panel/Margin/VBox/Tabs/Audio/Pad/Inner/MasterRow/MasterSlider
@onready var _master_value_label : Label        = $MenuRoot/SettingsOverlay/Center/Panel/Margin/VBox/Tabs/Audio/Pad/Inner/MasterRow/MasterValue
@onready var _fps_check          : CheckButton  = $MenuRoot/SettingsOverlay/Center/Panel/Margin/VBox/Tabs/Display/Pad/Inner/FPSRow/FPSCheck
@onready var _fullscreen_check   : CheckButton  = $MenuRoot/SettingsOverlay/Center/Panel/Margin/VBox/Tabs/Display/Pad/Inner/FullscreenRow/FullscreenCheck
@onready var _controls_inner     : VBoxContainer = $MenuRoot/SettingsOverlay/Center/Panel/Margin/VBox/Tabs/Controls/ControlsInner
@onready var _lang_options       : OptionButton = $MenuRoot/SettingsOverlay/Center/Panel/Margin/VBox/Tabs/Language/Pad/Inner/LangRow/LangOptions
@onready var _close_settings_btn : Button       = $MenuRoot/SettingsOverlay/Center/Panel/Margin/VBox/CloseSettingsButton
@onready var _settings_tabs      : TabContainer = $MenuRoot/SettingsOverlay/Center/Panel/Margin/VBox/Tabs

# Host-Overlay
@onready var _host_overlay    : Control  = $MenuRoot/HostOverlay
@onready var _host_local_ip   : Label    = $MenuRoot/HostOverlay/Center/Panel/Margin/VBox/LocalIPRow/LocalIPValue
@onready var _host_public_ip  : Label    = $MenuRoot/HostOverlay/Center/Panel/Margin/VBox/PublicIPRow/PublicIPValue
@onready var _host_port_input : LineEdit = $MenuRoot/HostOverlay/Center/Panel/Margin/VBox/PortRow/PortInput
@onready var _host_cancel_btn : Button   = $MenuRoot/HostOverlay/Center/Panel/Margin/VBox/HostButtons/HostCancelButton
@onready var _host_start_btn  : Button   = $MenuRoot/HostOverlay/Center/Panel/Margin/VBox/HostButtons/HostStartButton

# Join-Overlay
@onready var _join_overlay    : Control  = $MenuRoot/JoinOverlay
@onready var _join_server_list : ItemList = $MenuRoot/JoinOverlay/Center/Panel/Margin/VBox/ServerList
@onready var _join_ip_input   : LineEdit = $MenuRoot/JoinOverlay/Center/Panel/Margin/VBox/IPRow/IPInput
@onready var _join_port_input : LineEdit = $MenuRoot/JoinOverlay/Center/Panel/Margin/VBox/JoinPortRow/JoinPortInput
@onready var _join_status     : Label    = $MenuRoot/JoinOverlay/Center/Panel/Margin/VBox/JoinStatusLabel
@onready var _join_cancel_btn : Button   = $MenuRoot/JoinOverlay/Center/Panel/Margin/VBox/JoinButtons/JoinCancelButton
@onready var _join_connect_btn : Button  = $MenuRoot/JoinOverlay/Center/Panel/Margin/VBox/JoinButtons/JoinConnectButton

# Welt-Auswahl (programmatisch – bleibt als eigene Klasse)
var _world_menu    : WorldSelectionMenu
var _pending_mode  : String = ""

# ── Config-State ──────────────────────────────────────────────────────────────

var _cfg              := ConfigFile.new()
var _rebind_action    : String = ""
var _rebind_btn       : Button = null
var _control_btns     : Dictionary = {}
var _discovered       : Dictionary = {}
var _http             : HTTPRequest


func _ready() -> void:
	_cfg.load(SETTINGS_PATH)

	# HTTP für öffentliche IP
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_public_ip_received)

	# NetworkManager-Signale
	NetworkManager.player_connected.connect(_on_net_player_connected)
	NetworkManager.connection_failed.connect(_on_net_connection_failed)
	NetworkManager.server_found.connect(_on_server_found)

	# Welt-Auswahl
	_world_menu = WorldSelectionMenu.new()
	add_child(_world_menu)
	_world_menu.world_confirmed.connect(_on_world_confirmed)

	# Login-Screen
	_login_screen.login_confirmed.connect(_on_login_confirmed)

	# Hauptmenü-Buttons
	_solo_btn.pressed.connect(func() -> void:
		_pending_mode = "solo"
		_world_menu.show_menu()
	)
	_host_btn.pressed.connect(func() -> void:
		_pending_mode = "host"
		_world_menu.show_menu()
	)
	_join_btn_main.pressed.connect(_open_join)
	_settings_btn.pressed.connect(func() -> void:
		_settings_overlay.visible = true
	)
	_change_player_btn.pressed.connect(func() -> void:
		_menu_root.visible = false
		_login_screen.visible = true
	)
	_run_tests_btn.pressed.connect(func() -> void:
		TestRunner.run_all_tests()
	)
	_quit_btn.pressed.connect(func() -> void:
		get_tree().quit()
	)

	# Einstellungen
	_close_settings_btn.pressed.connect(func() -> void:
		_settings_overlay.visible = false
	)
	_master_slider.value_changed.connect(_on_master_changed)
	_fps_check.toggled.connect(_on_fps_toggled)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_build_controls_list()
	_build_language_tab()

	# Host
	_host_cancel_btn.pressed.connect(func() -> void: _host_overlay.visible = false)
	_host_start_btn.pressed.connect(_on_host_start)

	# Join
	_join_cancel_btn.pressed.connect(_close_join)
	_join_connect_btn.pressed.connect(_on_join_connect)
	_join_server_list.item_selected.connect(_on_server_selected)

	# Tabs benennen (Übersetzungen)
	_settings_tabs.set_tab_title(0, tr("TAB_AUDIO"))
	_settings_tabs.set_tab_title(1, tr("TAB_DISPLAY"))
	_settings_tabs.set_tab_title(2, tr("TAB_CONTROLS"))
	_settings_tabs.set_tab_title(3, tr("TAB_LANGUAGE"))

	_apply_settings()

	# Flow: Direkt zum Hauptmenü wenn bereits eingeloggt
	if PlayerProfile.is_logged_in():
		_show_main_menu()
	else:
		_login_screen.visible = true
		_menu_root.visible    = false


func _process(_delta: float) -> void:
	if _fps_label and _fps_label.visible:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _input(event: InputEvent) -> void:
	if _rebind_action.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		get_viewport().set_input_as_handled()
		_finish_rebind(event)


# ── Login-Flow ────────────────────────────────────────────────────────────────

func _on_login_confirmed(_player_name: String) -> void:
	_show_main_menu()


func _show_main_menu() -> void:
	_login_screen.visible = false
	_menu_root.visible    = true
	# Spieler-Willkommenstext aktualisieren
	if PlayerProfile.is_logged_in():
		_player_name_label.text = "Willkommen, %s!" % PlayerProfile.current_player_name
	else:
		_player_name_label.text = ""


# ── Welt-Auswahl ──────────────────────────────────────────────────────────────

func _on_world_confirmed(world_name: String) -> void:
	SaveManager.set_world(world_name)
	match _pending_mode:
		"solo":
			get_tree().change_scene_to_file(GAME_SCENE)
		"host":
			_host_local_ip.text  = NetworkManager.get_local_ip()
			_host_public_ip.text = "Wird geladen…"
			_host_overlay.visible = true
			_http.request("https://api.ipify.org")
	_pending_mode = ""


# ── Einstellungen ─────────────────────────────────────────────────────────────

func _apply_settings() -> void:
	var master_pct : float = _cfg.get_value("audio", "master_pct", 100.0)
	_master_slider.value = master_pct
	_master_value_label.text = "%d" % int(master_pct)
	_set_master_volume(master_pct)

	var show_fps  : bool = _cfg.get_value("display", "show_fps", false)
	var fullscreen : bool = _cfg.get_value("display", "fullscreen", false)
	_fps_check.set_pressed_no_signal(show_fps)
	_fps_label.visible = show_fps
	_fullscreen_check.set_pressed_no_signal(fullscreen)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	for action: String in ACTIONS:
		var code : int = _cfg.get_value("controls", action, -1)
		if code != -1:
			_apply_keybind(action, code)


func _on_master_changed(val: float) -> void:
	_set_master_volume(val)
	_master_value_label.text = "%d" % int(val)
	_cfg.set_value("audio", "master_pct", val)
	_cfg.save(SETTINGS_PATH)


func _on_fps_toggled(on: bool) -> void:
	_fps_label.visible = on
	_cfg.set_value("display", "show_fps", on)
	_cfg.save(SETTINGS_PATH)


func _on_fullscreen_toggled(on: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	)
	_cfg.set_value("display", "fullscreen", on)
	_cfg.save(SETTINGS_PATH)


func _set_master_volume(pct: float) -> void:
	var db := linear_to_db(pct / 100.0) if pct > 0.0 else -80.0
	AudioServer.set_bus_volume_db(0, db)


# ── Steuerung (Controls-Tab) ──────────────────────────────────────────────────

func _build_controls_list() -> void:
	for child in _controls_inner.get_children():
		child.queue_free()

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_top",   16)
	pad.add_theme_constant_override("margin_left",  12)
	pad.add_theme_constant_override("margin_right", 12)
	_controls_inner.add_child(pad)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	pad.add_child(inner)

	for action: String in ACTIONS:
		var row := HBoxContainer.new()
		inner.add_child(row)

		var lbl := Label.new()
		lbl.text = tr(ACTIONS[action])
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 0)
		btn.text = _action_key_string(action)
		btn.pressed.connect(_start_rebind.bind(action, btn))
		row.add_child(btn)
		_control_btns[action] = btn


func _build_language_tab() -> void:
	_lang_options.clear()
	var current_locale := LocaleManager.get_locale()
	for i: int in range(LOCALES.size()):
		_lang_options.add_item(tr(LOCALES[i]["key"]), i)
		if LOCALES[i]["code"] == current_locale:
			_lang_options.selected = i
	_lang_options.item_selected.connect(func(idx: int) -> void:
		LocaleManager.set_locale(LOCALES[idx]["code"])
	)


# ── Key-Rebinding ─────────────────────────────────────────────────────────────

func _start_rebind(action: String, btn: Button) -> void:
	if not _rebind_action.is_empty():
		return
	_rebind_action = action
	_rebind_btn    = btn
	btn.text       = tr("REBIND_PRESS")


func _finish_rebind(event: InputEventKey) -> void:
	var action := _rebind_action
	var btn    := _rebind_btn
	_rebind_action = ""
	_rebind_btn    = null

	if event.physical_keycode == KEY_ESCAPE:
		btn.text = _action_key_string(action)
		return

	_apply_keybind(action, event.physical_keycode)
	_cfg.set_value("controls", action, event.physical_keycode)
	_cfg.save(SETTINGS_PATH)
	btn.text = _action_key_string(action)


func _apply_keybind(action: String, physical_keycode: int) -> void:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode as Key
	InputMap.action_add_event(action, ev)


func _action_key_string(action: String) -> String:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return "—"


# ── Host ──────────────────────────────────────────────────────────────────────

func _on_host_start() -> void:
	var port := int(_host_port_input.text) if _host_port_input.text.is_valid_int() else DEFAULT_PORT
	var err   := NetworkManager.host(port)
	if err != OK:
		_host_public_ip.text = tr("HOST_PORT_ERROR")
		return
	_host_overlay.visible = false
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_public_ip_received(_result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _host_public_ip:
		_host_public_ip.text = body.get_string_from_utf8().strip_edges()


# ── Join ──────────────────────────────────────────────────────────────────────

func _open_join() -> void:
	_join_overlay.visible = true
	_join_status.text     = ""
	_join_connect_btn.disabled = false
	_join_connect_btn.text = tr("BTN_CONNECT")
	_discovered.clear()
	_join_server_list.clear()
	NetworkManager.start_discovery()


func _close_join() -> void:
	NetworkManager.close()
	NetworkManager.stop_discovery()
	_join_overlay.visible = false
	_join_status.text     = ""
	_join_connect_btn.disabled = false
	_join_connect_btn.text = tr("BTN_CONNECT")


func _on_join_connect() -> void:
	var ip   := _join_ip_input.text.strip_edges()
	var port := int(_join_port_input.text) if _join_port_input.text.is_valid_int() else DEFAULT_PORT
	if ip.is_empty():
		_join_status.text = tr("JOIN_ENTER_IP")
		return
	_join_connect_btn.disabled = true
	_join_connect_btn.text     = tr("BTN_CONNECTING")
	_join_status.text          = ""
	NetworkManager.stop_discovery()
	NetworkManager.join(ip, port)


func _on_server_found(_ip: String, info: Dictionary) -> void:
	var key  := "%s:%d" % [info.get("ip", ""), int(info.get("port", 0))]
	var text := "%s  (%s)  –  %d/%d" % [
		info.get("name", "?"),
		info.get("ip", "?"),
		int(info.get("players", 0)),
		int(info.get("max_players", 0)),
	]
	if _discovered.has(key):
		var idx : int = _discovered[key] as int
		if idx < _join_server_list.item_count:
			_join_server_list.set_item_text(idx, text)
	else:
		var idx := _join_server_list.add_item(text)
		_join_server_list.set_item_metadata(idx, info)
		_discovered[key] = idx


func _on_server_selected(idx: int) -> void:
	var info : Dictionary = _join_server_list.get_item_metadata(idx)
	_join_ip_input.text   = str(info.get("ip", ""))
	_join_port_input.text = str(int(info.get("port", DEFAULT_PORT)))


func _on_net_player_connected(_id: int) -> void:
	if _join_overlay and _join_overlay.visible:
		NetworkManager.stop_discovery()
		_join_overlay.visible = false
		get_tree().change_scene_to_file(GAME_SCENE)


func _on_net_connection_failed() -> void:
	_join_connect_btn.disabled = false
	_join_connect_btn.text     = tr("BTN_CONNECT")
	_join_status.text          = tr("JOIN_FAILED")
