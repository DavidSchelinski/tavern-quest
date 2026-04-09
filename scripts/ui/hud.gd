extends CanvasLayer
## In-game HUD: HP bar and Stamina bar, top-left corner.
## Created and owned by player.gd (_setup_hud).
##
## Layout (all values in pixels, origin = panel top-left):
##
##   ┌──────────────────────────────────────┐
##   │  PAD_X                               │
##   │  ♥  [═══════════bar══════════]  80/100│
##   │  ◈  [═══════════bar══════════]  65/100│
##   │  PAD_X                               │
##   └──────────────────────────────────────┘
##
##   PANEL_W = PAD_X + ICON_W + BAR_GAP + BAR_W + NUM_GAP + NUM_W + PAD_X
##           = 10   +  14    +   4     +  128  +    5    +  50   +  10  = 221 → 222

# ── Layout constants ──────────────────────────────────────────────────────────
const PAD_X    := 10.0
const PAD_Y    := 9.0
const ICON_W   := 14.0
const BAR_GAP  := 4.0
const BAR_W    := 128.0
const BAR_H    := 9.0
const NUM_GAP  := 5.0
const NUM_W    := 50.0
const ROW_H    := 26.0

const PANEL_W  := PAD_X + ICON_W + BAR_GAP + BAR_W + NUM_GAP + NUM_W + PAD_X   # = 221
const PANEL_H  := PAD_Y * 2.0 + ROW_H * 2.0 + 4.0                              # = 74
const MARGIN   := 14.0

# ── Colors ────────────────────────────────────────────────────────────────────
const C_HP_FULL  := Color(0.85, 0.15, 0.12, 1.0)
const C_HP_LOW   := Color(1.00, 0.40, 0.10, 1.0)   # below 30 %
const C_STA_FULL := Color(0.92, 0.72, 0.10, 1.0)
const C_STA_LOW  := Color(0.50, 0.50, 0.50, 1.0)   # exhausted
const C_TRACK    := Color(0.08, 0.06, 0.05, 0.80)
const C_PANEL    := Color(0.04, 0.03, 0.02, 0.72)

# ── Nodes ─────────────────────────────────────────────────────────────────────
var _hp_fill     : Panel     = null
var _hp_label    : Label     = null
var _sta_fill    : Panel     = null
var _sta_label   : Label     = null
var _dmg_overlay : ColorRect = null

# ── State ─────────────────────────────────────────────────────────────────────
var _player : CharacterBody3D = null


func _ready() -> void:
	layer = 5
	_build_ui()


func set_player(player: CharacterBody3D) -> void:
	_player = player


# ── Update every frame ────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _player == null:
		return

	var max_hp  : float = _player.get_node("Stats").get_max_hp()
	var hp_val          = _player.get("health")
	var sta_val         = _player.get("_stamina")

	var cur_hp  : float = float(hp_val)  if hp_val  != null else max_hp
	var cur_sta : float = float(sta_val) if sta_val != null else 100.0

	_update_bar(_hp_fill,  _hp_label,  cur_hp,  max_hp, C_HP_FULL,  C_HP_LOW)
	_update_bar(_sta_fill, _sta_label, cur_sta, 100.0,  C_STA_FULL, C_STA_LOW)


func _update_bar(fill: Panel, label: Label,
				 cur: float, max_val: float,
				 col_full: Color, col_low: Color) -> void:
	if fill == null or label == null or max_val <= 0.0:
		return
	var ratio : float = clampf(cur / max_val, 0.0, 1.0)
	fill.size.x = BAR_W * ratio

	# Colour: full → low when ratio < 0.3
	var t   : float = clampf((0.3 - ratio) / 0.3, 0.0, 1.0)
	var col : Color = col_full.lerp(col_low, t)
	var style := fill.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.bg_color = col

	label.text = "%d/%d" % [int(cur), int(max_val)]


# ── Damage flash ──────────────────────────────────────────────────────────────

func flash_damage() -> void:
	if _dmg_overlay == null:
		return
	_dmg_overlay.modulate.a = 0.45
	create_tween().tween_property(_dmg_overlay, "modulate:a", 0.0, 0.5) \
		.set_trans(Tween.TRANS_QUAD)


# ── Build UI ──────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-screen damage overlay (sits behind everything, shown on hit)
	_dmg_overlay = ColorRect.new()
	_dmg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dmg_overlay.color       = Color(0.9, 0.05, 0.0, 1.0)
	_dmg_overlay.modulate.a  = 0.0
	_dmg_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dmg_overlay)

	# Outer anchor — fixed size, top-left corner
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_TOP_LEFT)
	anchor.offset_left   = MARGIN
	anchor.offset_top    = MARGIN
	anchor.offset_right  = MARGIN + PANEL_W
	anchor.offset_bottom = MARGIN + PANEL_H
	anchor.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	# Background panel (fills the anchor)
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = C_PANEL
	bg_style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", bg_style)
	anchor.add_child(panel)

	# Bar rows — all children of panel, all within its bounds
	var hp_row  := _make_bar_row(panel, 0, "♥", C_HP_FULL)
	_hp_fill    = hp_row[0]
	_hp_label   = hp_row[1]
	var sta_row := _make_bar_row(panel, 1, "◈", C_STA_FULL)
	_sta_fill   = sta_row[0]
	_sta_label  = sta_row[1]


# Returns [fill_panel, value_label]
func _make_bar_row(parent: Control, row_idx: int, icon: String, col: Color) -> Array:
	var row_y  := PAD_Y + row_idx * (ROW_H + 4.0)
	var bar_y  := row_y + (ROW_H - BAR_H) * 0.5   # vertically centred

	# ── Icon ──────────────────────────────────────────────────────────────────
	var icon_x := PAD_X
	var icon_lbl := Label.new()
	icon_lbl.text                = icon
	icon_lbl.position            = Vector2(icon_x, row_y)
	icon_lbl.size                = Vector2(ICON_W, ROW_H)
	icon_lbl.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 13)
	icon_lbl.add_theme_color_override("font_color", col)
	icon_lbl.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon_lbl)

	# ── Bar track ─────────────────────────────────────────────────────────────
	var bar_x := PAD_X + ICON_W + BAR_GAP
	var track := Panel.new()
	track.position    = Vector2(bar_x, bar_y)
	track.size        = Vector2(BAR_W, BAR_H)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = C_TRACK
	track_style.set_corner_radius_all(4)
	track.add_theme_stylebox_override("panel", track_style)
	parent.add_child(track)

	# ── Bar fill (child of track, so it clips naturally) ──────────────────────
	var fill := Panel.new()
	fill.position    = Vector2(0.0, 0.0)
	fill.size        = Vector2(BAR_W, BAR_H)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = col
	fill_style.set_corner_radius_all(4)
	fill.add_theme_stylebox_override("panel", fill_style)
	track.add_child(fill)

	# ── Value label ───────────────────────────────────────────────────────────
	# Starts exactly at bar_x + BAR_W + NUM_GAP, ends at PANEL_W - PAD_X
	var num_x := PAD_X + ICON_W + BAR_GAP + BAR_W + NUM_GAP
	var val_lbl := Label.new()
	val_lbl.position             = Vector2(num_x, row_y)
	val_lbl.size                 = Vector2(NUM_W, ROW_H)
	val_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 10)
	val_lbl.add_theme_color_override("font_color", Color(0.82, 0.78, 0.70, 1.0))
	val_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	parent.add_child(val_lbl)

	return [fill, val_lbl]
