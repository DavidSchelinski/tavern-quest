extends CanvasLayer

const HOTBAR_SLOT_SCRIPT := "res://scripts/ui/hotbar_slot.gd"

const SLOT_COUNT : int   = 7
const SLOT_SIZE  : float = 52.0
const SLOT_GAP   : float = 6.0
const MARGIN_BOT : float = 20.0

const C_BG     := Color(0.10, 0.08, 0.07, 0.80)   # UITheme.BG_DARK (alpha adjusted)
const C_FILLED := Color(0.20, 0.16, 0.12, 0.85)   # UITheme.BG_LIGHT
const C_BORDER := Color(0.55, 0.45, 0.30, 1.0)     # UITheme.BORDER
const C_KEY    := Color(0.55, 0.52, 0.47, 1.0)      # UITheme.TEXT_DIMMED
const C_SKILL  := Color(0.88, 0.82, 0.72, 1.0)      # UITheme.TEXT_NORMAL

var _player       : Node  = null
var _slot_panels  : Array = []
var _skill_labels : Array = []
var _skill_icons  : Array = []
var _skill_data_cache : Dictionary = {}


func _ready() -> void:
	layer = 4
	_build_ui()


func set_player(player: Node) -> void:
	_player = player
	for slot in _slot_panels:
		if slot != null:
			slot.player_ref = player


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
		var slot_script: Script = load(HOTBAR_SLOT_SCRIPT)
		if slot_script:
			slot.set_script(slot_script)
			slot.slot_index = i
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

		# Skill icon
		var skill_icon := TextureRect.new()
		skill_icon.position = Vector2(6.0, 12.0)
		skill_icon.size = Vector2(SLOT_SIZE - 12.0, SLOT_SIZE - 24.0)
		skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skill_icon.visible = false
		slot.add_child(skill_icon)
		_skill_icons.append(skill_icon)

		# Skill name (centred, shown when no icon)
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
		var icon  : TextureRect  = _skill_icons[i] as TextureRect
		var panel : Panel        = _slot_panels[i] as Panel
		var style : StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat

		if id != "":
			var sd := _get_skill_data(id)
			if sd != null:
				lbl.text = sd.display_name if sd.display_name != "" else id
				if sd.icon != null:
					icon.texture = sd.icon
					icon.visible = true
					lbl.visible = false
				else:
					icon.visible = false
					lbl.visible = true
			else:
				lbl.text = id
				icon.visible = false
				lbl.visible = true
		else:
			lbl.text = ""
			icon.texture = null
			icon.visible = false
			lbl.visible = true
		if style:
			style.bg_color = C_FILLED if id != "" else C_BG


func _get_skill_data(skill_id: String) -> SkillData:
	if _skill_data_cache.has(skill_id):
		return _skill_data_cache[skill_id]
	var path := "res://scripts/skills/" + skill_id + ".tres"
	if ResourceLoader.exists(path):
		var res := load(path) as SkillData
		_skill_data_cache[skill_id] = res
		return res
	return null
