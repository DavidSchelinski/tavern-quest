extends CanvasLayer

## InGame-Menü mit 5 Tabs: Inventar, Quests, Charakter, Skills, Abenteuergruppe.
## Alle Seiten sind als eigene Szenen im Editor sichtbar.

signal closed

var _player_ref  : Node3D = null
var _current_tab : int = 0

var _root       : Control
var _tab_btns   : Array[Button] = []
var _pages      : Array[Control] = []
var _held_icon  : TextureRect = null
var _held_label : Label = null

const TAB_H     := 38
const PANEL_W   := 900.0
const CONTENT_H := 560.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func open(player: Node3D) -> void:
	_player_ref = player

	# Setup each page with player reference
	var inv_page := _pages[0]
	if inv_page.has_method("setup"):
		inv_page.setup(player, _held_icon, _held_label)
		inv_page.drop_to_world.connect(_do_drop_to_world)

	var quest_page := _pages[1]
	if quest_page.has_method("setup"):
		quest_page.setup(player)

	var char_page := _pages[2]
	if char_page.has_method("setup"):
		char_page.setup(player)

	var skill_page := _pages[3]
	if skill_page.has_method("setup"):
		skill_page.setup(player)

	var group_page := _pages[4]
	if group_page.has_method("setup"):
		group_page.setup(player)

	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_switch_tab(_current_tab)


func close() -> void:
	# Let inventory page clean up held items
	if _pages.size() > 0 and _pages[0].has_method("on_menu_close"):
		_pages[0].on_menu_close()
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	closed.emit()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Backdrop
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = UITheme.BG_OVERLAY
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_bg_input)
	_root.add_child(bg)

	# Outer panel
	var panel_h : float = CONTENT_H + TAB_H
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(PANEL_W, panel_h)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-PANEL_W / 2.0, -panel_h / 2.0)
	panel.size = Vector2(PANEL_W, panel_h)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_style())
	_root.add_child(panel)

	# Tab strip
	_build_tab_strip(panel, PANEL_W)

	# Separator
	var line := ColorRect.new()
	line.position = Vector2(0, TAB_H)
	line.size = Vector2(PANEL_W, 1)
	line.color = UITheme.SEPARATOR
	panel.add_child(line)

	# Content area
	var content := Control.new()
	content.position = Vector2(0, TAB_H + 1)
	content.size = Vector2(PANEL_W, CONTENT_H)
	panel.add_child(content)

	# Page 0 - Inventory
	var inv_page := Control.new()
	var inv_script := load("res://scripts/ui/inventory_page.gd")
	inv_page.set_script(inv_script)
	inv_page.size = Vector2(PANEL_W, CONTENT_H)
	content.add_child(inv_page)
	_pages.append(inv_page)

	# Page 1 - Quests
	var quest_page := Control.new()
	var quest_script := load("res://scripts/ui/quest_page.gd")
	quest_page.set_script(quest_script)
	quest_page.size = Vector2(PANEL_W, CONTENT_H)
	content.add_child(quest_page)
	_pages.append(quest_page)

	# Page 2 - Character
	var char_page := Control.new()
	var char_script := load("res://scripts/ui/character_page.gd")
	char_page.set_script(char_script)
	char_page.size = Vector2(PANEL_W, CONTENT_H)
	content.add_child(char_page)
	_pages.append(char_page)

	# Page 3 - Skills
	var skill_page := Control.new()
	var skill_script := load("res://scripts/ui/skill_page.gd")
	skill_page.set_script(skill_script)
	skill_page.size = Vector2(PANEL_W, CONTENT_H)
	content.add_child(skill_page)
	_pages.append(skill_page)

	# Page 4 - Adventure Group
	var group_page := Control.new()
	var group_script := load("res://scripts/ui/adventure_group_page.gd")
	group_page.set_script(group_script)
	group_page.size = Vector2(PANEL_W, CONTENT_H)
	content.add_child(group_page)
	_pages.append(group_page)

	# Floating held-item icon
	_held_icon = TextureRect.new()
	_held_icon.custom_minimum_size = Vector2(60, 60)
	_held_icon.size = Vector2(60, 60)
	_held_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_held_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_held_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_icon.visible = false
	_root.add_child(_held_icon)

	_held_label = Label.new()
	_held_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_held_label.size = Vector2(60, 20)
	_held_label.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	_held_label.add_theme_color_override("font_color", Color.WHITE)
	_held_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_label.visible = false
	_root.add_child(_held_label)


func _build_tab_strip(parent: Control, panel_w: float) -> void:
	var labels := ["Inventar", "Quests", "Charakter", "Skills", "Gruppe"]
	var tab_w := panel_w / labels.size()

	for i in labels.size():
		var btn := Button.new()
		btn.text = labels[i]
		btn.position = Vector2(i * tab_w, 0)
		btn.size = Vector2(tab_w, TAB_H)
		btn.add_theme_font_size_override("font_size", UITheme.TAB_SIZE)
		btn.flat = true
		var idx := i
		btn.pressed.connect(func() -> void: _switch_tab(idx))
		parent.add_child(btn)
		_tab_btns.append(btn)


func _switch_tab(index: int) -> void:
	_current_tab = index
	for i in _pages.size():
		_pages[i].visible = (i == index)
	_apply_tab_styles()
	# Refresh the active page
	if _pages[index].has_method("refresh"):
		_pages[index].refresh()


func _apply_tab_styles() -> void:
	for i in _tab_btns.size():
		var btn := _tab_btns[i]
		var active := (i == _current_tab)

		var s := UITheme.make_tab_style(active)
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_stylebox_override("hover", s)
		btn.add_theme_stylebox_override("pressed", s)
		btn.add_theme_stylebox_override("focus", s)

		var col := UITheme.TEXT_ACTIVE if active else UITheme.TEXT_DIMMED
		btn.add_theme_color_override("font_color", col)
		btn.add_theme_color_override("font_hover_color", UITheme.TAB_HOVER_TEXT)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	# Update held item position
	if event is InputEventMouseMotion and _pages.size() > 0:
		var inv_page = _pages[0]
		if inv_page.has_method("update_held_position"):
			inv_page.update_held_position(event.position)


func _on_bg_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
	# Delegate to inventory page
	if _pages.size() > 0 and _pages[0].has_method("handle_bg_input"):
		_pages[0].handle_bg_input(event)


func _do_drop_to_world(item_id: String, count: int) -> void:
	if _player_ref == null:
		return
	var scene := load("res://scenes/world/pickable_item.tscn") as PackedScene
	if scene == null:
		return
	var item := load("res://data/items/" + item_id + ".tres") as ItemData
	if item == null:
		return
	for i in count:
		var inst := scene.instantiate()
		inst.item_data = item
		var fwd := -_player_ref.global_transform.basis.z
		var offset := fwd * 2.0 + Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3))
		inst.global_position = _player_ref.global_position + offset
		_player_ref.get_parent().add_child(inst)
