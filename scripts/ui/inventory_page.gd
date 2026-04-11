extends Control

## Inventory page inside the InGameMenu.
## Contains a 6×5 item grid (30 slots) and equipment panel.

signal item_held(data: Variant)
signal item_cleared
signal drop_to_world(item_id: String, count: int)

const COLS      := 6
const ROWS      := 5
const SLOT_SIZE := 72
const SLOT_GAP  := 6
const ICON_SIZE := 60

var _player_ref  : Node3D = null
var _slot_panels : Array[Panel] = []
var _equip_panels: Dictionary = {}   # slot_name → Panel

var _held_data   : Variant = null
var _held_icon   : TextureRect = null
var _held_label  : Label = null

var _ctx_menu    : Panel = null
var _ctx_slot    : int   = -1

var _split_panel  : Panel   = null
var _split_slider : HSlider = null
var _split_label  : Label   = null
var _split_slot   : int     = -1

var _placeholder_cache : Dictionary = {}

const EQUIP_SLOTS : Array[String] = [
	"helm", "torso", "pants", "shoes", "left_hand", "right_hand", "neck"
]
const EQUIP_LABELS : Dictionary = {
	"helm": "Helm", "torso": "Rüstung", "pants": "Hose",
	"shoes": "Schuhe", "left_hand": "L. Hand", "right_hand": "R. Hand",
	"neck": "Hals",
}


func setup(player: Node3D, held_icon: TextureRect, held_label: Label) -> void:
	_player_ref = player
	_held_icon = held_icon
	_held_label = held_label
	var inv: Node = player.get_node("Inventory")
	if not inv.slot_changed.is_connected(_on_slot_changed):
		inv.slot_changed.connect(_on_slot_changed)


func refresh() -> void:
	_refresh_all_slots()
	_refresh_equipment()


func on_menu_close() -> void:
	_close_context_menu()
	_close_split_dialog()
	if _held_data != null:
		var inv: Node = _player_ref.get_node("Inventory")
		var leftover: int = inv.add_item(_load_item(_held_data["id"]), _held_data["count"])
		if leftover > 0:
			drop_to_world.emit(_held_data["id"], leftover)
		_clear_held()


func get_held_data() -> Variant:
	return _held_data


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Title
	var title := Label.new()
	title.text = "Inventar"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.position = Vector2(16, 8)
	title.size = Vector2(200, 28)
	title.add_theme_font_size_override("font_size", UITheme.TITLE_SIZE)
	title.add_theme_color_override("font_color", UITheme.TEXT_TITLE)
	add_child(title)

	# Inventory grid (left side)
	var grid_w : float = COLS * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP
	var grid := Control.new()
	grid.position = Vector2(16, 44)
	grid.size = Vector2(grid_w, ROWS * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP)
	add_child(grid)

	for i in 30:
		var slot := _create_slot(i)
		grid.add_child(slot)
		_slot_panels.append(slot)

	# Equipment panel (right side)
	var equip_x : float = 16 + grid_w + 24
	_build_equipment_panel(equip_x, 44)


func _build_equipment_panel(start_x: float, start_y: float) -> void:
	var equip_title := Label.new()
	equip_title.text = "Ausrüstung"
	equip_title.position = Vector2(start_x, start_y - 36)
	equip_title.size = Vector2(300, 28)
	equip_title.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	equip_title.add_theme_color_override("font_color", UITheme.TEXT_TITLE)
	add_child(equip_title)

	# Layout: centered character silhouette-style
	var slot_w := 68.0
	var slot_h := 68.0
	var gap := 10.0
	var center_x := start_x + 130.0
	var row_h := slot_h + gap

	var positions : Dictionary = {
		"helm":       Vector2(center_x - slot_w / 2, start_y),
		"neck":       Vector2(center_x + slot_w / 2 + gap, start_y + row_h * 0.5),
		"torso":      Vector2(center_x - slot_w / 2, start_y + row_h),
		"left_hand":  Vector2(center_x - slot_w / 2 - slot_w - gap, start_y + row_h),
		"right_hand": Vector2(center_x + slot_w / 2 + gap, start_y + row_h),
		"pants":      Vector2(center_x - slot_w / 2, start_y + row_h * 2),
		"shoes":      Vector2(center_x - slot_w / 2, start_y + row_h * 3),
	}

	for slot_name in EQUIP_SLOTS:
		var pos : Vector2 = positions.get(slot_name, Vector2.ZERO)
		var panel := Panel.new()
		panel.position = pos
		panel.size = Vector2(slot_w, slot_h)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_equip_input.bind(slot_name))

		var style := UITheme.make_slot_style(UITheme.SLOT_BG, UITheme.SLOT_EQUIP_BORDER)
		panel.add_theme_stylebox_override("panel", style)
		add_child(panel)

		# Slot label
		var lbl := Label.new()
		lbl.name = "SlotLabel"
		lbl.text = EQUIP_LABELS[slot_name]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(0, 0)
		lbl.size = Vector2(slot_w, slot_h)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", UITheme.TEXT_DIMMED)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(lbl)

		# Icon
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2((slot_w - ICON_SIZE) / 2.0, (slot_h - ICON_SIZE) / 2.0)
		icon.size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)

		_equip_panels[slot_name] = panel


func _create_slot(index: int) -> Panel:
	var col := index % COLS
	var row := index / COLS
	var panel := Panel.new()
	panel.position = Vector2(col * (SLOT_SIZE + SLOT_GAP), row * (SLOT_SIZE + SLOT_GAP))
	panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_slot_input.bind(index))

	var style := UITheme.make_slot_style()
	panel.add_theme_stylebox_override("panel", style)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2((SLOT_SIZE - ICON_SIZE) / 2.0, (SLOT_SIZE - ICON_SIZE) / 2.0 - 4)
	icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)

	var lbl := Label.new()
	lbl.name = "Count"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.position = Vector2(4, 4)
	lbl.size = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
	lbl.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)

	return panel


# ── Slot rendering ───────────────────────────────────────────────────────────

func _refresh_all_slots() -> void:
	if _player_ref == null:
		return
	for i in _player_ref.get_node("Inventory").SLOT_COUNT:
		_refresh_slot(i)


func _refresh_slot(index: int) -> void:
	if index < 0 or index >= _slot_panels.size() or _player_ref == null:
		return
	var panel := _slot_panels[index]
	var icon := panel.get_node("Icon") as TextureRect
	var lbl := panel.get_node("Count") as Label
	var data = _player_ref.get_node("Inventory").get_slot(index)

	if data == null:
		icon.texture = null
		lbl.text = ""
	else:
		var item : ItemData = _load_item(data["id"])
		icon.texture = _get_icon(item)
		lbl.text = str(data["count"]) if data["count"] > 1 else ""


func _on_slot_changed(index: int) -> void:
	if visible:
		_refresh_slot(index)


func _refresh_equipment() -> void:
	if _player_ref == null:
		return
	var inv: Node = _player_ref.get_node("Inventory")
	if not inv.has_method("get_equipment_slot"):
		return
	for slot_name in EQUIP_SLOTS:
		var panel: Panel = _equip_panels[slot_name]
		var icon := panel.get_node("Icon") as TextureRect
		var label := panel.get_node("SlotLabel") as Label
		var data = inv.get_equipment_slot(slot_name)
		if data == null:
			icon.texture = null
			label.visible = true
		else:
			var item := _load_item(data["id"])
			icon.texture = _get_icon(item)
			label.visible = false


# ── Input ────────────────────────────────────────────────────────────────────

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

	var inv: Node = _player_ref.get_node("Inventory")
	if _held_data == null:
		var data = inv.take_slot(index)
		if data != null:
			_held_data = {"id": data["id"], "count": data["count"]}
			_held_icon.texture = _get_icon(_load_item(data["id"]))
			_held_icon.visible = true
			_held_label.text = str(data["count"]) if data["count"] > 1 else ""
			_held_label.visible = data["count"] > 1
			_update_held_position(event.global_position)
			item_held.emit(_held_data)
	else:
		var put_data : Dictionary = {"id": _held_data["id"], "count": _held_data["count"]}
		var returned = inv.put_slot(index, put_data)
		if returned == null:
			_clear_held()
		else:
			_held_data = {"id": returned["id"], "count": returned["count"]}
			_held_icon.texture = _get_icon(_load_item(returned["id"]))
			_held_label.text = str(returned["count"]) if returned["count"] > 1 else ""
			_held_label.visible = returned["count"] > 1


func _on_equip_input(event: InputEvent, slot_name: String) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	var inv: Node = _player_ref.get_node("Inventory")
	if not inv.has_method("get_equipment_slot"):
		return

	if _held_data == null:
		# Unequip
		if inv.get_equipment_slot(slot_name) != null:
			inv.unequip_item(slot_name)
			_refresh_equipment()
			_refresh_all_slots()
	else:
		# Equip
		var item := _load_item(_held_data["id"])
		if item.get("equip_type") != null and item.equip_type != "none":
			var target_slots := _get_target_equip_slots(item.equip_type)
			if slot_name in target_slots:
				# Put held item into equipment
				inv.equip_from_data(slot_name, _held_data["id"])
				_clear_held()
				_refresh_equipment()
				_refresh_all_slots()


func _get_target_equip_slots(equip_type: String) -> Array[String]:
	match equip_type:
		"helm": return ["helm"]
		"torso": return ["torso"]
		"pants": return ["pants"]
		"shoes": return ["shoes"]
		"hand": return ["left_hand", "right_hand"]
		"two_hand": return ["left_hand", "right_hand"]
		"neck": return ["neck"]
	return []


func handle_bg_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
		_close_context_menu()
		_close_split_dialog()
	if event.button_index == MOUSE_BUTTON_LEFT and _held_data != null:
		drop_to_world.emit(_held_data["id"], _held_data["count"])
		_clear_held()


func update_held_position(pos: Vector2) -> void:
	_update_held_position(pos)


func _update_held_position(pos: Vector2) -> void:
	if _held_icon == null:
		return
	_held_icon.position = pos - Vector2(ICON_SIZE / 2.0, ICON_SIZE / 2.0)
	_held_label.position = pos + Vector2(-ICON_SIZE / 2.0, ICON_SIZE / 2.0 - 4)


func _clear_held() -> void:
	_held_data = null
	if _held_icon:
		_held_icon.visible = false
		_held_icon.texture = null
	if _held_label:
		_held_label.visible = false
		_held_label.text = ""
	item_cleared.emit()


# ── Context menu ─────────────────────────────────────────────────────────────

func _open_context_menu(slot_index: int, pos: Vector2) -> void:
	var inv: Node = _player_ref.get_node("Inventory")
	var data = inv.get_slot(slot_index)
	if data == null:
		return
	_close_context_menu()
	_ctx_slot = slot_index

	var item : ItemData = _load_item(data["id"])
	var count : int = data["count"]

	_ctx_menu = Panel.new()
	_ctx_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	# Add to root of the InGameMenu so it's above everything
	var root := get_parent().get_parent().get_parent()  # Content -> Panel -> Root
	root.add_child(_ctx_menu)

	var style := UITheme.make_panel_style(UITheme.CTX_BG)
	_ctx_menu.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.position = Vector2(6, 6)
	col.add_theme_constant_override("separation", 4)
	_ctx_menu.add_child(col)

	if item.stackable and count > 1:
		var split_btn := Button.new()
		split_btn.text = "Stack teilen"
		split_btn.custom_minimum_size = Vector2(120, 32)
		split_btn.pressed.connect(func() -> void:
			_close_context_menu()
			_open_split_dialog(slot_index, pos)
		)
		col.add_child(split_btn)

	var drop_btn := Button.new()
	drop_btn.text = "Ablegen" if count <= 1 else "Stack ablegen"
	drop_btn.custom_minimum_size = Vector2(120, 32)
	drop_btn.pressed.connect(func() -> void:
		var taken = inv.take_slot(slot_index)
		if taken != null:
			drop_to_world.emit(taken["id"], taken["count"])
		_close_context_menu()
	)
	col.add_child(drop_btn)

	var btn_count := col.get_child_count()
	var menu_w := 132.0
	var menu_h : float = btn_count * 36.0 + 12.0
	_ctx_menu.size = Vector2(menu_w, menu_h)

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


# ── Split stack dialog ───────────────────────────────────────────────────────

func _open_split_dialog(slot_index: int, pos: Vector2) -> void:
	var inv: Node = _player_ref.get_node("Inventory")
	var data = inv.get_slot(slot_index)
	if data == null:
		return
	var count : int = data["count"]
	if count < 2:
		return
	_close_split_dialog()
	_split_slot = slot_index

	_split_panel = Panel.new()
	_split_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var root := get_parent().get_parent().get_parent()
	root.add_child(_split_panel)

	var style := UITheme.make_panel_style(UITheme.CTX_BG)
	_split_panel.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.position = Vector2(10, 8)
	col.add_theme_constant_override("separation", 6)
	_split_panel.add_child(col)

	var header := Label.new()
	header.text = "Stack teilen"
	header.add_theme_font_size_override("font_size", 15)
	col.add_child(header)

	var half := count / 2
	_split_label = Label.new()
	_split_label.text = "Nehmen: %d / %d" % [half, count]
	_split_label.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	col.add_child(_split_label)

	_split_slider = HSlider.new()
	_split_slider.min_value = 1
	_split_slider.max_value = count - 1
	_split_slider.step = 1
	_split_slider.value = half
	_split_slider.custom_minimum_size = Vector2(140, 20)
	_split_slider.value_changed.connect(func(v: float) -> void:
		_split_label.text = "Nehmen: %d / %d" % [int(v), count]
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
	cancel_btn.text = "Abbrechen"
	cancel_btn.custom_minimum_size = Vector2(65, 28)
	cancel_btn.pressed.connect(_close_split_dialog)
	btn_row.add_child(cancel_btn)

	_split_panel.size = Vector2(170, 120)
	var vp_size := get_viewport().get_visible_rect().size
	var panel_pos := pos + Vector2(4, 4)
	panel_pos.x = minf(panel_pos.x, vp_size.x - 170.0)
	panel_pos.y = minf(panel_pos.y, vp_size.y - 120.0)
	_split_panel.position = panel_pos


func _do_split(slot_index: int, take_count: int) -> void:
	var inv: Node = _player_ref.get_node("Inventory")
	var data = inv.get_slot(slot_index)
	if data == null:
		_close_split_dialog()
		return
	var item : ItemData = _load_item(data["id"])
	var total : int = data["count"]
	var split_amount : int = clampi(take_count, 1, total - 1)

	data["count"] = total - split_amount
	inv.slot_changed.emit(slot_index)
	inv.inventory_changed.emit()

	_held_data = {"id": item.id, "count": split_amount}
	_held_icon.texture = _get_icon(item)
	_held_icon.visible = true
	_held_label.text = str(split_amount) if split_amount > 1 else ""
	_held_label.visible = split_amount > 1
	item_held.emit(_held_data)

	_close_split_dialog()


func _close_split_dialog() -> void:
	if _split_panel != null:
		_split_panel.queue_free()
		_split_panel = null
		_split_slider = null
		_split_label = null
		_split_slot = -1


# ── Helpers ──────────────────────────────────────────────────────────────────

func _load_item(item_id: String) -> ItemData:
	return load("res://data/items/" + item_id + ".tres") as ItemData


func _get_icon(item: ItemData) -> Texture2D:
	if item.icon != null:
		return item.icon
	if _placeholder_cache.has(item.id):
		return _placeholder_cache[item.id]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(item.mesh_color)
	var border_col := item.mesh_color.darkened(0.4)
	for x in 64:
		for y in 64:
			if x < 3 or x >= 61 or y < 3 or y >= 61:
				img.set_pixel(x, y, border_col)
	var tex := ImageTexture.create_from_image(img)
	_placeholder_cache[item.id] = tex
	return tex
