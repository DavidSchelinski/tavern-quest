class_name UITheme

# ── Shared color palette (medieval dark-brown theme) ─────────────────────────

const BG_DARK      := Color(0.10, 0.08, 0.07, 0.96)
const BG_MEDIUM    := Color(0.15, 0.12, 0.10, 0.85)
const BG_LIGHT     := Color(0.20, 0.16, 0.12, 1.0)
const BG_OVERLAY   := Color(0.0, 0.0, 0.0, 0.35)

const BORDER       := Color(0.55, 0.45, 0.30, 1.0)
const BORDER_FAINT := Color(0.40, 0.32, 0.22, 0.50)
const BORDER_GOLD  := Color(0.75, 0.60, 0.35, 1.0)

const TEXT_TITLE   := Color(0.90, 0.75, 0.45, 1.0)
const TEXT_NORMAL  := Color(0.88, 0.82, 0.72, 1.0)
const TEXT_DIMMED   := Color(0.55, 0.52, 0.47, 1.0)
const TEXT_ACTIVE  := Color(0.95, 0.78, 0.45, 1.0)
const TEXT_POSITIVE := Color(0.45, 0.92, 0.45, 1.0)
const TEXT_NEGATIVE := Color(0.92, 0.35, 0.35, 1.0)
const TEXT_MUTED    := Color(0.50, 0.48, 0.44, 1.0)
const TEXT_VALUE    := Color(0.90, 0.82, 0.50, 1.0)
const TEXT_STAT_UP  := Color(0.95, 0.75, 0.28, 1.0)

const ACCENT_GOLD  := Color(0.75, 0.60, 0.35, 1.0)
const SEPARATOR    := Color(0.45, 0.38, 0.28, 0.50)

const TAB_ACTIVE_BG   := Color(0.20, 0.16, 0.12, 1.0)
const TAB_INACTIVE_BG := Color(0.10, 0.08, 0.07, 0.0)
const TAB_HOVER_TEXT  := Color(1.0, 0.88, 0.60, 1.0)

const SLOT_BG      := Color(0.15, 0.12, 0.10, 0.85)
const SLOT_EQUIP_BORDER := Color(0.80, 0.65, 0.30, 1.0)

const CTX_BG       := Color(0.12, 0.10, 0.08, 0.95)

const CONFIRM_COLOR := Color(0.30, 0.70, 0.30, 1.0)
const CANCEL_COLOR  := Color(0.70, 0.30, 0.30, 1.0)

# ── Font sizes ───────────────────────────────────────────────────────────────

const TITLE_SIZE   := 18
const NORMAL_SIZE  := 14
const SMALL_SIZE   := 12
const TAB_SIZE     := 15

# ── Rank colors (quest system) ───────────────────────────────────────────────

const RANK_COLORS : Dictionary = {
	"F": Color(0.60, 0.60, 0.60, 1.0),
	"E": Color(0.35, 0.80, 0.35, 1.0),
	"D": Color(0.35, 0.55, 0.95, 1.0),
	"C": Color(0.95, 0.60, 0.20, 1.0),
	"B": Color(0.90, 0.25, 0.25, 1.0),
	"A": Color(0.75, 0.30, 0.95, 1.0),
	"S": Color(0.95, 0.80, 0.10, 1.0),
}

# ── Style factories ──────────────────────────────────────────────────────────

static func make_panel_style(bg: Color = BG_DARK, border: Color = BORDER,
							  corner_radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(corner_radius)
	return s


static func make_slot_style(bg: Color = SLOT_BG, border: Color = BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	return s


static func make_tab_style(active: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = TAB_ACTIVE_BG if active else TAB_INACTIVE_BG
	s.set_border_width_all(0)
	s.border_width_bottom = 2 if active else 0
	s.border_color = ACCENT_GOLD
	s.set_corner_radius_all(0)
	return s


static func make_hsep(x: float, y: float, w: float) -> ColorRect:
	var r := ColorRect.new()
	r.position = Vector2(x, y)
	r.size = Vector2(w, 1)
	r.color = SEPARATOR
	return r


static func make_section_label(text: String, x: float, y: float, w: float) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(x, y)
	lbl.size = Vector2(w, 20)
	lbl.add_theme_font_size_override("font_size", SMALL_SIZE)
	lbl.add_theme_color_override("font_color", TEXT_DIMMED)
	return lbl
