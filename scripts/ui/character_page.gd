extends Control

## Character/stats page inside the InGameMenu.
## Features confirm/cancel workflow for stat allocation.

var _player_ref        : Node3D = null
var _stat_points_label : Label = null
var _stat_val_labels   : Dictionary = {}   # stat → Label
var _stat_plus_btns    : Dictionary = {}   # stat → Button
var _stat_pending_lbls : Dictionary = {}   # stat → Label (preview)
var _derived_labels    : Dictionary = {}   # key  → Label
var _confirm_btn       : Button = null
var _cancel_btn        : Button = null

var _pending_allocations : Dictionary = {}
var _preview_mode : bool = false


func setup(player: Node3D) -> void:
	_player_ref = player
	player.get_node("Stats").stats_changed.connect(_on_stats_changed)


func refresh() -> void:
	_refresh_character_page()


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var panel_w := size.x if size.x > 0 else 900.0
	var p := 10.0
	var y := p

	# Title + stat points
	var title := Label.new()
	title.text = "Charakter"
	title.position = Vector2(p, y)
	title.size = Vector2(220, 28)
	title.add_theme_font_size_override("font_size", UITheme.TITLE_SIZE)
	title.add_theme_color_override("font_color", UITheme.TEXT_TITLE)
	add_child(title)

	_stat_points_label = Label.new()
	_stat_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stat_points_label.position = Vector2(panel_w * 0.45, y)
	_stat_points_label.size = Vector2(panel_w * 0.5 - p, 28)
	_stat_points_label.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	_stat_points_label.add_theme_color_override("font_color", UITheme.TEXT_POSITIVE)
	add_child(_stat_points_label)
	y += 34

	add_child(UITheme.make_hsep(p, y, panel_w - p * 2))
	y += 10

	add_child(UITheme.make_section_label("Primäre Attribute", p, y, panel_w - p * 2))
	y += 24

	# Stat rows (including stamina)
	var stat_names : Array[String] = ["strength", "agility", "defense", "endurance", "charisma", "stamina"]
	var row_h := 38.0
	for stat in stat_names:
		_build_stat_row(stat, p, y, panel_w - p * 2, row_h)
		y += row_h + 4
	y += 4

	# Confirm / Cancel row
	_confirm_btn = Button.new()
	_confirm_btn.text = "Bestätigen"
	_confirm_btn.position = Vector2(p, y)
	_confirm_btn.size = Vector2(120, 32)
	_confirm_btn.visible = false
	_confirm_btn.pressed.connect(_on_confirm)
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = UITheme.CONFIRM_COLOR
	confirm_style.set_corner_radius_all(4)
	_confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	add_child(_confirm_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Abbrechen"
	_cancel_btn.position = Vector2(p + 128, y)
	_cancel_btn.size = Vector2(120, 32)
	_cancel_btn.visible = false
	_cancel_btn.pressed.connect(_on_cancel)
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = UITheme.CANCEL_COLOR
	cancel_style.set_corner_radius_all(4)
	_cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	add_child(_cancel_btn)
	y += 40

	add_child(UITheme.make_hsep(p, y, panel_w - p * 2))
	y += 10

	# Derived stats
	add_child(UITheme.make_section_label("Abgeleitete Werte", p, y, panel_w - p * 2))
	y += 24

	var derived_defs : Array[Array] = [
		["Max-HP", "max_hp"],
		["Max-Stamina", "max_stamina"],
		["Schadensbonus", "dmg_mult"],
		["Schadensreduktion", "dmg_red"],
		["Bewegungstempo", "speed"],
		["Angriffsgeschwindigkeit", "atk_speed"],
	]
	for def in derived_defs:
		_build_derived_row(def[0], def[1], p, y, panel_w - p * 2)
		y += 24

	y += 4
	add_child(UITheme.make_hsep(p, y, panel_w - p * 2))
	y += 10
	add_child(UITheme.make_section_label("Aktueller Status", p, y, panel_w - p * 2))
	y += 24
	var status_defs : Array[Array] = [
		["Aktuelle HP", "current_hp"],
		["Ausdauer", "current_stamina"],
	]
	for def in status_defs:
		_build_derived_row(def[0], def[1], p, y, panel_w - p * 2)
		y += 24


func _get_stat_label(stat: String) -> String:
	var labels : Dictionary = {
		"strength": "Stärke",
		"agility": "Beweglichkeit",
		"defense": "Verteidigung",
		"endurance": "Ausdauer",
		"charisma": "Charisma",
		"stamina": "Stamina",
	}
	return labels.get(stat, stat)


func _get_stat_desc(stat: String) -> String:
	var descs : Dictionary = {
		"strength": "+10% Schaden pro Punkt",
		"agility": "+5% Tempo & Angriff",
		"defense": "-5% Eingehender Schaden",
		"endurance": "+20 Max-HP pro Punkt",
		"charisma": "Quests & Handel",
		"stamina": "+10 Max-Stamina pro Punkt",
	}
	return descs.get(stat, "")


func _build_stat_row(stat: String, x: float, y: float, w: float, h: float) -> void:
	var bg := Panel.new()
	bg.position = Vector2(x, y)
	bg.size = Vector2(w, h)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.12, 0.10, 0.60)
	bg_style.border_color = UITheme.BORDER_FAINT
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(3)
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	var name_lbl := Label.new()
	name_lbl.text = _get_stat_label(stat)
	name_lbl.position = Vector2(8, 0)
	name_lbl.size = Vector2(155, h)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	name_lbl.add_theme_color_override("font_color", UITheme.TEXT_NORMAL)
	bg.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.position = Vector2(165, 0)
	val_lbl.size = Vector2(38, h)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 16)
	bg.add_child(val_lbl)
	_stat_val_labels[stat] = val_lbl

	# Pending preview label
	var pending_lbl := Label.new()
	pending_lbl.position = Vector2(203, 0)
	pending_lbl.size = Vector2(30, h)
	pending_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pending_lbl.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	pending_lbl.add_theme_color_override("font_color", UITheme.TEXT_POSITIVE)
	pending_lbl.visible = false
	bg.add_child(pending_lbl)
	_stat_pending_lbls[stat] = pending_lbl

	var btn := Button.new()
	btn.text = "+"
	btn.position = Vector2(235, (h - 26) / 2.0)
	btn.size = Vector2(26, 26)
	btn.add_theme_font_size_override("font_size", 17)
	btn.pressed.connect(func() -> void: _on_spend_point_preview(stat))
	bg.add_child(btn)
	_stat_plus_btns[stat] = btn

	var desc := Label.new()
	desc.text = _get_stat_desc(stat)
	desc.position = Vector2(268, 0)
	desc.size = Vector2(w - 276, h)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc.clip_text = true
	desc.add_theme_font_size_override("font_size", UITheme.SMALL_SIZE)
	desc.add_theme_color_override("font_color", UITheme.TEXT_DIMMED)
	bg.add_child(desc)


func _build_derived_row(label: String, key: String, x: float, y: float, w: float) -> void:
	var lbl := Label.new()
	lbl.text = label + ":"
	lbl.position = Vector2(x + 8, y)
	lbl.size = Vector2(200, 22)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.68, 0.62, 0.54, 1.0))
	add_child(lbl)

	var val := Label.new()
	val.position = Vector2(x + 216, y)
	val.size = Vector2(w - 224, 22)
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", UITheme.TEXT_VALUE)
	add_child(val)
	_derived_labels[key] = val


# ── Confirm / Cancel workflow ────────────────────────────────────────────────

func _on_spend_point_preview(stat: String) -> void:
	if _player_ref == null:
		return
	var stats_node: Node = _player_ref.get_node("Stats")
	var available: int = stats_node.stat_points - _total_pending()
	if available <= 0:
		return
	_pending_allocations[stat] = _pending_allocations.get(stat, 0) + 1
	_preview_mode = true
	_refresh_preview()


func _on_confirm() -> void:
	if _player_ref == null:
		return
	var stats_node: Node = _player_ref.get_node("Stats")
	if multiplayer.has_multiplayer_peer():
		# Multiplayer: Server validiert und sendet autoritative Daten zurück.
		stats_node.request_spend_points.rpc_id(1, _pending_allocations.duplicate())
	else:
		# Singleplayer: direkt anwenden.
		for stat: String in _pending_allocations:
			for i: int in (_pending_allocations[stat] as int):
				stats_node.spend_point(stat)
	_pending_allocations.clear()
	_preview_mode = false
	_refresh_character_page()


func _on_cancel() -> void:
	_pending_allocations.clear()
	_preview_mode = false
	_refresh_character_page()


func _total_pending() -> int:
	var total := 0
	for stat in _pending_allocations:
		total += _pending_allocations[stat]
	return total


func _refresh_preview() -> void:
	if _player_ref == null:
		return
	var stats_node: Node = _player_ref.get_node("Stats")
	var pts: int= stats_node.stat_points
	var pending_total := _total_pending()
	var remaining := pts - pending_total

	if remaining > 0:
		_stat_points_label.text = "✦ %d Statpunkt%s verfügbar" % [remaining, "e" if remaining != 1 else ""]
		_stat_points_label.add_theme_color_override("font_color", UITheme.TEXT_POSITIVE)
	else:
		_stat_points_label.text = "Keine Statpunkte verfügbar"
		_stat_points_label.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50, 1.0))

	var stat_names : Array[String] = ["strength", "agility", "defense", "endurance", "charisma", "stamina"]
	for stat in stat_names:
		var val : int = stats_node.stats.get(stat, 1) if stats_node.stats.has(stat) else 1
		var lbl : Label = _stat_val_labels[stat]
		var btn : Button = _stat_plus_btns[stat]
		var pending_lbl : Label = _stat_pending_lbls[stat]
		var pending : int = _pending_allocations.get(stat, 0)

		lbl.text = str(val)
		var col := UITheme.TEXT_STAT_UP if val > 1 else Color(0.82, 0.82, 0.82, 1.0)
		lbl.add_theme_color_override("font_color", col)

		if pending > 0:
			pending_lbl.text = "+%d" % pending
			pending_lbl.visible = true
		else:
			pending_lbl.visible = false

		btn.disabled = (remaining <= 0)

	_confirm_btn.visible = _preview_mode
	_cancel_btn.visible = _preview_mode

	_refresh_derived_values()


# ── Character page refresh ────────��──────────────────────────────────────────

func _on_stats_changed() -> void:
	if visible:
		_refresh_character_page()


func _refresh_character_page() -> void:
	if _stat_points_label == null or _player_ref == null:
		return

	var stats_node: Node = _player_ref.get_node("Stats")
	var pts: int = stats_node.stat_points

	if pts > 0:
		_stat_points_label.text = "✦ %d Statpunkt%s verfügbar" % [pts, "e" if pts != 1 else ""]
		_stat_points_label.add_theme_color_override("font_color", UITheme.TEXT_POSITIVE)
	else:
		_stat_points_label.text = "Keine Statpunkte verfügbar"
		_stat_points_label.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50, 1.0))

	var stat_names : Array[String] = ["strength", "agility", "defense", "endurance", "charisma", "stamina"]
	for stat in stat_names:
		var val : int = stats_node.stats.get(stat, 1) if stats_node.stats.has(stat) else 1
		var lbl : Label = _stat_val_labels[stat]
		var btn : Button = _stat_plus_btns[stat]
		var pending_lbl : Label = _stat_pending_lbls[stat]

		lbl.text = str(val)
		var col := UITheme.TEXT_STAT_UP if val > 1 else Color(0.82, 0.82, 0.82, 1.0)
		lbl.add_theme_color_override("font_color", col)
		pending_lbl.visible = false
		btn.disabled = (pts <= 0)

	_confirm_btn.visible = false
	_cancel_btn.visible = false
	_pending_allocations.clear()
	_preview_mode = false

	_refresh_derived_values()


func _refresh_derived_values() -> void:
	if _player_ref == null:
		return
	var stats_node: Node = _player_ref.get_node("Stats")

	var dmg_pct := int((stats_node.get_damage_multiplier() - 1.0) * 100.0)
	var spd_pct := int((stats_node.get_speed_multiplier() - 1.0) * 100.0)
	var atk_pct := int((stats_node.get_attack_speed_multiplier() - 1.0) * 100.0)
	var red_pct := int(stats_node.get_damage_reduction() * 100.0)
	var max_hp: int = stats_node.get_max_hp()

	_derived_labels["max_hp"].text = "%d HP" % max_hp
	if _derived_labels.has("max_stamina"):
		var max_sta := 100.0
		if stats_node.has_method("get_max_stamina"):
			max_sta = stats_node.get_max_stamina()
		_derived_labels["max_stamina"].text = "%d" % int(max_sta)
	_derived_labels["dmg_mult"].text = ("+%d %%" % dmg_pct) if dmg_pct > 0 else "–"
	_derived_labels["dmg_red"].text = ("-%d %%" % red_pct) if red_pct > 0 else "–"
	_derived_labels["speed"].text = ("+%d %%" % spd_pct) if spd_pct > 0 else "–"
	_derived_labels["atk_speed"].text = ("+%d %%" % atk_pct) if atk_pct > 0 else "–"

	if _derived_labels.has("current_hp"):
		var hp_val = _player_ref.get("health")
		var cur_hp : float = float(hp_val) if hp_val != null else float(max_hp)
		_derived_labels["current_hp"].text = "%d / %d" % [int(cur_hp), max_hp]
	if _derived_labels.has("current_stamina"):
		var sta_val = _player_ref.get("_stamina")
		var max_sta := 100.0
		if stats_node.has_method("get_max_stamina"):
			max_sta = stats_node.get_max_stamina()
		var cur_sta : float = float(sta_val) if sta_val != null else max_sta
		_derived_labels["current_stamina"].text = "%d / %d" % [int(cur_sta), int(max_sta)]
