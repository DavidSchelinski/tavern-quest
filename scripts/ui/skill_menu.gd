extends ScrollContainer

@export var skill_buttons   : Array[Button]    = []
@export var skill_data_refs : Array[SkillData] = []

var _player : Node = null
@onready var map_canvas = $MapCanvas

# Variablen für Drag & Zoom
var _is_panning : bool = false
var _zoom : float = 1.0
var _base_canvas_size : Vector2 = Vector2(3000, 2000)

func setup(player: Node) -> void:
	_player = player
	call_deferred("refresh_ui")

func _ready() -> void:
	# Die Originalgröße der Karte speichern, damit der Zoom richtig berechnet wird
	if map_canvas:
		_base_canvas_size = map_canvas.custom_minimum_size
	call_deferred("_draw_lines")

func refresh_ui() -> void:
	if _player == null:
		return
	var skills : Node = _player.get_node_or_null("Skills")
	if skills == null:
		return
	
	var count : int = mini(skill_buttons.size(), skill_data_refs.size())
	for i in count:
		var btn = skill_buttons[i]
		var sd = skill_data_refs[i]
		if btn == null or sd == null: continue
		
		# Später prüfen wir hier die echten Level
		btn.disabled = not skills.can_unlock_skill(sd, 99)
		
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
		var current_btn = skill_buttons[i]
		var current_data = skill_data_refs[i]
		if current_btn == null or current_data == null: continue
			
		for prereq_id in current_data.prerequisite_skills:
			var prereq_btn : Button = null
			for j in count:
				if skill_data_refs[j] != null and skill_data_refs[j].id == prereq_id:
					prereq_btn = skill_buttons[j]
					break
			
			if prereq_btn != null:
				var line = Line2D.new()
				line.width = 6.0
				line.default_color = Color(1.0, 0.85, 0.2, 1.0) # Strahlendes Gold
				# Wir lassen den z_index weg, damit sie nicht hinter dem Hintergrund verschwinden!
				
				var pos1 = prereq_btn.position + (prereq_btn.size / 2.0)
				var pos2 = current_btn.position + (current_btn.size / 2.0)
				
				line.add_point(pos1)
				line.add_point(pos2)
				map_canvas.add_child(line)
				
				# Der geniale Godot-Trick: Wir schieben die Linie im Baum an Position 1, 
				# also genau ZWISCHEN den Hintergrund (Index 0) und die Buttons!
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
				_set_zoom(_zoom + 0.01) # Reinzoomen
				accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(_zoom - 0.01) # Rauszoomen
				accept_event()

	# Panning ausführen
	elif event is InputEventMouseMotion and _is_panning:
		scroll_horizontal -= int(event.relative.x)
		scroll_vertical -= int(event.relative.y)

func _set_zoom(new_zoom: float) -> void:
	# Begrenze den Zoom (zwischen 40% und 200%)
	_zoom = clamp(new_zoom, 0.4, 2.0)
	
	# Vergrößere/Verkleinere die Leinwand
	map_canvas.scale = Vector2(_zoom, _zoom)
	
	# Passe den Scroll-Bereich an, damit die Balken beim Zoomen nicht kaputt gehen
	map_canvas.custom_minimum_size = _base_canvas_size * _zoom
