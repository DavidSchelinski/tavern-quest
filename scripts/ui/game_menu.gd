extends CanvasLayer

## In-Game-Pausemenü.
## Öffnet sich über ESC oder M-Taste (open_menu-Aktion).
## Alle Nodes sind in scenes/ui/game_menu.tscn definiert – im Editor bearbeitbar.

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

# ── Node-Refs ─────────────────────────────────────────────────────────────────

@onready var _fps_label        : Label        = $FPSRoot/FPSLabel
@onready var _root             : Control      = $Root
@onready var _tabs             : TabContainer = $Root/Center/Panel/Margin/VBox/Tabs
@onready var _master_slider    : HSlider      = $Root/Center/Panel/Margin/VBox/Tabs/Audio/Pad/Inner/MasterRow/MasterSlider
@onready var _master_value     : Label        = $Root/Center/Panel/Margin/VBox/Tabs/Audio/Pad/Inner/MasterRow/MasterValue
@onready var _fps_check        : CheckButton  = $Root/Center/Panel/Margin/VBox/Tabs/Display/Pad/Inner/FPSRow/FPSCheck
@onready var _fullscreen_check : CheckButton  = $Root/Center/Panel/Margin/VBox/Tabs/Display/Pad/Inner/FullscreenRow/FullscreenCheck
@onready var _controls_inner   : VBoxContainer = $Root/Center/Panel/Margin/VBox/Tabs/Controls/ControlsInner
@onready var _dev_rank_label   : Label        = $Root/Center/Panel/Margin/VBox/Tabs/Dev/DevInner/DevRankLabel
@onready var _dev_quest_list   : VBoxContainer = $Root/Center/Panel/Margin/VBox/Tabs/Dev/DevInner/DevQuestList
@onready var _resume_btn       : Button       = $Root/Center/Panel/Margin/VBox/ButtonRow/ResumeButton
@onready var _main_menu_btn    : Button       = $Root/Center/Panel/Margin/VBox/ButtonRow/MainMenuButton

var _cfg           := ConfigFile.new()
var _rebind_action : String = ""
var _rebind_btn    : Button = null
var _control_btns  : Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg.load(SETTINGS_PATH)

	_resume_btn.pressed.connect(close)
	_main_menu_btn.pressed.connect(_on_quit_to_menu)

	_master_slider.value_changed.connect(_on_master_changed)
	_fps_check.toggled.connect(_on_fps_toggled)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	_build_controls_list()

	_tabs.set_tab_title(0, tr("TAB_AUDIO"))
	_tabs.set_tab_title(1, tr("TAB_DISPLAY"))
	_tabs.set_tab_title(2, tr("TAB_CONTROLS"))
	_tabs.set_tab_title(3, "Dev")

	_apply_display_settings()

	# Quests-Signal verbinden für Dev-Tab
	var quests := get_parent().get_node_or_null("Quests")
	if quests != null:
		quests.quests_changed.connect(_refresh_dev_tab)

	_root.visible = false


func open() -> void:
	_root.visible = true
	if not multiplayer.has_multiplayer_peer():
		get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Werte beim Öffnen synchronisieren
	_master_slider.value = _cfg.get_value("audio", "master_pct", 100.0)
	_fps_check.set_pressed_no_signal(_cfg.get_value("display", "show_fps", false))
	_fullscreen_check.set_pressed_no_signal(
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	for action: String in _control_btns:
		(_control_btns[action] as Button).text = _action_key_string(action)
	_refresh_dev_tab()


func close() -> void:
	_root.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	resumed.emit()


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if not _rebind_action.is_empty():
		if event is InputEventKey and event.pressed and not event.is_echo():
			get_viewport().set_input_as_handled()
			_finish_rebind(event)
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_menu"):
		get_viewport().set_input_as_handled()
		close()


func _process(_delta: float) -> void:
	if _fps_label and _fps_label.visible:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


# ── Audio ─────────────────────────────────────────────────────────────────────

func _on_master_changed(val: float) -> void:
	var db := linear_to_db(val / 100.0) if val > 0.0 else -80.0
	AudioServer.set_bus_volume_db(0, db)
	_master_value.text = "%d" % int(val)
	_cfg.set_value("audio", "master_pct", val)
	_cfg.save(SETTINGS_PATH)


# ── Display ───────────────────────────────────────────────────────────────────

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


func _apply_display_settings() -> void:
	var show_fps : bool = _cfg.get_value("display", "show_fps", false)
	_fps_label.visible = show_fps
	var fullscreen : bool = _cfg.get_value("display", "fullscreen", false)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ── Controls ──────────────────────────────────────────────────────────────────

func _build_controls_list() -> void:
	for child in _controls_inner.get_children():
		child.queue_free()
	_control_btns.clear()

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


# ── Dev-Tab ───────────────────────────────────────────────────────────────────

func _refresh_dev_tab() -> void:
	var guild  := get_parent().get_node_or_null("GuildRank")
	var quests := get_parent().get_node_or_null("Quests")

	if guild != null and _dev_rank_label != null:
		_dev_rank_label.text = "Rang: %s  |  Punkte: %d / %d" % [
			guild.get_rank(), guild.get_points(), guild.get_points_needed()
		]

	if quests == null or _dev_quest_list == null:
		return

	for child in _dev_quest_list.get_children():
		child.queue_free()

	var active : Array[Dictionary] = quests.get_active_quests()
	if active.is_empty():
		var lbl := Label.new()
		lbl.text = "Keine aktiven Quests."
		lbl.modulate = Color(0.55, 0.53, 0.50)
		lbl.add_theme_font_size_override("font_size", 13)
		_dev_quest_list.add_child(lbl)
		return

	for q : Dictionary in active:
		var quest_id : String = q.get("title_key", "") as String
		var row := HBoxContainer.new()
		_dev_quest_list.add_child(row)

		var lbl := Label.new()
		lbl.text = "[%s] %s" % [q.get("rank", "?"), tr(quest_id)]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = "✓ Abschließen"
		btn.custom_minimum_size = Vector2(140, 0)
		btn.pressed.connect(func() -> void:
			quests.complete_quest(quest_id)
		)
		row.add_child(btn)


# ── Quit ──────────────────────────────────────────────────────────────────────

func _on_quit_to_menu() -> void:
	get_tree().paused = false

	# Spielerdaten vor dem Verlassen speichern
	var player := get_parent()
	if is_instance_valid(player) and PlayerProfile.is_logged_in():
		var skills: Node    = player.get_node_or_null("Skills")
		var inventory: Node = player.get_node_or_null("Inventory")
		var stats: Node     = player.get_node_or_null("Stats")
		var quests: Node    = player.get_node_or_null("Quests")
		var guild: Node     = player.get_node_or_null("GuildRank")

		var data := {}
		if skills != null:
			skills.last_position = player.position
			data.merge(skills.get_save_data())
		if inventory != null:
			data["inventory"] = inventory.get_save_data()
		if stats != null:
			data["stats_data"] = stats.get_save_data()
		if quests != null:
			data["quests_data"] = quests.get_save_data()
		if guild != null:
			data["guild_data"] = guild.get_save_data()
		if player.get("health") != null:
			data["hp"] = float(player.health)
		if player.get("_stamina") != null:
			data["stamina"] = float(player._stamina)

		SaveManager.update_player_data(PlayerProfile.current_player_name, data)
		print("GameMenu: Spielerdaten gespeichert für '%s'" % PlayerProfile.current_player_name)

	NetworkManager.close()
	quit_to_menu.emit()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
