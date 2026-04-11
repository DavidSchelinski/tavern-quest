extends ScrollContainer

@export var skill_buttons   : Array[Button]    = []
@export var skill_data_refs : Array[SkillData] = []

var _player       : Node  = null
var points_label  : Label = null

@onready var map_canvas = $MapCanvas

# Variablen für Drag & Zoom
var _is_panning : bool = false
var _zoom : float = 1.0
var _base_canvas_size : Vector2 = Vector2(3000, 2000)


func setup(player: Node) -> void:
	_player = player
	for btn in skill_buttons:
		if btn != null:
			btn.player_ref = player
	# UI nach Server-Bestätigung eines Skill-Kaufs automatisch neu laden.
	var skills: Node = player.get_node_or_null("Skills")
	if skills != null and not skills.skill_data_synced.is_connected(refresh_ui):
		skills.skill_data_synced.connect(refresh_ui)
	call_deferred("refresh_ui")


func _ready() -> void:
	if map_canvas:
		_base_canvas_size = map_canvas.custom_minimum_size

	call_deferred("refresh_ui")
	call_deferred("_draw_lines")


func refresh_ui() -> void:
	if _player == null:
		return
	var skills : Node = _player.get_node_or_null("Skills")
	if skills == null:
		return

	if points_label != null:
		var pts: int = skills.skill_points
		if pts > 0:
			points_label.text = "✦ %d Skillpunkt%s verfügbar" % [pts, "e" if pts != 1 else ""]
			points_label.add_theme_color_override("font_color", Color(0.45, 0.92, 0.45, 1.0))
		else:
			points_label.text = "Keine Skillpunkte verfügbar"
			points_label.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50, 1.0))

	var count : int = mini(skill_buttons.size(), skill_data_refs.size())
	for i in count:
		var btn: Button = skill_buttons[i]
		var sd: SkillData = skill_data_refs[i]
		if btn == null or sd == null:
			continue
		var level: int = skills.get_skill_level(sd.id)
		var is_unlocked: bool = level > 0
		if btn.has_method("update_visual_state"):
			btn.update_visual_state(is_unlocked, level)
		if btn.has_method("_rebuild_tooltip"):
			btn._rebuild_tooltip()

	_draw_lines()


func _draw_lines() -> void:
	if map_canvas == null:
		return

	# 1. Alte Linien löschen
	for child in map_canvas.get_children():
		if child is Line2D:
			child.queue_free()

	var count : int = mini(skill_buttons.size(), skill_data_refs.size())

	# 2. Neue Linien ziehen
	for i in count:
		var current_btn  = skill_buttons[i]
		var current_data = skill_data_refs[i]
		if current_btn == null or current_data == null:
			continue

		for prereq_id in current_data.prerequisite_skills:
			var prereq_btn : Button = null
			for j in count:
				if skill_data_refs[j] != null and skill_data_refs[j].id == prereq_id:
					prereq_btn = skill_buttons[j]
					break

			if prereq_btn != null:
				var line := Line2D.new()
				line.width = 6.0

				var skills: Node = _player.get_node_or_null("Skills") if _player != null else null
				var prereq_unlocked: bool = false
				if skills != null:
					prereq_unlocked = skills.get_skill_level(prereq_id) > 0
				if prereq_unlocked:
					line.default_color = Color(1.0, 0.85, 0.2, 1.0)  # Gold — Weg ist frei
				else:
					line.default_color = Color(0.3, 0.3, 0.3, 0.8)   # Dunkelgrau — gesperrt

				var pos1 : Vector2 = prereq_btn.position + (prereq_btn.size / 2.0)
				var pos2 : Vector2 = current_btn.position + (current_btn.size / 2.0)
				line.add_point(pos1)
				line.add_point(pos2)
				map_canvas.add_child(line)

				# Linie zwischen Hintergrund (Index 0) und Buttons einschieben
				map_canvas.move_child(line, 1)


# ── EINGABE: PANNING & ZOOM ──
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:

		# Panning (Verschieben mit Klick)
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_is_panning = true
			else:
				_is_panning = false

		# Zoom (Mausrad)
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_set_zoom(_zoom + 0.01)
				accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(_zoom - 0.01)
				accept_event()

	# Panning ausführen
	elif event is InputEventMouseMotion and _is_panning:
		scroll_horizontal -= int(event.relative.x)
		scroll_vertical   -= int(event.relative.y)


func _set_zoom(new_zoom: float) -> void:
	_zoom = clamp(new_zoom, 0.4, 2.0)
	map_canvas.scale = Vector2(_zoom, _zoom)
	map_canvas.custom_minimum_size = _base_canvas_size * _zoom
