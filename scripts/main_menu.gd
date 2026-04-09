extends Control

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
}

const LOCALES := [
	{ "code": "de", "key": "LANG_DE" },
	{ "code": "en", "key": "LANG_EN" },
]

var _cfg           := ConfigFile.new()
var _rebind_action : String = ""
var _rebind_btn    : Button = null

var _fps_label        : Label
var _master_slider    : HSlider
var _fps_check        : CheckButton
var _fullscreen_check : CheckButton
var _settings_root    : Control
var _control_btns     : Dictionary = {}   # action → Button
var _locale_options   : OptionButton

# Multiplayer UI refs
var _host_root       : Control
var _join_root       : Control
var _host_port_field : LineEdit
var _host_local_ip   : Label
var _host_public_ip  : Label
var _join_ip_field   : LineEdit
var _join_port_field : LineEdit
var _join_status     : Label
var _join_btn        : Button
var _join_server_list : ItemList
var _discovered      : Dictionary = {}   # "ip:port" → index
var _http            : HTTPRequest


func _ready() -> void:
	_cfg.load(SETTINGS_PATH)
	_build_ui()
	_apply_settings()
	# HTTP node for public-IP fetch
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_public_ip_received)
	# NetworkManager signals for join flow
	NetworkManager.player_connected.connect(_on_net_player_connected)
	NetworkManager.connection_failed.connect(_on_net_connection_failed)
	NetworkManager.server_found.connect(_on_server_found)


func _process(_delta: float) -> void:
	if _fps_label and _fps_label.visible:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _input(event: InputEvent) -> void:
	if _rebind_action.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		get_viewport().set_input_as_handled()
		_finish_rebind(event)


# ──────────────────────────────────────────────────────────────────────────────
#  BUILD UI
# ──────────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.06, 0.04)
	add_child(bg)

	# FPS counter (top-right)
	_fps_label = Label.new()
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -110
	_fps_label.offset_top  = 8
	_fps_label.visible     = false
	add_child(_fps_label)

	# Centered column
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(380, 0)
	col.add_theme_constant_override("separation", 14)
	c.add_child(col)

	# Title
	var title := Label.new()
	title.text = tr("MENU_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	col.add_child(title)

	var sub := Label.new()
	sub.text = tr("MENU_SUBTITLE")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(0.6, 0.6, 0.6)
	col.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	col.add_child(gap)

	# Main buttons
	var solo_btn     := _make_button(tr("MENU_SOLO"))
	var host_btn     := _make_button(tr("MENU_HOST"))
	var join_btn_m   := _make_button(tr("MENU_JOIN"))
	var settings_btn := _make_button(tr("MENU_SETTINGS"))
	var quit_btn     := _make_button(tr("MENU_QUIT"))
	col.add_child(solo_btn)
	col.add_child(host_btn)
	col.add_child(join_btn_m)
	col.add_child(settings_btn)
	col.add_child(quit_btn)

	solo_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(GAME_SCENE)
	)
	host_btn.pressed.connect(func() -> void:
		_host_root.visible = true
		_http.request("https://api.ipify.org")
		_host_local_ip.text = NetworkManager.get_local_ip()
		_host_public_ip.text = tr("HOST_FETCHING_IP")
	)
	join_btn_m.pressed.connect(func() -> void:
		_join_root.visible = true
		_discovered.clear()
		_join_server_list.clear()
		NetworkManager.start_discovery()
	)
	settings_btn.pressed.connect(func() -> void:
		_settings_root.visible = true
	)
	quit_btn.pressed.connect(func() -> void:
		get_tree().quit()
	)

	_build_settings_overlay()
	_build_host_overlay()
	_build_join_overlay()


func _make_button(label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(380, 54)
	return b


# ──────────────────────────────────────────────────────────────────────────────
#  SETTINGS OVERLAY
# ──────────────────────────────────────────────────────────────────────────────

func _build_settings_overlay() -> void:
	_settings_root = Control.new()
	_settings_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_root.visible = false
	add_child(_settings_root)

	# Dim
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	_settings_root.add_child(dim)

	# Centered panel
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_root.add_child(c)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(660, 560)
	c.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   24)
	margin.add_theme_constant_override("margin_right",  24)
	margin.add_theme_constant_override("margin_top",    20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var title := Label.new()
	title.text = tr("SETTINGS_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(tabs)

	_build_audio_tab(tabs)
	_build_display_tab(tabs)
	_build_controls_tab(tabs)
	_build_language_tab(tabs)

	var close := Button.new()
	close.text = tr("BTN_CLOSE")
	close.pressed.connect(func() -> void: _settings_root.visible = false)
	col.add_child(close)


# ──────────────────────────────────────────────────────────────────────────────
#  TAB: AUDIO
# ──────────────────────────────────────────────────────────────────────────────

func _build_audio_tab(tabs: TabContainer) -> void:
	var v := VBoxContainer.new()
	v.name = tr("TAB_AUDIO")
	tabs.add_child(v)

	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_top",   20)
	pad.add_theme_constant_override("margin_left",  12)
	pad.add_theme_constant_override("margin_right", 12)
	v.add_child(pad)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 18)
	pad.add_child(inner)

	_master_slider = _add_slider_row(inner, tr("AUDIO_MASTER"), 100)
	_master_slider.value_changed.connect(func(val: float) -> void:
		_set_master_volume(val)
		_cfg.set_value("audio", "master_pct", val)
		_save_settings()
	)


func _add_slider_row(parent: VBoxContainer, label: String, default_val: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(200, 0)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step      = 1
	slider.value     = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d" % int(default_val)
	val_lbl.custom_minimum_size = Vector2(36, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%d" % int(v)
	)

	return slider


# ──────────────────────────────────────────────────────────────────────────────
#  TAB: ANZEIGE
# ──────────────────────────────────────────────────────────────────────────────

func _build_display_tab(tabs: TabContainer) -> void:
	var v := VBoxContainer.new()
	v.name = tr("TAB_DISPLAY")
	tabs.add_child(v)

	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_top",   20)
	pad.add_theme_constant_override("margin_left",  12)
	pad.add_theme_constant_override("margin_right", 12)
	v.add_child(pad)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 16)
	pad.add_child(inner)

	_fps_check        = _add_check_row(inner, tr("DISPLAY_FPS"))
	_fullscreen_check = _add_check_row(inner, tr("DISPLAY_FULLSCREEN"))

	_fps_check.toggled.connect(func(on: bool) -> void:
		_fps_label.visible = on
		_cfg.set_value("display", "show_fps", on)
		_save_settings()
	)
	_fullscreen_check.toggled.connect(func(on: bool) -> void:
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if on \
				else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)
		_cfg.set_value("display", "fullscreen", on)
		_save_settings()
	)


func _add_check_row(parent: VBoxContainer, label: String) -> CheckButton:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var check := CheckButton.new()
	row.add_child(check)
	return check


# ──────────────────────────────────────────────────────────────────────────────
#  TAB: STEUERUNG
# ──────────────────────────────────────────────────────────────────────────────

func _build_controls_tab(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = tr("TAB_CONTROLS")
	tabs.add_child(scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_top",   16)
	pad.add_theme_constant_override("margin_left",  12)
	pad.add_theme_constant_override("margin_right", 12)
	v.add_child(pad)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	pad.add_child(inner)

	for action in ACTIONS:
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


# ──────────────────────────────────────────────────────────────────────────────
#  TAB: SPRACHE
# ──────────────────────────────────────────────────────────────────────────────

func _build_language_tab(tabs: TabContainer) -> void:
	var v := VBoxContainer.new()
	v.name = tr("TAB_LANGUAGE")
	tabs.add_child(v)

	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_top",   20)
	pad.add_theme_constant_override("margin_left",  12)
	pad.add_theme_constant_override("margin_right", 12)
	v.add_child(pad)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 16)
	pad.add_child(inner)

	var row := HBoxContainer.new()
	inner.add_child(row)

	var lbl := Label.new()
	lbl.text = tr("TAB_LANGUAGE")
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	_locale_options = OptionButton.new()
	_locale_options.custom_minimum_size = Vector2(200, 0)
	var current_locale := LocaleManager.get_locale()
	for i in range(LOCALES.size()):
		_locale_options.add_item(tr(LOCALES[i]["key"]), i)
		if LOCALES[i]["code"] == current_locale:
			_locale_options.selected = i
	_locale_options.item_selected.connect(_on_locale_changed)
	row.add_child(_locale_options)

	var hint := Label.new()
	hint.text = "Restart required for full effect." if current_locale == "en" else "Neustart erforderlich für vollständige Übernahme."
	hint.modulate = Color(0.6, 0.6, 0.6)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(hint)


func _on_locale_changed(idx: int) -> void:
	var locale_code : String = LOCALES[idx]["code"]
	LocaleManager.set_locale(locale_code)


# ──────────────────────────────────────────────────────────────────────────────
#  SETTINGS APPLICATION
# ──────────────────────────────────────────────────────────────────────────────

func _apply_settings() -> void:
	# Audio
	var master_pct : float = _cfg.get_value("audio", "master_pct", 100.0)
	_master_slider.value = master_pct
	_set_master_volume(master_pct)

	# Display — use set_pressed_no_signal to avoid re-triggering side effects
	var show_fps  : bool = _cfg.get_value("display", "show_fps",   false)
	var fullscreen : bool = _cfg.get_value("display", "fullscreen", false)
	_fps_check.set_pressed_no_signal(show_fps)
	_fps_label.visible = show_fps
	_fullscreen_check.set_pressed_no_signal(fullscreen)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	# Controls
	for action in ACTIONS:
		var code : int = _cfg.get_value("controls", action, -1)
		if code != -1:
			_apply_keybind(action, code)
			if _control_btns.has(action):
				_control_btns[action].text = _action_key_string(action)


func _set_master_volume(pct: float) -> void:
	var db := linear_to_db(pct / 100.0) if pct > 0.0 else -80.0
	AudioServer.set_bus_volume_db(0, db)


func _save_settings() -> void:
	_cfg.save(SETTINGS_PATH)


# ──────────────────────────────────────────────────────────────────────────────
#  KEY REBINDING
# ──────────────────────────────────────────────────────────────────────────────

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

	# ESC cancels without changing
	if event.physical_keycode == KEY_ESCAPE:
		btn.text = _action_key_string(action)
		return

	_apply_keybind(action, event.physical_keycode)
	_cfg.set_value("controls", action, event.physical_keycode)
	_save_settings()
	btn.text = _action_key_string(action)


func _apply_keybind(action: String, physical_keycode: int) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode as Key
	InputMap.action_add_event(action, ev)


func _action_key_string(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string(ev.physical_keycode)
	return "—"


# ──────────────────────────────────────────────────────────────────────────────
#  HOST OVERLAY
# ──────────────────────────────────────────────────────────────────────────────

func _build_host_overlay() -> void:
	_host_root = _make_overlay_root()

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(500, 360)
	(_host_root.get_child(1) as CenterContainer).add_child(panel)

	var margin := _panel_margin(panel)
	var col    := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	var title := Label.new()
	title.text = tr("HOST_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	col.add_child(title)

	# Local IP
	var local_row := HBoxContainer.new()
	col.add_child(local_row)
	var local_lbl := Label.new()
	local_lbl.text = tr("HOST_LOCAL_IP")
	local_lbl.custom_minimum_size = Vector2(130, 0)
	local_row.add_child(local_lbl)
	_host_local_ip = Label.new()
	_host_local_ip.text = "–"
	local_row.add_child(_host_local_ip)

	# Public IP
	var pub_row := HBoxContainer.new()
	col.add_child(pub_row)
	var pub_lbl := Label.new()
	pub_lbl.text = tr("HOST_PUBLIC_IP")
	pub_lbl.custom_minimum_size = Vector2(130, 0)
	pub_row.add_child(pub_lbl)
	_host_public_ip = Label.new()
	_host_public_ip.text = "–"
	pub_row.add_child(_host_public_ip)

	# Port
	var port_row := HBoxContainer.new()
	col.add_child(port_row)
	var port_lbl := Label.new()
	port_lbl.text = tr("HOST_PORT")
	port_lbl.custom_minimum_size = Vector2(130, 0)
	port_row.add_child(port_lbl)
	_host_port_field = LineEdit.new()
	_host_port_field.text = str(DEFAULT_PORT)
	_host_port_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_row.add_child(_host_port_field)

	var info := Label.new()
	info.text = tr("HOST_PORT_INFO")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.modulate = Color(0.6, 0.6, 0.6)
	col.add_child(info)

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(gap)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	col.add_child(btns)

	var cancel := Button.new()
	cancel.text = tr("BTN_CANCEL")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void: _host_root.visible = false)
	btns.add_child(cancel)

	var start := Button.new()
	start.text = tr("BTN_HOST_START")
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(_on_host_start)
	btns.add_child(start)


func _on_host_start() -> void:
	var port := int(_host_port_field.text) if _host_port_field.text.is_valid_int() else DEFAULT_PORT
	var err   := NetworkManager.host(port)
	if err != OK:
		_host_public_ip.text = tr("HOST_PORT_ERROR")
		return
	_host_root.visible = false
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_public_ip_received(_result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _host_public_ip:
		_host_public_ip.text = body.get_string_from_utf8().strip_edges()


# ──────────────────────────────────────────────────────────────────────────────
#  JOIN OVERLAY
# ──────────────────────────────────────────────────────────────────────────────

func _build_join_overlay() -> void:
	_join_root = _make_overlay_root()

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(520, 480)
	(_join_root.get_child(1) as CenterContainer).add_child(panel)

	var margin := _panel_margin(panel)
	var col    := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var title := Label.new()
	title.text = tr("JOIN_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	col.add_child(title)

	# ── Server list ───────────────────────────────────────────────────────────
	var list_lbl := Label.new()
	list_lbl.text = tr("JOIN_LAN_SERVERS")
	list_lbl.modulate = Color(0.75, 0.75, 0.75)
	col.add_child(list_lbl)

	_join_server_list = ItemList.new()
	_join_server_list.custom_minimum_size = Vector2(0, 120)
	_join_server_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_join_server_list.item_selected.connect(_on_server_selected)
	col.add_child(_join_server_list)

	# ── Manual entry ──────────────────────────────────────────────────────────
	var manual_lbl := Label.new()
	manual_lbl.text = tr("JOIN_MANUAL")
	manual_lbl.modulate = Color(0.75, 0.75, 0.75)
	col.add_child(manual_lbl)

	# IP
	var ip_row := HBoxContainer.new()
	col.add_child(ip_row)
	var ip_lbl := Label.new()
	ip_lbl.text = tr("JOIN_IP")
	ip_lbl.custom_minimum_size = Vector2(120, 0)
	ip_row.add_child(ip_lbl)
	_join_ip_field = LineEdit.new()
	_join_ip_field.placeholder_text = tr("JOIN_IP_HINT")
	_join_ip_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_row.add_child(_join_ip_field)

	# Port
	var port_row := HBoxContainer.new()
	col.add_child(port_row)
	var port_lbl := Label.new()
	port_lbl.text = tr("JOIN_PORT")
	port_lbl.custom_minimum_size = Vector2(120, 0)
	port_row.add_child(port_lbl)
	_join_port_field = LineEdit.new()
	_join_port_field.text = str(DEFAULT_PORT)
	_join_port_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_row.add_child(_join_port_field)

	_join_status = Label.new()
	_join_status.text = ""
	_join_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_status.modulate = Color(1.0, 0.5, 0.5)
	col.add_child(_join_status)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	col.add_child(btns)

	var cancel := Button.new()
	cancel.text = tr("BTN_CANCEL")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void:
		NetworkManager.close()
		NetworkManager.stop_discovery()
		_join_root.visible = false
		_join_status.text  = ""
		_join_btn.disabled = false
		_join_btn.text     = tr("BTN_CONNECT")
	)
	btns.add_child(cancel)

	_join_btn = Button.new()
	_join_btn.text = tr("BTN_CONNECT")
	_join_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_btn.pressed.connect(_on_join_connect)
	btns.add_child(_join_btn)


func _on_join_connect() -> void:
	var ip   := _join_ip_field.text.strip_edges()
	var port := int(_join_port_field.text) if _join_port_field.text.is_valid_int() else DEFAULT_PORT
	if ip.is_empty():
		_join_status.text = tr("JOIN_ENTER_IP")
		return
	_join_btn.disabled = true
	_join_btn.text     = tr("BTN_CONNECTING")
	_join_status.text  = ""
	NetworkManager.stop_discovery()
	NetworkManager.join(ip, port)


func _on_server_found(_ip: String, info: Dictionary) -> void:
	var key  := "%s:%d" % [info.get("ip", ""), int(info.get("port", 0))]
	var text := "%s  (%s)  –  %d/%d %s" % [
		info.get("name", "?"),
		info.get("ip", "?"),
		int(info.get("players", 0)),
		int(info.get("max_players", 0)),
		tr("JOIN_PLAYERS"),
	]
	if _discovered.has(key):
		var idx : int = _discovered[key]
		if idx < _join_server_list.item_count:
			_join_server_list.set_item_text(idx, text)
	else:
		var idx := _join_server_list.add_item(text)
		_join_server_list.set_item_metadata(idx, info)
		_discovered[key] = idx


func _on_server_selected(idx: int) -> void:
	var info : Dictionary = _join_server_list.get_item_metadata(idx)
	_join_ip_field.text   = str(info.get("ip", ""))
	_join_port_field.text = str(int(info.get("port", DEFAULT_PORT)))


func _on_net_player_connected(_id: int) -> void:
	# Called when our own connection to the server succeeds.
	if _join_root and _join_root.visible:
		NetworkManager.stop_discovery()
		_join_root.visible = false
		get_tree().change_scene_to_file(GAME_SCENE)


func _on_net_connection_failed() -> void:
	if _join_btn:
		_join_btn.disabled = false
		_join_btn.text     = tr("BTN_CONNECT")
	if _join_status:
		_join_status.text = tr("JOIN_FAILED")


# ──────────────────────────────────────────────────────────────────────────────
#  OVERLAY HELPERS
# ──────────────────────────────────────────────────────────────────────────────

## Creates the standard dim + center-container overlay root (hidden).
func _make_overlay_root() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	root.add_child(dim)

	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)

	return root


## Adds a full-rect MarginContainer with standard padding to a panel.
func _panel_margin(panel: Panel) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left",   24)
	m.add_theme_constant_override("margin_right",  24)
	m.add_theme_constant_override("margin_top",    20)
	m.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(m)
	return m
