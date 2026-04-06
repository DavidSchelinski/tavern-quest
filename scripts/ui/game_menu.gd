extends CanvasLayer

signal resumed
signal quit_to_menu

const SETTINGS_PATH := "user://settings.cfg"
const ACTIONS : Dictionary = {
	"move_forward" : "Vorwärts",
	"move_back"    : "Rückwärts",
	"move_left"    : "Links",
	"move_right"   : "Rechts",
	"jump"         : "Springen",
	"sprint"       : "Rennen",
	"interact"     : "Interagieren",
}

var _cfg          := ConfigFile.new()
var _rebind_action : String = ""
var _rebind_btn    : Button = null
var _control_btns  : Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg.load(SETTINGS_PATH)
	_build_ui()
	visible = false


func open() -> void:
	visible = true
	if not multiplayer.has_multiplayer_peer():
		get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Refresh displayed key labels
	for action in _control_btns:
		_control_btns[action].text = _action_key_string(action)


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


# ──────────────────────────────────────────────────────────────────────────────
#  BUILD UI
# ──────────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
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
	title.text = "Spielmenü"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(tabs)

	_build_controls_tab(tabs)

	# Bottom buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	col.add_child(btn_row)

	var resume_btn := Button.new()
	resume_btn.text = "Fortsetzen"
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume_btn.custom_minimum_size = Vector2(0, 44)
	resume_btn.pressed.connect(close)
	btn_row.add_child(resume_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Hauptmenü"
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
#  CONTROLS TAB
# ──────────────────────────────────────────────────────────────────────────────

func _build_controls_tab(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Steuerung"
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
		lbl.text = ACTIONS[action]
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
	btn.text       = "Taste drücken …"


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
