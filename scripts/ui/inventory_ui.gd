extends CanvasLayer

signal closed

const COLS       := 6
const ROWS       := 5
const SLOT_SIZE  := 72
const SLOT_GAP   := 6
const ICON_SIZE  := 60
const PANEL_PAD  := 16

var _root        : Control
var _grid        : Control
var _slot_panels : Array[Panel] = []
var _held_data   : Variant = null   # { "item": ItemData, "count": int } or null
var _held_icon   : TextureRect = null
var _held_label  : Label = null
var _player_ref  : Node3D = null

# Context menu state.
var _ctx_menu    : Panel = null
var _ctx_slot    : int   = -1

# Split dialog state.
var _split_panel  : Panel  = null
var _split_slider : HSlider = null
var _split_label  : Label  = null
var _split_slot   : int    = -1

# Placeholder textures generated at runtime (colored squares).
var _placeholder_cache : Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	InventoryManager.slot_changed.connect(_on_slot_changed)


# ──────────────────────────────────────────────────────────────────────────────
#  PUBLIC
# ──────────────────────────────────────────────────────────────────────────────

func open(player: Node3D) -> void:
	_player_ref = player
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_all_slots()


func close() -> void:
	_close_context_menu()
	_close_split_dialog()
	# If holding an item, put it back.
	if _held_data != null:
		var leftover := InventoryManager.add_item(_held_data["item"], _held_data["count"])
		if leftover > 0:
			_drop_to_world(_held_data["item"], leftover)
		_clear_held()
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	closed.emit()


# ──────────────────────────────────────────────────────────────────────────────
#  BUILD UI
# ──────────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Semi-transparent backdrop — click here to close or drop items.
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.35)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_bg_input)
	_root.add_child(bg)

	# Centered panel.
	var grid_w : float = COLS * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP
	var grid_h : float = ROWS * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP
	var panel_w : float = grid_w + PANEL_PAD * 2
	var panel_h : float = grid_h + PANEL_PAD * 2 + 40  # extra for title

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-panel_w / 2.0, -panel_h / 2.0)
	panel.size = Vector2(panel_w, panel_h)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(panel)

	# Title.
	var title := Label.new()
	title.text = "Inventory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 8)
	title.size = Vector2(panel_w, 30)
	title.add_theme_font_size_override("font_size", 20)
	panel.add_child(title)

	# Grid container.
	_grid = Control.new()
	_grid.position = Vector2(PANEL_PAD, 40)
	_grid.size = Vector2(grid_w, grid_h)
	panel.add_child(_grid)

	for i in InventoryManager.SLOT_COUNT:
		var slot := _create_slot(i)
		_grid.add_child(slot)
		_slot_panels.append(slot)

	# Floating held-item icon (follows mouse).
	_held_icon = TextureRect.new()
	_held_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_held_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	_held_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_held_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_held_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_icon.visible = false
	_root.add_child(_held_icon)

	_held_label = Label.new()
	_held_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_held_label.size = Vector2(ICON_SIZE, 20)
	_held_label.add_theme_font_size_override("font_size", 14)
	_held_label.add_theme_color_override("font_color", Color.WHITE)
	_held_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_label.visible = false
	_root.add_child(_held_label)


func _create_slot(index: int) -> Panel:
	var col := index % COLS
	var row := index / COLS
	var panel := Panel.new()
	panel.position = Vector2(col * (SLOT_SIZE + SLOT_GAP), row * (SLOT_SIZE + SLOT_GAP))
	panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_slot_input.bind(index))

	# Slot background style.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.10, 0.85)
	style.border_color = Color(0.55, 0.45, 0.30, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	# Icon.
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2((SLOT_SIZE - ICON_SIZE) / 2.0, (SLOT_SIZE - ICON_SIZE) / 2.0 - 4)
	icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)

	# Count label.
	var lbl := Label.new()
	lbl.name = "Count"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.position = Vector2(4, 4)
	lbl.size = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)

	return panel


# ──────────────────────────────────────────────────────────────────────────────
#  SLOT RENDERING
# ──────────────────────────────────────────────────────────────────────────────

func _refresh_all_slots() -> void:
	for i in InventoryManager.SLOT_COUNT:
		_refresh_slot(i)


func _refresh_slot(index: int) -> void:
	if index < 0 or index >= _slot_panels.size():
		return
	var panel := _slot_panels[index]
	var icon  := panel.get_node("Icon") as TextureRect
	var lbl   := panel.get_node("Count") as Label
	var data  = InventoryManager.get_slot(index)

	if data == null:
		icon.texture = null
		lbl.text = ""
	else:
		var item : ItemData = data["item"]
		icon.texture = _get_icon(item)
		lbl.text = str(data["count"]) if data["count"] > 1 else ""


func _on_slot_changed(index: int) -> void:
	if visible:
		_refresh_slot(index)


## Returns the item icon, or generates a colored placeholder if none is set.
func _get_icon(item: ItemData) -> Texture2D:
	if item.icon != null:
		return item.icon
	if _placeholder_cache.has(item.id):
		return _placeholder_cache[item.id]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(item.mesh_color)
	# Draw a darker border.
	var border_col := item.mesh_color.darkened(0.4)
	for x in 64:
		for y in 64:
			if x < 3 or x >= 61 or y < 3 or y >= 61:
				img.set_pixel(x, y, border_col)
	var tex := ImageTexture.create_from_image(img)
	_placeholder_cache[item.id] = tex
	return tex


# ──────────────────────────────────────────────────────────────────────────────
#  INPUT
# ──────────────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	# Move held icon with mouse.
	if _held_data != null and event is InputEventMouseMotion:
		_update_held_position(event.position)


func _on_slot_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		_close_split_dialog()
		if _held_data == null:
			_open_context_menu(index, event.global_position)
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	_close_context_menu()
	_close_split_dialog()

	if _held_data == null:
		# Pick up from slot.
		var data = InventoryManager.take_slot(index)
		if data != null:
			_held_data = data
			_held_icon.texture = _get_icon(data["item"])
			_held_icon.visible = true
			_held_label.text = str(data["count"]) if data["count"] > 1 else ""
			_held_label.visible = data["count"] > 1
			_update_held_position(event.global_position)
	else:
		# Place into slot (swap if occupied).
		var returned = InventoryManager.put_slot(index, _held_data)
		if returned == null:
			_clear_held()
		else:
			_held_data = returned
			_held_icon.texture = _get_icon(returned["item"])
			_held_label.text = str(returned["count"]) if returned["count"] > 1 else ""
			_held_label.visible = returned["count"] > 1


func _on_bg_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		_close_context_menu()
		_close_split_dialog()
	if event.button_index == MOUSE_BUTTON_LEFT and _held_data != null:
		_drop_to_world(_held_data["item"], _held_data["count"])
		_clear_held()


func _update_held_position(pos: Vector2) -> void:
	_held_icon.position = pos - Vector2(ICON_SIZE / 2.0, ICON_SIZE / 2.0)
	_held_label.position = pos + Vector2(-ICON_SIZE / 2.0, ICON_SIZE / 2.0 - 4)


func _clear_held() -> void:
	_held_data = null
	_held_icon.visible = false
	_held_icon.texture = null
	_held_label.visible = false
	_held_label.text = ""


# ──────────────────────────────────────────────────────────────────────────────
#  CONTEXT MENU (right-click)
# ──────────────────────────────────────────────────────────────────────────────

func _open_context_menu(slot_index: int, pos: Vector2) -> void:
	var data = InventoryManager.get_slot(slot_index)
	if data == null:
		return

	_close_context_menu()
	_ctx_slot = slot_index

	var item : ItemData = data["item"]
	var count : int = data["count"]

	_ctx_menu = Panel.new()
	_ctx_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_ctx_menu)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.95)
	style.border_color = Color(0.55, 0.45, 0.30, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	_ctx_menu.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.position = Vector2(6, 6)
	col.add_theme_constant_override("separation", 4)
	_ctx_menu.add_child(col)

	# "Split Stack" — only if stackable and count > 1.
	if item.stackable and count > 1:
		var split_btn := Button.new()
		split_btn.text = "Split Stack"
		split_btn.custom_minimum_size = Vector2(120, 32)
		split_btn.pressed.connect(func() -> void:
			_close_context_menu()
			_open_split_dialog(slot_index, pos)
		)
		col.add_child(split_btn)

	# "Drop Stack".
	var drop_btn := Button.new()
	drop_btn.text = "Drop Stack" if count > 1 else "Drop"
	drop_btn.custom_minimum_size = Vector2(120, 32)
	drop_btn.pressed.connect(func() -> void:
		var taken = InventoryManager.take_slot(slot_index)
		if taken != null:
			_drop_to_world(taken["item"], taken["count"])
		_close_context_menu()
	)
	col.add_child(drop_btn)

	# Size the panel to fit its contents.
	var btn_count := col.get_child_count()
	var menu_w := 120.0 + 12.0
	var menu_h : float = btn_count * 36.0 + 12.0
	_ctx_menu.size = Vector2(menu_w, menu_h)

	# Position near the click, clamped to viewport.
	var vp_size := get_viewport().get_visible_rect().size
	var menu_pos := pos + Vector2(4, 4)
	menu_pos.x = minf(menu_pos.x, vp_size.x - menu_w)
	menu_pos.y = minf(menu_pos.y, vp_size.y - menu_h)
	_ctx_menu.position = menu_pos


func _close_context_menu() -> void:
	if _ctx_menu != null:
		_ctx_menu.queue_free()
		_ctx_menu = null
		_ctx_slot = -1


# ──────────────────────────────────────────────────────────────────────────────
#  SPLIT STACK DIALOG
# ──────────────────────────────────────────────────────────────────────────────

func _open_split_dialog(slot_index: int, pos: Vector2) -> void:
	var data = InventoryManager.get_slot(slot_index)
	if data == null:
		return
	var count : int = data["count"]
	if count < 2:
		return

	_close_split_dialog()
	_split_slot = slot_index

	_split_panel = Panel.new()
	_split_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_split_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.95)
	style.border_color = Color(0.55, 0.45, 0.30, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	_split_panel.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.position = Vector2(10, 8)
	col.add_theme_constant_override("separation", 6)
	_split_panel.add_child(col)

	var header := Label.new()
	header.text = "Split Stack"
	header.add_theme_font_size_override("font_size", 15)
	col.add_child(header)

	var half := count / 2
	_split_label = Label.new()
	_split_label.text = "Take: %d / %d" % [half, count]
	_split_label.add_theme_font_size_override("font_size", 14)
	col.add_child(_split_label)

	_split_slider = HSlider.new()
	_split_slider.min_value = 1
	_split_slider.max_value = count - 1
	_split_slider.step = 1
	_split_slider.value = half
	_split_slider.custom_minimum_size = Vector2(140, 20)
	_split_slider.value_changed.connect(func(v: float) -> void:
		_split_label.text = "Take: %d / %d" % [int(v), count]
	)
	col.add_child(_split_slider)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	col.add_child(btn_row)

	var ok_btn := Button.new()
	ok_btn.text = "OK"
	ok_btn.custom_minimum_size = Vector2(65, 28)
	ok_btn.pressed.connect(func() -> void:
		_do_split(slot_index, int(_split_slider.value))
	)
	btn_row.add_child(ok_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(65, 28)
	cancel_btn.pressed.connect(_close_split_dialog)
	btn_row.add_child(cancel_btn)

	_split_panel.size = Vector2(170, 120)

	# Position near the context menu click.
	var vp_size := get_viewport().get_visible_rect().size
	var panel_pos := pos + Vector2(4, 4)
	panel_pos.x = minf(panel_pos.x, vp_size.x - 170.0)
	panel_pos.y = minf(panel_pos.y, vp_size.y - 120.0)
	_split_panel.position = panel_pos


func _do_split(slot_index: int, take_count: int) -> void:
	var data = InventoryManager.get_slot(slot_index)
	if data == null:
		_close_split_dialog()
		return

	var item : ItemData = data["item"]
	var total : int = data["count"]
	var split_amount : int = clampi(take_count, 1, total - 1)

	# Reduce the source slot.
	data["count"] = total - split_amount
	InventoryManager.slot_changed.emit(slot_index)
	InventoryManager.inventory_changed.emit()

	# Pick up the split portion on the cursor.
	_held_data = { "item": item, "count": split_amount }
	_held_icon.texture = _get_icon(item)
	_held_icon.visible = true
	_held_label.text = str(split_amount) if split_amount > 1 else ""
	_held_label.visible = split_amount > 1

	_close_split_dialog()


func _close_split_dialog() -> void:
	if _split_panel != null:
		_split_panel.queue_free()
		_split_panel = null
		_split_slider = null
		_split_label = null
		_split_slot = -1


# ──────────────────────────────────────────────────────────────────────────────
#  DROP TO WORLD
# ──────────────────────────────────────────────────────────────────────────────

func _drop_to_world(item: ItemData, count: int) -> void:
	if _player_ref == null:
		return
	var scene := load("res://scenes/world/pickable_item.tscn") as PackedScene
	if scene == null:
		push_warning("InventoryUI: pickable_item.tscn not found.")
		return
	for i in count:
		var inst := scene.instantiate()
		inst.item_data = item
		# Drop 2m in front of the player, slightly randomised.
		var fwd := -_player_ref.global_transform.basis.z
		var offset := fwd * 2.0 + Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3))
		inst.global_position = _player_ref.global_position + offset
		_player_ref.get_parent().add_child(inst)
