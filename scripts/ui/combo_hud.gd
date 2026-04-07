extends CanvasLayer

# ── Config ────────────────────────────────────────────────────────────────────
const BAR_WIDTH    := 110.0
const BAR_HEIGHT   := 7.0
const FADE_SPEED   := 6.0   # how fast the bar fades in/out

# Colors: full window = gold, almost expired = red
const COLOR_FULL   := Color(1.00, 0.78, 0.10, 1.0)
const COLOR_EMPTY  := Color(0.90, 0.18, 0.10, 1.0)
const COLOR_BG     := Color(0.0,  0.0,  0.0,  0.45)

# ── Nodes (built in _ready) ───────────────────────────────────────────────────
var _panel     : Panel       = null
var _bar_fill  : Panel       = null
var _dot_row   : HBoxContainer = null
var _dots      : Array[TextureRect] = []

# ── State ─────────────────────────────────────────────────────────────────────
var _combat    : CombatHandler = null
var _alpha     : float = 0.0   # current opacity (0 = hidden, 1 = visible)
var _last_combo: String = ""


func _ready() -> void:
	layer = 10
	_build_ui()


func set_combat_handler(handler: CombatHandler) -> void:
	_combat = handler


func _process(delta: float) -> void:
	if _combat == null:
		return

	var ratio  := _combat.get_combo_ratio()
	var target := 1.0 if ratio > 0.0 else 0.0
	_alpha = move_toward(_alpha, target, FADE_SPEED * delta)

	_panel.modulate.a = _alpha

	if _alpha < 0.01:
		return

	# Resize fill bar
	var fill_w := BAR_WIDTH * ratio
	_bar_fill.size.x = fill_w

	# Color: lerp gold → red as window shrinks
	var col := COLOR_FULL.lerp(COLOR_EMPTY, 1.0 - ratio)
	var style := _bar_fill.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.bg_color = col

	# Update hit-type dots
	var combo_str := _combat._combo
	if combo_str != _last_combo:
		_last_combo = combo_str
		_refresh_dots(combo_str)


func _build_ui() -> void:
	# Root anchor: bottom-centre of viewport
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	anchor.offset_top    = -72.0
	anchor.offset_bottom = -52.0
	anchor.offset_left   = -BAR_WIDTH * 0.5 - 6.0
	anchor.offset_right  = BAR_WIDTH  * 0.5 + 6.0
	add_child(anchor)

	# Background panel
	_panel = Panel.new()
	_panel.size = Vector2(BAR_WIDTH + 12.0, 34.0)
	_panel.position = Vector2.ZERO
	_panel.modulate.a = 0.0
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color           = COLOR_BG
	bg_style.corner_radius_top_left     = 4
	bg_style.corner_radius_top_right    = 4
	bg_style.corner_radius_bottom_left  = 4
	bg_style.corner_radius_bottom_right = 4
	_panel.add_theme_stylebox_override("panel", bg_style)
	anchor.add_child(_panel)

	# Bar track (dark background)
	var track := Panel.new()
	track.size     = Vector2(BAR_WIDTH, BAR_HEIGHT)
	track.position = Vector2(6.0, 6.0)
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	track_style.corner_radius_top_left     = 3
	track_style.corner_radius_top_right    = 3
	track_style.corner_radius_bottom_left  = 3
	track_style.corner_radius_bottom_right = 3
	track.add_theme_stylebox_override("panel", track_style)
	_panel.add_child(track)

	# Bar fill
	_bar_fill = Panel.new()
	_bar_fill.size     = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar_fill.position = Vector2(0.0, 0.0)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = COLOR_FULL
	fill_style.corner_radius_top_left     = 3
	fill_style.corner_radius_top_right    = 3
	fill_style.corner_radius_bottom_left  = 3
	fill_style.corner_radius_bottom_right = 3
	_bar_fill.add_theme_stylebox_override("panel", fill_style)
	track.add_child(_bar_fill)

	# Dot row showing current combo hits (L = light, H = heavy)
	_dot_row = HBoxContainer.new()
	_dot_row.size         = Vector2(BAR_WIDTH, 14.0)
	_dot_row.position     = Vector2(6.0, 17.0)
	_dot_row.alignment    = BoxContainer.ALIGNMENT_CENTER
	_dot_row.add_theme_constant_override("separation", 5)
	_panel.add_child(_dot_row)


func _refresh_dots(combo: String) -> void:
	for d in _dots:
		d.queue_free()
	_dots.clear()

	for i in combo.length():
		var is_heavy := combo[i] == "H"
		var dot := _make_dot(is_heavy)
		_dot_row.add_child(dot)
		_dots.append(dot)


func _make_dot(heavy: bool) -> TextureRect:
	# Draw a small filled square as a colored dot via a nested Panel
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(12.0, 12.0)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var inner := Panel.new()
	inner.size = Vector2(10.0, 10.0)
	inner.position = Vector2(1.0, 1.0)
	var s := StyleBoxFlat.new()
	# Light = gold circle, Heavy = red diamond-ish
	s.bg_color = Color(1.0, 0.65, 0.0, 1.0) if not heavy else Color(0.9, 0.15, 0.1, 1.0)
	s.corner_radius_top_left     = 5 if not heavy else 1
	s.corner_radius_top_right    = 5 if not heavy else 1
	s.corner_radius_bottom_left  = 5 if not heavy else 1
	s.corner_radius_bottom_right = 5 if not heavy else 1
	inner.add_theme_stylebox_override("panel", s)
	rect.add_child(inner)
	return rect
