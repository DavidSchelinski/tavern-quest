extends CanvasLayer

signal closed

# ── Layout constants ──────────────────────────────────────────────────────────
const COLS      := 6
const ROWS      := 5
const SLOT_SIZE := 72
const SLOT_GAP  := 6
const ICON_SIZE := 60
const PAD       := 16
const TAB_H     := 38   # height of the tab strip

# ── Shared ────────────────────────────────────────────────────────────────────
var _root        : Control
var _tab_btns    : Array[Button] = []
var _pages       : Array[Control] = []
var _current_tab : int = 0
var _player_ref  : Node3D = null

# ── Inventory page ────────────────────────────────────────────────────────────
var _grid        : Control
var _slot_panels : Array[Panel] = []
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

# ── Skill page ───────────────────────────────────────────────────────────────
var _skill_map_inst : Node = null

# ── Character page ────────────────────────────────────────────────────────────
var _stat_points_label : Label      = null
var _stat_val_labels   : Dictionary = {}   # stat → Label
var _stat_plus_btns    : Dictionary = {}   # stat → Button
var _derived_labels    : Dictionary = {}   # key  → Label

# ── Quest page ────────────────────────────────────────────────────────────────
var _quest_list_box     : VBoxContainer = null   # left column entries
var _quest_detail_panel : Control       = null   # right column
var _detail_title       : Label         = null
var _detail_rank        : Label         = null
var _detail_giver       : Label         = null
var _detail_desc        : RichTextLabel = null
var _detail_reward      : Label         = null
var _detail_status      : Label         = null
var _selected_quest     : Dictionary    = {}
var _quest_entry_btns   : Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	get_parent().get_node("Inventory").slot_changed.connect(_on_slot_changed)
	get_parent().get_node("Stats").stats_changed.connect(_on_stats_changed)
	get_parent().get_node("Quests").quests_changed.connect(_on_quests_changed)


# ──────────────────────────────────────────────────────────────────────────────
#  PUBLIC
# ──────────────────────────────────────────────────────────────────────────────

func open(player: Node3D) -> void:
	_player_ref = player
	if _skill_map_inst != null and _skill_map_inst.has_method("setup"):
		_skill_map_inst.setup(_player_ref)
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_switch_tab(_current_tab)


func close() -> void:
	_close_context_menu()
	_close_split_dialog()
	if _held_data != null:
		var leftover: int = get_parent().get_node("Inventory").add_item(_load_item(_held_data["id"]), _held_data["count"])
		if leftover > 0:
			_drop_to_world(_held_data["id"], leftover)
		_clear_held()
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	closed.emit()


# ──────────────────────────────────────────────────────────────────────────────
#  BUILD UI – root + outer panel + tabs
# ──────────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Semi-transparent backdrop.
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.35)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_bg_input)
	_root.add_child(bg)

	# Panel dimensions.
	var grid_w : float = COLS * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP   # 462
	var grid_h : float = ROWS * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP   # 384
	var panel_w : float = 900.0
	var content_h : float = 600.0
	var panel_h : float = content_h + TAB_H                          # 494

	# Outer panel.
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position  = Vector2(-panel_w / 2.0, -panel_h / 2.0)
	panel.size      = Vector2(panel_w, panel_h)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var outer_style := _make_panel_style(Color(0.10, 0.08, 0.07, 0.96))
	panel.add_theme_stylebox_override("panel", outer_style)
	_root.add_child(panel)

	# Tab strip (inside the outer panel, at the top).
	_build_tab_strip(panel, panel_w)

	# Thin separator line below tab strip.
	var line := ColorRect.new()
	line.position = Vector2(0, TAB_H)
	line.size     = Vector2(panel_w, 1)
	line.color    = Color(0.55, 0.45, 0.30, 0.5)
	panel.add_child(line)

	# Content area (below tabs).
	var content := Control.new()
	content.position = Vector2(0, TAB_H + 1)
	content.size     = Vector2(panel_w, content_h)
	panel.add_child(content)

	# Page 0 – Inventory.
	var inv_page := Control.new()
	inv_page.size = Vector2(panel_w, content_h)
	content.add_child(inv_page)
	_pages.append(inv_page)
	_build_inventory_page(inv_page, panel_w, grid_w, grid_h)

	# Page 1 – Quests.
	var quest_page := Control.new()
	quest_page.size = Vector2(panel_w, content_h)
	content.add_child(quest_page)
	_pages.append(quest_page)
	_build_quest_page(quest_page, panel_w, content_h)

	# Page 2 – Character.
	var char_page := Control.new()
	char_page.size = Vector2(panel_w, content_h)
	content.add_child(char_page)
	_pages.append(char_page)
	_build_character_page(char_page, panel_w, content_h)

	# Page 3 – Skills.
	var skill_page := Control.new()
	skill_page.size = Vector2(panel_w, content_h)
	content.add_child(skill_page)
	_pages.append(skill_page)
	_build_skill_page(skill_page, panel_w, content_h)

	# Floating held-item icon (above everything, on _root).
	_held_icon = TextureRect.new()
	_held_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_held_icon.size         = Vector2(ICON_SIZE, ICON_SIZE)
	_held_icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_held_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_held_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_icon.visible      = false
	_root.add_child(_held_icon)

	_held_label = Label.new()
	_held_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_held_label.size = Vector2(ICON_SIZE, 20)
	_held_label.add_theme_font_size_override("font_size", 14)
	_held_label.add_theme_color_override("font_color", Color.WHITE)
	_held_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_label.visible = false
	_root.add_child(_held_label)


# ── Tab strip ──────────────────────────────────────────────────────────────────

func _build_tab_strip(parent: Control, panel_w: float) -> void:
	var labels := ["Inventar", "Quests", "Charakter", "Skills"]
	var tab_w  := panel_w / labels.size()

	for i in labels.size():
		var btn := Button.new()
		btn.text     = labels[i]
		btn.position = Vector2(i * tab_w, 0)
		btn.size     = Vector2(tab_w, TAB_H)
		btn.add_theme_font_size_override("font_size", 15)
		btn.flat = true
		var idx := i   # capture for closure
		btn.pressed.connect(func() -> void: _switch_tab(idx))
		parent.add_child(btn)
		_tab_btns.append(btn)


func _switch_tab(index: int) -> void:
	_current_tab = index
	for i in _pages.size():
		_pages[i].visible = (i == index)
	_apply_tab_styles()
	match index:
		0: _refresh_all_slots()
		1: _refresh_quest_page()
		2: _refresh_character_page()
		3:
			if _pages[3].has_method("refresh_ui"):
				_pages[3].refresh_ui()


func _apply_tab_styles() -> void:
	for i in _tab_btns.size():
		var btn    := _tab_btns[i]
		var active := (i == _current_tab)

		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.20, 0.16, 0.12, 1.0) if active else Color(0.10, 0.08, 0.07, 0.0)
		s.set_border_width_all(0)
		s.border_width_bottom = 2 if active else 0
		s.border_color = Color(0.75, 0.60, 0.35, 1.0)
		s.set_corner_radius_all(0)
		btn.add_theme_stylebox_override("normal",  s)
		btn.add_theme_stylebox_override("hover",   s)
		btn.add_theme_stylebox_override("pressed", s)
		btn.add_theme_stylebox_override("focus",   s)

		var col := Color(0.95, 0.78, 0.45, 1.0) if active else Color(0.58, 0.54, 0.48, 1.0)
		btn.add_theme_color_override("font_color",       col)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.60, 1.0))


# ──────────────────────────────────────────────────────────────────────────────
#  BUILD – QUEST PAGE
# ──────────────────────────────────────────────────────────────────────────────

const QUEST_LIST_W  : float = 172.0   # width of the left list column
const QUEST_COL_GAP : float = 8.0

const RANK_COLORS : Dictionary = {
	"F": Color(0.60, 0.60, 0.60, 1.0),
	"E": Color(0.35, 0.80, 0.35, 1.0),
	"D": Color(0.35, 0.55, 0.95, 1.0),
	"C": Color(0.95, 0.60, 0.20, 1.0),
	"B": Color(0.90, 0.25, 0.25, 1.0),
	"A": Color(0.75, 0.30, 0.95, 1.0),
	"S": Color(0.95, 0.80, 0.10, 1.0),
}


func _build_quest_page(page: Control, panel_w: float, page_h: float) -> void:
	var p : float = PAD

	# ── Page title ──
	var title := Label.new()
	title.text     = "Questtagebuch"
	title.position = Vector2(p, 8.0)
	title.size     = Vector2(panel_w - p * 2.0, 28.0)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.90, 0.75, 0.45, 1.0))
	page.add_child(title)

	var content_y : float = 40.0
	var content_h : float = page_h - content_y - p

	# ── Left: scrollable quest list ──
	var scroll := ScrollContainer.new()
	scroll.position                          = Vector2(p, content_y)
	scroll.size                              = Vector2(QUEST_LIST_W, content_h)
	scroll.vertical_scroll_mode             = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode           = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	_quest_list_box = VBoxContainer.new()
	_quest_list_box.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	_quest_list_box.add_theme_constant_override("separation", 3)
	scroll.add_child(_quest_list_box)

	# ── Vertical divider ──
	var div := ColorRect.new()
	div.position = Vector2(p + QUEST_LIST_W + QUEST_COL_GAP * 0.5 - 1.0, content_y)
	div.size     = Vector2(1.0, content_h)
	div.color    = Color(0.45, 0.38, 0.28, 0.50)
	page.add_child(div)

	# ── Right: detail panel ──
	var detail_x : float = p + QUEST_LIST_W + QUEST_COL_GAP
	var detail_w : float = panel_w - detail_x - p
	_quest_detail_panel = Control.new()
	_quest_detail_panel.position = Vector2(detail_x, content_y)
	_quest_detail_panel.size     = Vector2(detail_w, content_h)
	page.add_child(_quest_detail_panel)
	_build_quest_detail_panel(_quest_detail_panel, detail_w, content_h)


func _build_quest_detail_panel(parent: Control, w: float, h: float) -> void:
	# Empty-state hint (shown when nothing is selected).
	var hint := Label.new()
	hint.name                    = "EmptyHint"
	hint.text                    = "← Quest auswählen"
	hint.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment      = VERTICAL_ALIGNMENT_CENTER
	hint.position                = Vector2(0.0, 0.0)
	hint.size                    = Vector2(w, h)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.45, 0.42, 0.38, 1.0))
	hint.autowrap_mode           = TextServer.AUTOWRAP_WORD
	parent.add_child(hint)

	var dp : float = 8.0   # detail inner padding

	# Rank badge.
	_detail_rank = Label.new()
	_detail_rank.position = Vector2(dp, dp)
	_detail_rank.size     = Vector2(48.0, 28.0)
	_detail_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_rank.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_detail_rank.add_theme_font_size_override("font_size", 15)
	_detail_rank.visible = false
	var rank_style := StyleBoxFlat.new()
	rank_style.bg_color = Color(0.18, 0.14, 0.10, 0.9)
	rank_style.set_border_width_all(2)
	rank_style.set_corner_radius_all(4)
	rank_style.border_color = Color(0.55, 0.45, 0.30, 1.0)
	_detail_rank.add_theme_stylebox_override("normal", rank_style)
	parent.add_child(_detail_rank)

	# Quest title.
	_detail_title = Label.new()
	_detail_title.position      = Vector2(dp + 56.0, dp)
	_detail_title.size          = Vector2(w - dp - 56.0, 28.0)
	_detail_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_title.clip_text     = true
	_detail_title.add_theme_font_size_override("font_size", 16)
	_detail_title.add_theme_color_override("font_color", Color(0.92, 0.82, 0.55, 1.0))
	_detail_title.visible = false
	parent.add_child(_detail_title)

	# Separator.
	var sep := ColorRect.new()
	sep.name     = "DetailSep"
	sep.position = Vector2(dp, dp + 34.0)
	sep.size     = Vector2(w - dp * 2.0, 1.0)
	sep.color    = Color(0.45, 0.38, 0.28, 0.40)
	sep.visible  = false
	parent.add_child(sep)

	# Giver.
	_detail_giver = Label.new()
	_detail_giver.position = Vector2(dp, dp + 42.0)
	_detail_giver.size     = Vector2(w - dp * 2.0, 20.0)
	_detail_giver.add_theme_font_size_override("font_size", 13)
	_detail_giver.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50, 1.0))
	_detail_giver.visible = false
	parent.add_child(_detail_giver)

	# Description.
	_detail_desc = RichTextLabel.new()
	_detail_desc.position         = Vector2(dp, dp + 68.0)
	_detail_desc.size             = Vector2(w - dp * 2.0, h - dp - 68.0 - 58.0)
	_detail_desc.bbcode_enabled   = false
	_detail_desc.scroll_active    = true
	_detail_desc.autowrap_mode    = TextServer.AUTOWRAP_WORD
	_detail_desc.add_theme_font_size_override("normal_font_size", 13)
	_detail_desc.add_theme_color_override("default_color", Color(0.82, 0.78, 0.70, 1.0))
	_detail_desc.visible = false
	parent.add_child(_detail_desc)

	# Reward row.
	_detail_reward = Label.new()
	_detail_reward.position      = Vector2(dp, h - dp - 50.0)
	_detail_reward.size          = Vector2(w - dp * 2.0, 22.0)
	_detail_reward.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_reward.add_theme_font_size_override("font_size", 13)
	_detail_reward.add_theme_color_override("font_color", Color(0.45, 0.82, 0.45, 1.0))
	_detail_reward.visible = false
	parent.add_child(_detail_reward)

	# Status badge.
	_detail_status = Label.new()
	_detail_status.position              = Vector2(dp, h - dp - 24.0)
	_detail_status.size                  = Vector2(w - dp * 2.0, 20.0)
	_detail_status.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	_detail_status.add_theme_font_size_override("font_size", 12)
	_detail_status.visible = false
	parent.add_child(_detail_status)


# ── QUEST PAGE REFRESH ────────────────────────────────────────────────────────

func _on_quests_changed() -> void:
	if visible and _current_tab == 1:
		_refresh_quest_page()


func _refresh_quest_page() -> void:
	if _quest_list_box == null:
		return

	# Clear ALL children (labels, buttons, spacers).
	for child in _quest_list_box.get_children():
		child.queue_free()
	_quest_entry_btns.clear()

	var active    : Array[Dictionary] = get_parent().get_node("Quests").get_active_quests()
	var completed : Array[Dictionary] = get_parent().get_node("Quests").get_completed_quests()

	if active.is_empty() and completed.is_empty():
		_add_list_placeholder("Noch keine Quests.\nBesuche das Quest-Board.")
		_clear_quest_detail()
		return

	if not active.is_empty():
		_add_list_header("Aktive Quests (%d)" % active.size())
		for q : Dictionary in active:
			_add_quest_entry(q, false)

	if not completed.is_empty():
		if not active.is_empty():
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0.0, 6.0)
			_quest_list_box.add_child(spacer)
			_quest_entry_btns.append(Button.new())   # dummy to track for cleanup
			_quest_entry_btns[-1].visible = false
		_add_list_header("Abgeschlossen (%d)" % completed.size())
		for q : Dictionary in completed:
			_add_quest_entry(q, true)

	# Re-select currently shown quest if it still exists.
	if not _selected_quest.is_empty():
		var id : String = _selected_quest.get("title_key", "") as String
		if get_parent().get_node("Quests").is_quest_active(id) or get_parent().get_node("Quests").is_quest_completed(id):
			_show_quest_detail(_selected_quest)
			return
	_clear_quest_detail()


func _add_list_placeholder(text: String) -> void:
	var lbl := Label.new()
	lbl.text          = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.50, 0.48, 0.44, 1.0))
	_quest_list_box.add_child(lbl)
	# Track via a hidden Button so cleanup stays uniform.
	var dummy := Button.new()
	dummy.visible = false
	_quest_list_box.add_child(dummy)
	_quest_entry_btns.append(dummy)


func _add_list_header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.58, 0.54, 0.47, 1.0))
	lbl.custom_minimum_size = Vector2(QUEST_LIST_W - 8.0, 18.0)
	_quest_list_box.add_child(lbl)
	var dummy := Button.new()
	dummy.visible = false
	_quest_list_box.add_child(dummy)
	_quest_entry_btns.append(dummy)


func _add_quest_entry(quest: Dictionary, is_completed: bool) -> void:
	var rank  : String = quest.get("rank", "?") as String
	var title : String = tr(quest.get("title_key", "") as String)

	var btn := Button.new()
	btn.text                  = "[%s] %s" % [rank, title]
	btn.clip_text             = true
	btn.alignment             = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size   = Vector2(QUEST_LIST_W - 8.0, 30.0)
	btn.flat                  = false

	var rank_col : Color = RANK_COLORS.get(rank, Color.WHITE) as Color
	if is_completed:
		rank_col = rank_col.lerp(Color(0.5, 0.5, 0.5, 1.0), 0.55)

	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.15, 0.12, 0.10, 0.70)
	s.border_color = rank_col.darkened(0.2)
	s.set_border_width_all(1)
	s.border_width_left = 3
	s.border_color      = rank_col
	s.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", s)

	var s_hover := s.duplicate() as StyleBoxFlat
	s_hover.bg_color = Color(0.22, 0.18, 0.14, 0.90)
	btn.add_theme_stylebox_override("hover", s_hover)

	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color",
		Color(0.65, 0.62, 0.56, 1.0) if is_completed else Color(0.88, 0.84, 0.72, 1.0))

	btn.pressed.connect(func() -> void: _show_quest_detail(quest))
	_quest_list_box.add_child(btn)
	_quest_entry_btns.append(btn)


func _show_quest_detail(quest: Dictionary) -> void:
	_selected_quest = quest
	var quest_id : String = quest.get("title_key", "") as String
	var is_done  : bool   = get_parent().get_node("Quests").is_quest_completed(quest_id)
	var rank     : String = quest.get("rank", "?") as String

	# Hide empty hint.
	var hint := _quest_detail_panel.get_node_or_null("EmptyHint") as Label
	if hint:
		hint.visible = false

	# Rank badge.
	_detail_rank.text    = rank
	_detail_rank.visible = true
	var rank_col : Color = RANK_COLORS.get(rank, Color.WHITE) as Color
	_detail_rank.add_theme_color_override("font_color", rank_col)

	# Title.
	_detail_title.text    = tr(quest_id)
	_detail_title.visible = true

	# Separator.
	var sep := _quest_detail_panel.get_node_or_null("DetailSep")
	if sep:
		sep.visible = true

	# Giver.
	_detail_giver.text    = "Auftraggeber: " + tr(quest.get("giver_key", "") as String)
	_detail_giver.visible = true

	# Description.
	_detail_desc.text    = tr(quest.get("desc_key", "") as String)
	_detail_desc.visible = true

	# Reward.
	_detail_reward.text    = "Belohnung: " + tr(quest.get("reward_key", "") as String)
	_detail_reward.visible = true

	# Status.
	if is_done:
		_detail_status.text = "✓ Abgeschlossen"
		_detail_status.add_theme_color_override("font_color", Color(0.45, 0.80, 0.45, 1.0))
	else:
		_detail_status.text = "● Aktiv"
		_detail_status.add_theme_color_override("font_color", Color(0.90, 0.75, 0.25, 1.0))
	_detail_status.visible = true


func _clear_quest_detail() -> void:
	_selected_quest = {}
	var hint := _quest_detail_panel.get_node_or_null("EmptyHint") as Label
	if hint:
		hint.visible = true
	if _detail_rank:   _detail_rank.visible   = false
	if _detail_title:  _detail_title.visible  = false
	if _detail_giver:  _detail_giver.visible  = false
	if _detail_desc:   _detail_desc.visible   = false
	if _detail_reward: _detail_reward.visible = false
	if _detail_status: _detail_status.visible = false
	var sep := _quest_detail_panel.get_node_or_null("DetailSep")
	if sep:
		sep.visible = false


# ──────────────────────────────────────────────────────────────────────────────
#  BUILD – INVENTORY PAGE
# ──────────────────────────────────────────────────────────────────────────────

func _build_inventory_page(page: Control, panel_w: float, grid_w: float, grid_h: float) -> void:
	var title := Label.new()
	title.text = "Inventar"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 8)
	title.size     = Vector2(panel_w, 28)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.90, 0.75, 0.45, 1.0))
	page.add_child(title)

	_grid = Control.new()
	_grid.position = Vector2((panel_w - grid_w) / 2.0, 40)
	_grid.size     = Vector2(grid_w, grid_h)
	page.add_child(_grid)

	for i in get_parent().get_node("Inventory").SLOT_COUNT:
		var slot := _create_slot(i)
		_grid.add_child(slot)
		_slot_panels.append(slot)


func _create_slot(index: int) -> Panel:
	var col := index % COLS
	var row := index / COLS
	var panel := Panel.new()
	panel.position = Vector2(col * (SLOT_SIZE + SLOT_GAP), row * (SLOT_SIZE + SLOT_GAP))
	panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_slot_input.bind(index))

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.15, 0.12, 0.10, 0.85)
	style.border_color = Color(0.55, 0.45, 0.30, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var icon := TextureRect.new()
	icon.name         = "Icon"
	icon.position     = Vector2((SLOT_SIZE - ICON_SIZE) / 2.0, (SLOT_SIZE - ICON_SIZE) / 2.0 - 4)
	icon.size         = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)

	var lbl := Label.new()
	lbl.name                       = "Count"
	lbl.horizontal_alignment       = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment         = VERTICAL_ALIGNMENT_BOTTOM
	lbl.position = Vector2(4, 4)
	lbl.size     = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)

	return panel


# ──────────────────────────────────────────────────────────────────────────────
#  BUILD – CHARACTER PAGE
# ──────────────────────────────────────────────────────────────────────────────

func _build_character_page(page: Control, panel_w: float, _page_h: float) -> void:
	var p  := 10.0   # inner padding
	var y  := p

	# ── Header: title + stat points ──
	var title := Label.new()
	title.text     = "Charakter"
	title.position = Vector2(p, y)
	title.size     = Vector2(220, 28)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.90, 0.75, 0.45, 1.0))
	page.add_child(title)

	_stat_points_label = Label.new()
	_stat_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stat_points_label.position = Vector2(panel_w * 0.45, y)
	_stat_points_label.size     = Vector2(panel_w * 0.5 - p, 28)
	_stat_points_label.add_theme_font_size_override("font_size", 14)
	_stat_points_label.add_theme_color_override("font_color", Color(0.45, 0.88, 0.45, 1.0))
	page.add_child(_stat_points_label)
	y += 34

	# ── Separator ──
	page.add_child(_make_hsep(p, y, panel_w - p * 2))
	y += 10

	# ── Section label ──
	page.add_child(_make_section_label("Primäre Attribute", p, y, panel_w - p * 2))
	y += 24

	# ── Stat rows ──
	var row_h := 38.0
	for stat in get_parent().get_node("Stats").STAT_NAMES:
		_build_stat_row(page, stat, p, y, panel_w - p * 2, row_h)
		y += row_h + 4

	y += 4

	# ── Separator ──
	page.add_child(_make_hsep(p, y, panel_w - p * 2))
	y += 10

	# ── Derived stats ──
	page.add_child(_make_section_label("Abgeleitete Werte", p, y, panel_w - p * 2))
	y += 24

	var derived_defs : Array[Array] = [
		["Max-HP",                  "max_hp"],
		["Schadensbonus",           "dmg_mult"],
		["Schadensreduktion",       "dmg_red"],
		["Bewegungstempo",          "speed"],
		["Angriffsgeschwindigkeit", "atk_speed"],
	]
	for def in derived_defs:
		_build_derived_row(page, def[0], def[1], p, y, panel_w - p * 2)
		y += 24

	y += 4
	page.add_child(_make_hsep(p, y, panel_w - p * 2))
	y += 10
	page.add_child(_make_section_label("Aktueller Status", p, y, panel_w - p * 2))
	y += 24
	var status_defs : Array[Array] = [
		["Aktuelle HP",  "current_hp"],
		["Ausdauer",     "current_stamina"],
	]
	for def in status_defs:
		_build_derived_row(page, def[0], def[1], p, y, panel_w - p * 2)
		y += 24


func _build_stat_row(parent: Control, stat: String,
					  x: float, y: float, w: float, h: float) -> void:
	# Background panel.
	var bg := Panel.new()
	bg.position = Vector2(x, y)
	bg.size     = Vector2(w, h)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color     = Color(0.15, 0.12, 0.10, 0.60)
	bg_style.border_color = Color(0.40, 0.32, 0.22, 0.50)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(3)
	bg.add_theme_stylebox_override("panel", bg_style)
	parent.add_child(bg)

	# Stat name.
	var name_lbl := Label.new()
	name_lbl.text               = get_parent().get_node("Stats").STAT_LABELS[stat]
	name_lbl.position           = Vector2(8, 0)
	name_lbl.size               = Vector2(155, h)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.72, 1.0))
	bg.add_child(name_lbl)

	# Current value.
	var val_lbl := Label.new()
	val_lbl.position              = Vector2(165, 0)
	val_lbl.size                  = Vector2(38, h)
	val_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 16)
	bg.add_child(val_lbl)
	_stat_val_labels[stat] = val_lbl

	# "+" button.
	var btn := Button.new()
	btn.text     = "+"
	btn.position = Vector2(207, (h - 26) / 2.0)
	btn.size     = Vector2(26, 26)
	btn.add_theme_font_size_override("font_size", 17)
	btn.pressed.connect(func() -> void: _on_spend_point(stat))
	bg.add_child(btn)
	_stat_plus_btns[stat] = btn

	# Description (clipped so it never overflows).
	var desc := Label.new()
	desc.text               = get_parent().get_node("Stats").STAT_DESC[stat]
	desc.position           = Vector2(240, 0)
	desc.size               = Vector2(w - 248, h)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc.clip_text          = true
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.55, 0.52, 0.47, 1.0))
	bg.add_child(desc)


func _build_derived_row(parent: Control, label: String, key: String,
						  x: float, y: float, w: float) -> void:
	var lbl := Label.new()
	lbl.text               = label + ":"
	lbl.position           = Vector2(x + 8, y)
	lbl.size               = Vector2(200, 22)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.68, 0.62, 0.54, 1.0))
	parent.add_child(lbl)

	var val := Label.new()
	val.position           = Vector2(x + 216, y)
	val.size               = Vector2(w - 224, 22)
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", Color(0.90, 0.82, 0.50, 1.0))
	parent.add_child(val)
	_derived_labels[key] = val


# ── Helper builders ───────────────────────────────────────────────────────────

func _make_hsep(x: float, y: float, w: float) -> ColorRect:
	var r := ColorRect.new()
	r.position = Vector2(x, y)
	r.size     = Vector2(w, 1)
	r.color    = Color(0.45, 0.38, 0.28, 0.50)
	return r


func _make_section_label(text: String, x: float, y: float, w: float) -> Label:
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = Vector2(x, y)
	lbl.size     = Vector2(w, 20)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.58, 0.54, 0.47, 1.0))
	return lbl


func _make_panel_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = Color(0.55, 0.45, 0.30, 1.0)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	return s


# ──────────────────────────────────────────────────────────────────────────────
#  CHARACTER PAGE – REFRESH
# ──────────────────────────────────────────────────────────────────────────────

func _on_stats_changed() -> void:
	if visible and _current_tab == 2:
		_refresh_character_page()


func _on_spend_point(stat: String) -> void:
	get_parent().get_node("Stats").spend_point(stat)


func _refresh_character_page() -> void:
	if _stat_points_label == null:
		return

	var pts: int = get_parent().get_node("Stats").stat_points
	if pts > 0:
		_stat_points_label.text = "✦ %d Statpunkt%s verfügbar" % [pts, "e" if pts != 1 else ""]
		_stat_points_label.add_theme_color_override("font_color", Color(0.45, 0.92, 0.45, 1.0))
	else:
		_stat_points_label.text = "Keine Statpunkte verfügbar"
		_stat_points_label.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50, 1.0))

	for stat in get_parent().get_node("Stats").STAT_NAMES:
		var val  : int = get_parent().get_node("Stats").stats[stat]
		var lbl  : Label  = _stat_val_labels[stat]
		var btn  : Button = _stat_plus_btns[stat]

		lbl.text = str(val)
		var col := Color(0.95, 0.75, 0.28, 1.0) if val > 1 else Color(0.82, 0.82, 0.82, 1.0)
		lbl.add_theme_color_override("font_color", col)

		btn.disabled = (pts <= 0)

	# Derived values.
	var dmg_pct := int((get_parent().get_node("Stats").get_damage_multiplier()      - 1.0) * 100.0)
	var spd_pct := int((get_parent().get_node("Stats").get_speed_multiplier()       - 1.0) * 100.0)
	var atk_pct := int((get_parent().get_node("Stats").get_attack_speed_multiplier()- 1.0) * 100.0)
	var red_pct := int(get_parent().get_node("Stats").get_damage_reduction()               * 100.0)
	var max_hp: int = get_parent().get_node("Stats").get_max_hp()

	_derived_labels["max_hp"  ].text = "%d HP" % max_hp
	_derived_labels["dmg_mult"].text = ("+%d %%" % dmg_pct) if dmg_pct > 0 else "–"
	_derived_labels["dmg_red" ].text = ("-%d %%" % red_pct) if red_pct > 0 else "–"
	_derived_labels["speed"   ].text = ("+%d %%" % spd_pct) if spd_pct > 0 else "–"
	_derived_labels["atk_speed"].text = ("+%d %%" % atk_pct) if atk_pct > 0 else "–"

	# Current status – read live values from player reference
	if _derived_labels.has("current_hp"):
		var hp_val = _player_ref.get("health") if _player_ref else null
		var cur_hp : float = float(hp_val) if hp_val != null else float(max_hp)
		_derived_labels["current_hp"].text = "%d / %d" % [int(cur_hp), max_hp]
	if _derived_labels.has("current_stamina"):
		var sta_val  = _player_ref.get("_stamina") if _player_ref else null
		var max_sta  = _player_ref.get("MAX_STAMINA") if _player_ref else null
		var cur_sta  : float = float(sta_val) if sta_val != null else 100.0
		var max_sta_f: float = float(max_sta) if max_sta != null else 100.0
		_derived_labels["current_stamina"].text = "%d / %d" % [int(cur_sta), int(max_sta_f)]


# ──────────────────────────────────────────────────────────────────────────────
#  HELPERS
# ──────────────────────────────────────────────────────────────────────────────

func _load_item(item_id: String) -> ItemData:
	return load("res://data/items/" + item_id + ".tres") as ItemData


# ──────────────────────────────────────────────────────────────────────────────
#  SLOT RENDERING
# ──────────────────────────────────────────────────────────────────────────────

func _refresh_all_slots() -> void:
	for i in get_parent().get_node("Inventory").SLOT_COUNT:
		_refresh_slot(i)


func _refresh_slot(index: int) -> void:
	if index < 0 or index >= _slot_panels.size():
		return
	var panel := _slot_panels[index]
	var icon  := panel.get_node("Icon") as TextureRect
	var lbl   := panel.get_node("Count") as Label
	var data  = get_parent().get_node("Inventory").get_slot(index)

	if data == null:
		icon.texture = null
		lbl.text     = ""
	else:
		var item : ItemData = _load_item(data["id"])
		icon.texture = _get_icon(item)
		lbl.text     = str(data["count"]) if data["count"] > 1 else ""


func _on_slot_changed(index: int) -> void:
	if visible:
		_refresh_slot(index)


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
		var data = get_parent().get_node("Inventory").take_slot(index)
		if data != null:
			_held_data = data
			_held_icon.texture = _get_icon(_load_item(data["id"]))
			_held_icon.visible = true
			_held_label.text   = str(data["count"]) if data["count"] > 1 else ""
			_held_label.visible = data["count"] > 1
			_update_held_position(event.global_position)
	else:
		var returned = get_parent().get_node("Inventory").put_slot(index, _held_data)
		if returned == null:
			_clear_held()
		else:
			_held_data = returned
			_held_icon.texture  = _get_icon(_load_item(returned["id"]))
			_held_label.text    = str(returned["count"]) if returned["count"] > 1 else ""
			_held_label.visible = returned["count"] > 1


func _on_bg_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		_close_context_menu()
		_close_split_dialog()
	if event.button_index == MOUSE_BUTTON_LEFT and _held_data != null:
		_drop_to_world(_held_data["id"], _held_data["count"])
		_clear_held()


func _update_held_position(pos: Vector2) -> void:
	_held_icon.position  = pos - Vector2(ICON_SIZE / 2.0, ICON_SIZE / 2.0)
	_held_label.position = pos + Vector2(-ICON_SIZE / 2.0, ICON_SIZE / 2.0 - 4)


func _clear_held() -> void:
	_held_data          = null
	_held_icon.visible  = false
	_held_icon.texture  = null
	_held_label.visible = false
	_held_label.text    = ""


# ──────────────────────────────────────────────────────────────────────────────
#  CONTEXT MENU
# ──────────────────────────────────────────────────────────────────────────────

func _open_context_menu(slot_index: int, pos: Vector2) -> void:
	var data = get_parent().get_node("Inventory").get_slot(slot_index)
	if data == null:
		return
	_close_context_menu()
	_ctx_slot = slot_index

	var item  : ItemData = _load_item(data["id"])
	var count : int      = data["count"]

	_ctx_menu = Panel.new()
	_ctx_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_ctx_menu)

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.12, 0.10, 0.08, 0.95)
	style.border_color = Color(0.55, 0.45, 0.30, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	_ctx_menu.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.position = Vector2(6, 6)
	col.add_theme_constant_override("separation", 4)
	_ctx_menu.add_child(col)

	if item.stackable and count > 1:
		var split_btn := Button.new()
		split_btn.text = "Split Stack"
		split_btn.custom_minimum_size = Vector2(120, 32)
		split_btn.pressed.connect(func() -> void:
			_close_context_menu()
			_open_split_dialog(slot_index, pos)
		)
		col.add_child(split_btn)

	var drop_btn := Button.new()
	drop_btn.text = "Drop Stack" if count > 1 else "Drop"
	drop_btn.custom_minimum_size = Vector2(120, 32)
	drop_btn.pressed.connect(func() -> void:
		var taken = get_parent().get_node("Inventory").take_slot(slot_index)
		if taken != null:
			_drop_to_world(taken["id"], taken["count"])
		_close_context_menu()
	)
	col.add_child(drop_btn)

	var btn_count := col.get_child_count()
	var menu_w    := 120.0 + 12.0
	var menu_h    : float = btn_count * 36.0 + 12.0
	_ctx_menu.size = Vector2(menu_w, menu_h)

	var vp_size  := get_viewport().get_visible_rect().size
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
	var data = get_parent().get_node("Inventory").get_slot(slot_index)
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
	style.bg_color     = Color(0.12, 0.10, 0.08, 0.95)
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
	_split_slider.step      = 1
	_split_slider.value     = half
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
	var vp_size   := get_viewport().get_visible_rect().size
	var panel_pos := pos + Vector2(4, 4)
	panel_pos.x = minf(panel_pos.x, vp_size.x - 170.0)
	panel_pos.y = minf(panel_pos.y, vp_size.y - 120.0)
	_split_panel.position = panel_pos


func _do_split(slot_index: int, take_count: int) -> void:
	var data = get_parent().get_node("Inventory").get_slot(slot_index)
	if data == null:
		_close_split_dialog()
		return
	var item         : ItemData = _load_item(data["id"])
	var total        : int      = data["count"]
	var split_amount : int      = clampi(take_count, 1, total - 1)

	data["count"] = total - split_amount
	get_parent().get_node("Inventory").slot_changed.emit(slot_index)
	get_parent().get_node("Inventory").inventory_changed.emit()

	_held_data          = { "id": data["id"], "count": split_amount }
	_held_icon.texture  = _get_icon(item)
	_held_icon.visible  = true
	_held_label.text    = str(split_amount) if split_amount > 1 else ""
	_held_label.visible = split_amount > 1

	_close_split_dialog()


func _close_split_dialog() -> void:
	if _split_panel != null:
		_split_panel.queue_free()
		_split_panel  = null
		_split_slider = null
		_split_label  = null
		_split_slot   = -1


# ──────────────────────────────────────────────────────────────────────────────
#  DROP TO WORLD
# ──────────────────────────────────────────────────────────────────────────────

func _drop_to_world(item_id: String, count: int) -> void:
	if _player_ref == null:
		return
	var scene := load("res://scenes/world/pickable_item.tscn") as PackedScene
	if scene == null:
		push_warning("InventoryUI: pickable_item.tscn not found.")
		return
	for i in count:
		var inst := scene.instantiate()
		inst.item_data = _load_item(item_id)
		var fwd    := -_player_ref.global_transform.basis.z
		var offset := fwd * 2.0 + Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3))
		inst.global_position = _player_ref.global_position + offset
		_player_ref.get_parent().add_child(inst)


func _build_skill_page(page: Control, panel_w: float, page_h: float) -> void:
	page.clip_contents = true
	var p := 10.0
	
	# ── Header: Title ──
	var title := Label.new()
	title.name     = "SkillTitle"
	title.text     = "Fähigkeiten (Skills)"
	title.position = Vector2(p, p)
	title.size     = Vector2(500, 28)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.90, 0.75, 0.45, 1.0))
	page.add_child(title)
	
	var sk_pts_lbl := Label.new()
	sk_pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sk_pts_lbl.position = Vector2(p, p)
	sk_pts_lbl.size     = Vector2(panel_w - p * 2, 28)
	sk_pts_lbl.add_theme_font_size_override("font_size", 14)
	sk_pts_lbl.add_theme_color_override("font_color", Color(0.45, 0.88, 0.45, 1.0))
	page.add_child(sk_pts_lbl)

	# ── Separator ──
	var sep := ColorRect.new()
	sep.position = Vector2(p, p + 34)
	sep.size     = Vector2(panel_w - p * 2, 1)
	sep.color    = Color(0.45, 0.38, 0.28, 0.50)
	page.add_child(sep)

	# ── VISUELLE SZENE LADEN ──
	var map_scene = load("res://scenes/ui/skill_map_ui.tscn")
	if map_scene:
		var map_inst = map_scene.instantiate()
		map_inst.position = Vector2(0, 40)
		map_inst.size = Vector2(panel_w, page_h - 40)
		map_inst.points_label = sk_pts_lbl
		page.add_child(map_inst)
		_skill_map_inst = map_inst
