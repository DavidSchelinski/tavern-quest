extends CanvasLayer

const SLOT_COUNT : int   = 7
const SLOT_SIZE  : float = 52.0
const SLOT_GAP   : float = 6.0
const MARGIN_BOT : float = 20.0

const C_BG     := Color(0.04, 0.03, 0.02, 0.80)
const C_FILLED := Color(0.18, 0.40, 0.75, 0.45)
const C_BORDER := Color(0.35, 0.30, 0.22, 1.0)
const C_KEY    := Color(0.60, 0.58, 0.52, 1.0)
const C_SKILL  := Color(0.90, 0.86, 0.78, 1.0)

var _player       : Node  = null
var _slot_panels  : Array = []
var _skill_labels : Array = []


func _ready() -> void:
	layer = 4
	_build_ui()


func set_player(player: Node) -> void:
	_player = player


func _build_ui() -> void:
	var total_w : float = SLOT_COUNT * SLOT_SIZE + (SLOT_COUNT - 1) * SLOT_GAP

	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	anchor.offset_left   = -total_w * 0.5
	anchor.offset_right  = total_w * 0.5
	anchor.offset_bottom = -MARGIN_BOT
	anchor.offset_top    = -(MARGIN_BOT + SLOT_SIZE)
	anchor.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	for i : int in SLOT_COUNT:
		var x : float = i * (SLOT_SIZE + SLOT_GAP)

		var slot := Panel.new()
		slot.position = Vector2(x, 0.0)
		slot.size     = Vector2(SLOT_SIZE, SLOT_SIZE)
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = C_BG
		bg_style.set_corner_radius_all(6)
		bg_style.border_color = C_BORDER
		bg_style.set_border_width_all(1)
		slot.add_theme_stylebox_override("panel", bg_style)
		anchor.add_child(slot)
		_slot_panels.append(slot)

		# Key number (top-left)
		var key_lbl := Label.new()
		key_lbl.text     = str(i + 1)
		key_lbl.position = Vector2(4.0, 2.0)
		key_lbl.size     = Vector2(14.0, 14.0)
		key_lbl.add_theme_font_size_override("font_size", 10)
		key_lbl.add_theme_color_override("font_color", C_KEY)
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(key_lbl)

		# Skill name (centred)
		var skill_lbl := Label.new()
		skill_lbl.position             = Vector2(2.0, SLOT_SIZE * 0.5 - 10.0)
		skill_lbl.size                 = Vector2(SLOT_SIZE - 4.0, 20.0)
		skill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_lbl.add_theme_font_size_override("font_size", 9)
		skill_lbl.add_theme_color_override("font_color", C_SKILL)
		skill_lbl.clip_text            = true
		skill_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		slot.add_child(skill_lbl)
		_skill_labels.append(skill_lbl)


func _process(_delta: float) -> void:
	if _player == null:
		return
	var skills : Node = _player.get_node_or_null("Skills")
	if skills == null:
		return
	var hotbar : Array = skills._hotbar as Array
	for i : int in SLOT_COUNT:
		var id    : String       = hotbar[i] as String
		var lbl   : Label        = _skill_labels[i] as Label
		var panel : Panel        = _slot_panels[i] as Panel
		var style : StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		lbl.text = id if id != "" else ""
		if style:
			style.bg_color = C_FILLED if id != "" else C_BG
