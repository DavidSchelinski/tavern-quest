extends Control

## Quest page inside the InGameMenu.

const QUEST_LIST_W  : float = 172.0
const QUEST_COL_GAP : float = 8.0

var _player_ref         : Node3D = null
var _quest_list_box     : VBoxContainer = null
var _quest_detail_panel : Control = null
var _detail_title       : Label = null
var _detail_rank        : Label = null
var _detail_giver       : Label = null
var _detail_desc        : RichTextLabel = null
var _detail_reward      : Label = null
var _detail_status      : Label = null
var _selected_quest     : Dictionary = {}
var _quest_entry_btns   : Array[Button] = []


func setup(player: Node3D) -> void:
	_player_ref = player
	player.get_node("Quests").quests_changed.connect(_on_quests_changed)


func refresh() -> void:
	_refresh_quest_page()


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var panel_w := size.x if size.x > 0 else 900.0
	var page_h := size.y if size.y > 0 else 560.0
	var p : float = 16.0

	# Title
	var title := Label.new()
	title.text = "Questtagebuch"
	title.position = Vector2(p, 8.0)
	title.size = Vector2(panel_w - p * 2.0, 28.0)
	title.add_theme_font_size_override("font_size", UITheme.TITLE_SIZE)
	title.add_theme_color_override("font_color", UITheme.TEXT_TITLE)
	add_child(title)

	var content_y : float = 40.0
	var content_h : float = page_h - content_y - p

	# Left: scrollable quest list
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(p, content_y)
	scroll.size = Vector2(QUEST_LIST_W, content_h)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_quest_list_box = VBoxContainer.new()
	_quest_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_list_box.add_theme_constant_override("separation", 3)
	scroll.add_child(_quest_list_box)

	# Vertical divider
	var div := ColorRect.new()
	div.position = Vector2(p + QUEST_LIST_W + QUEST_COL_GAP * 0.5 - 1.0, content_y)
	div.size = Vector2(1.0, content_h)
	div.color = UITheme.SEPARATOR
	add_child(div)

	# Right: detail panel
	var detail_x : float = p + QUEST_LIST_W + QUEST_COL_GAP
	var detail_w : float = panel_w - detail_x - p
	_quest_detail_panel = Control.new()
	_quest_detail_panel.position = Vector2(detail_x, content_y)
	_quest_detail_panel.size = Vector2(detail_w, content_h)
	add_child(_quest_detail_panel)
	_build_quest_detail_panel(_quest_detail_panel, detail_w, content_h)


func _build_quest_detail_panel(parent: Control, w: float, h: float) -> void:
	var hint := Label.new()
	hint.name = "EmptyHint"
	hint.text = "← Quest auswählen"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.position = Vector2(0.0, 0.0)
	hint.size = Vector2(w, h)
	hint.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	hint.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(hint)

	var dp : float = 8.0

	_detail_rank = Label.new()
	_detail_rank.position = Vector2(dp, dp)
	_detail_rank.size = Vector2(48.0, 28.0)
	_detail_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_rank.add_theme_font_size_override("font_size", 15)
	_detail_rank.visible = false
	var rank_style := StyleBoxFlat.new()
	rank_style.bg_color = Color(0.18, 0.14, 0.10, 0.9)
	rank_style.set_border_width_all(2)
	rank_style.set_corner_radius_all(4)
	rank_style.border_color = UITheme.BORDER
	_detail_rank.add_theme_stylebox_override("normal", rank_style)
	parent.add_child(_detail_rank)

	_detail_title = Label.new()
	_detail_title.position = Vector2(dp + 56.0, dp)
	_detail_title.size = Vector2(w - dp - 56.0, 28.0)
	_detail_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_title.clip_text = true
	_detail_title.add_theme_font_size_override("font_size", 16)
	_detail_title.add_theme_color_override("font_color", Color(0.92, 0.82, 0.55, 1.0))
	_detail_title.visible = false
	parent.add_child(_detail_title)

	var sep := ColorRect.new()
	sep.name = "DetailSep"
	sep.position = Vector2(dp, dp + 34.0)
	sep.size = Vector2(w - dp * 2.0, 1.0)
	sep.color = Color(0.45, 0.38, 0.28, 0.40)
	sep.visible = false
	parent.add_child(sep)

	_detail_giver = Label.new()
	_detail_giver.position = Vector2(dp, dp + 42.0)
	_detail_giver.size = Vector2(w - dp * 2.0, 20.0)
	_detail_giver.add_theme_font_size_override("font_size", 13)
	_detail_giver.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50, 1.0))
	_detail_giver.visible = false
	parent.add_child(_detail_giver)

	_detail_desc = RichTextLabel.new()
	_detail_desc.position = Vector2(dp, dp + 68.0)
	_detail_desc.size = Vector2(w - dp * 2.0, h - dp - 68.0 - 58.0)
	_detail_desc.bbcode_enabled = false
	_detail_desc.scroll_active = true
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_desc.add_theme_font_size_override("normal_font_size", 13)
	_detail_desc.add_theme_color_override("default_color", UITheme.TEXT_NORMAL)
	_detail_desc.visible = false
	parent.add_child(_detail_desc)

	_detail_reward = Label.new()
	_detail_reward.position = Vector2(dp, h - dp - 50.0)
	_detail_reward.size = Vector2(w - dp * 2.0, 22.0)
	_detail_reward.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_reward.add_theme_font_size_override("font_size", 13)
	_detail_reward.add_theme_color_override("font_color", UITheme.TEXT_POSITIVE)
	_detail_reward.visible = false
	parent.add_child(_detail_reward)

	_detail_status = Label.new()
	_detail_status.position = Vector2(dp, h - dp - 24.0)
	_detail_status.size = Vector2(w - dp * 2.0, 20.0)
	_detail_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_detail_status.add_theme_font_size_override("font_size", UITheme.SMALL_SIZE)
	_detail_status.visible = false
	parent.add_child(_detail_status)


# ── Quest page refresh ───────────────────────────────────────────────────────

func _on_quests_changed() -> void:
	if visible:
		_refresh_quest_page()


func _refresh_quest_page() -> void:
	if _quest_list_box == null or _player_ref == null:
		return

	for child in _quest_list_box.get_children():
		child.queue_free()
	_quest_entry_btns.clear()

	var quests_node: Node = _player_ref.get_node("Quests")
	var active : Array[Dictionary] = quests_node.get_active_quests()
	var completed : Array[Dictionary] = quests_node.get_completed_quests()

	if active.is_empty() and completed.is_empty():
		_add_list_placeholder("Noch keine Quests.\nBesuche das Quest-Board.")
		_clear_quest_detail()
		return

	if not active.is_empty():
		_add_list_header("Aktive Quests (%d)" % active.size())
		for q in active:
			_add_quest_entry(q, false)

	if not completed.is_empty():
		if not active.is_empty():
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0.0, 6.0)
			_quest_list_box.add_child(spacer)
		_add_list_header("Abgeschlossen (%d)" % completed.size())
		for q in completed:
			_add_quest_entry(q, true)

	if not _selected_quest.is_empty():
		var id : String = _selected_quest.get("title_key", "")
		if quests_node.is_quest_active(id) or quests_node.is_quest_completed(id):
			_show_quest_detail(_selected_quest)
			return
	_clear_quest_detail()


func _add_list_placeholder(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	_quest_list_box.add_child(lbl)


func _add_list_header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", UITheme.SMALL_SIZE)
	lbl.add_theme_color_override("font_color", UITheme.TEXT_DIMMED)
	lbl.custom_minimum_size = Vector2(QUEST_LIST_W - 8.0, 18.0)
	_quest_list_box.add_child(lbl)


func _add_quest_entry(quest: Dictionary, is_completed: bool) -> void:
	var rank : String = quest.get("rank", "?")
	var title_text : String = tr(quest.get("title_key", ""))

	var btn := Button.new()
	btn.text = "[%s] %s" % [rank, title_text]
	btn.clip_text = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(QUEST_LIST_W - 8.0, 30.0)
	btn.flat = false

	var rank_col : Color = UITheme.RANK_COLORS.get(rank, Color.WHITE)
	if is_completed:
		rank_col = rank_col.lerp(Color(0.5, 0.5, 0.5, 1.0), 0.55)

	var s := StyleBoxFlat.new()
	s.bg_color = UITheme.BG_MEDIUM
	s.border_color = rank_col
	s.set_border_width_all(1)
	s.border_width_left = 3
	s.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", s)

	var s_hover := s.duplicate() as StyleBoxFlat
	s_hover.bg_color = Color(0.22, 0.18, 0.14, 0.90)
	btn.add_theme_stylebox_override("hover", s_hover)

	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color",
		Color(0.65, 0.62, 0.56, 1.0) if is_completed else UITheme.TEXT_NORMAL)

	btn.pressed.connect(func() -> void: _show_quest_detail(quest))
	_quest_list_box.add_child(btn)
	_quest_entry_btns.append(btn)


func _show_quest_detail(quest: Dictionary) -> void:
	_selected_quest = quest
	var quest_id : String = quest.get("title_key", "")
	var is_done : bool = _player_ref.get_node("Quests").is_quest_completed(quest_id)
	var rank : String = quest.get("rank", "?")

	var hint := _quest_detail_panel.get_node_or_null("EmptyHint") as Label
	if hint: hint.visible = false

	_detail_rank.text = rank
	_detail_rank.visible = true
	var rank_col : Color = UITheme.RANK_COLORS.get(rank, Color.WHITE)
	_detail_rank.add_theme_color_override("font_color", rank_col)

	_detail_title.text = tr(quest_id)
	_detail_title.visible = true

	var sep := _quest_detail_panel.get_node_or_null("DetailSep")
	if sep: sep.visible = true

	_detail_giver.text = "Auftraggeber: " + tr(quest.get("giver_key", ""))
	_detail_giver.visible = true

	_detail_desc.text = tr(quest.get("desc_key", ""))
	_detail_desc.visible = true

	_detail_reward.text = "Belohnung: " + tr(quest.get("reward_key", ""))
	_detail_reward.visible = true

	if is_done:
		_detail_status.text = "✓ Abgeschlossen"
		_detail_status.add_theme_color_override("font_color", UITheme.TEXT_POSITIVE)
	else:
		_detail_status.text = "● Aktiv"
		_detail_status.add_theme_color_override("font_color", Color(0.90, 0.75, 0.25, 1.0))
	_detail_status.visible = true


func _clear_quest_detail() -> void:
	_selected_quest = {}
	var hint := _quest_detail_panel.get_node_or_null("EmptyHint") as Label
	if hint: hint.visible = true
	if _detail_rank:   _detail_rank.visible = false
	if _detail_title:  _detail_title.visible = false
	if _detail_giver:  _detail_giver.visible = false
	if _detail_desc:   _detail_desc.visible = false
	if _detail_reward: _detail_reward.visible = false
	if _detail_status: _detail_status.visible = false
	var sep := _quest_detail_panel.get_node_or_null("DetailSep")
	if sep: sep.visible = false
