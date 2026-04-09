extends CanvasLayer

signal resumed
signal quit_to_menu

const SETTINGS_PATH := "user://settings.cfg"
const ACTIONS : Dictionary = {
	"move_forward" : "ACTION_FORWARD",
	"move_back"    : "ACTION_BACK",
	"move_left"    : "ACTION_LEFT",
	"move_right"   : "ACTION_RIGHT",
	"jump"         : "ACTION_JUMP",
	"sprint"       : "ACTION_SPRINT",
	"interact"     : "ACTION_INTERACT",
}

var _cfg            := ConfigFile.new()
var _rebind_action  : String = ""
var _rebind_btn     : Button = null
var _control_btns   : Dictionary = {}
var _master_slider  : HSlider
var _fps_check      : CheckButton
var _fullscreen_check : CheckButton
var _fps_label      : Label
var _dev_list       : VBoxContainer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg.load(SETTINGS_PATH)
	_build_ui()
	_apply_display_settings()
	get_parent().get_node("Quests").quests_changed.connect(_refresh_dev_tab)
	visible = false


func open() -> void:
	visible = true
	if not multiplayer.has_multiplayer_peer():
		get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Refresh key labels
	for action in _control_btns:
		_control_btns[action].text = _action_key_string(action)
	# Sync slider/checks
	_master_slider.value = _cfg.get_value("audio", "master_pct", 100.0)
	_fps_check.set_pressed_no_signal(_cfg.get_value("display", "show_fps", false))
	_fullscreen_check.set_pressed_no_signal(
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	_refresh_dev_tab()


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	resumed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _rebind_action.is_empty():
		if event is InputEventKey and event.pressed and not event.is_echo():
			get_viewport().set_input_as_handled()
			_finish_rebind(event)
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _process(_delta: float) -> void:
	if _fps_label and _fps_label.visible:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


# ──────────────────────────────────────────────────────────────────────────────
#  BUILD UI
# ──────────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# FPS label — always on screen (above menu overlay)
	_fps_label = Label.new()
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -110
	_fps_label.offset_top  = 8
	_fps_label.visible     = false
	# Wrap in a Control so it stays outside the menu panel
	var fps_root := Control.new()
	fps_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	fps_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_root.add_child(_fps_label)
	add_child(fps_root)
	fps_root.show()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Dim background
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(660, 560)
	center.add_child(panel)

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
	title.text = tr("GAME_MENU_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(tabs)

	_build_audio_tab(tabs)
	_build_display_tab(tabs)
	_build_controls_tab(tabs)
	_build_dev_tab(tabs)

	# Bottom buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	col.add_child(btn_row)

	var resume_btn := Button.new()
	resume_btn.text = tr("BTN_RESUME")
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume_btn.custom_minimum_size = Vector2(0, 44)
	resume_btn.pressed.connect(close)
	btn_row.add_child(resume_btn)

	var menu_btn := Button.new()
	menu_btn.text = tr("BTN_MAIN_MENU")
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_btn.custom_minimum_size = Vector2(0, 44)
	menu_btn.pressed.connect(_on_quit_to_menu)
	btn_row.add_child(menu_btn)


func _on_quit_to_menu() -> void:
	get_tree().paused = false
	NetworkManager.close()
	quit_to_menu.emit()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ──────────────────────────────────────────────────────────────────────────────
#  AUDIO TAB
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

	_master_slider = _add_slider_row(inner, tr("AUDIO_MASTER"), _cfg.get_value("audio", "master_pct", 100.0))
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


func _set_master_volume(pct: float) -> void:
	var db := linear_to_db(pct / 100.0) if pct > 0.0 else -80.0
	AudioServer.set_bus_volume_db(0, db)


# ──────────────────────────────────────────────────────────────────────────────
#  DISPLAY TAB
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


func _apply_display_settings() -> void:
	var show_fps : bool = _cfg.get_value("display", "show_fps", false)
	_fps_label.visible = show_fps
	var fullscreen : bool = _cfg.get_value("display", "fullscreen", false)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ──────────────────────────────────────────────────────────────────────────────
#  CONTROLS TAB
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
	ev.physical_keycode = physical_keycode
	InputMap.action_add_event(action, ev)


func _action_key_string(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string(ev.physical_keycode)
	return "—"


func _save_settings() -> void:
	_cfg.save(SETTINGS_PATH)


# ──────────────────────────────────────────────────────────────────────────────
#  DEV TAB
# ──────────────────────────────────────────────────────────────────────────────

func _build_dev_tab(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Dev"
	tabs.add_child(scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_top",   12)
	pad.add_theme_constant_override("margin_left",  12)
	pad.add_theme_constant_override("margin_right", 12)
	v.add_child(pad)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	pad.add_child(inner)

	var warning := Label.new()
	warning.text = "⚠  Nur für Testzwecke / For testing only"
	warning.add_theme_color_override("font_color", Color(0.95, 0.65, 0.20, 1.0))
	warning.add_theme_font_size_override("font_size", 13)
	inner.add_child(warning)

	var sep := HSeparator.new()
	inner.add_child(sep)

	# Rank info row
	var rank_row := HBoxContainer.new()
	inner.add_child(rank_row)
	var rank_lbl := Label.new()
	rank_lbl.name = "DevRankLabel"
	rank_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_lbl.add_theme_font_size_override("font_size", 13)
	rank_row.add_child(rank_lbl)

	var sep2 := HSeparator.new()
	inner.add_child(sep2)

	var quests_lbl := Label.new()
	quests_lbl.text = "Aktive Quests:"
	quests_lbl.add_theme_font_size_override("font_size", 13)
	inner.add_child(quests_lbl)

	_dev_list = VBoxContainer.new()
	_dev_list.name = "DevList"
	_dev_list.add_theme_constant_override("separation", 4)
	inner.add_child(_dev_list)


func _refresh_dev_tab() -> void:
	if _dev_list == null:
		return

	# Update rank label.
	var rank_lbl := _dev_list.get_parent().get_parent().get_parent() \
		.find_child("DevRankLabel", true, false) as Label
	if rank_lbl:
		var rank  : String = get_parent().get_node("GuildRank").get_rank()
		var pts   : int    = get_parent().get_node("GuildRank").get_points()
		var needed : int   = get_parent().get_node("GuildRank").get_points_needed()
		rank_lbl.text = "Rang: %s  |  Punkte: %d / %d" % [rank, pts, needed]

	# Rebuild quest list.
	for child in _dev_list.get_children():
		child.queue_free()

	var active : Array[Dictionary] = get_parent().get_node("Quests").get_active_quests()
	if active.is_empty():
		var lbl := Label.new()
		lbl.text = "Keine aktiven Quests."
		lbl.add_theme_color_override("font_color", Color(0.55, 0.53, 0.50, 1.0))
		lbl.add_theme_font_size_override("font_size", 13)
		_dev_list.add_child(lbl)
		return

	for q : Dictionary in active:
		var quest_id : String = q.get("title_key", "") as String
		var row := HBoxContainer.new()
		_dev_list.add_child(row)

		var lbl := Label.new()
		lbl.text = "[%s] %s" % [q.get("rank", "?"), tr(quest_id)]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = "✓ Abschließen"
		btn.custom_minimum_size = Vector2(140, 0)
		btn.pressed.connect(func() -> void:
			get_parent().get_node("Quests").complete_quest(quest_id)
		)
		row.add_child(btn)
