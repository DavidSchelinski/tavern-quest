extends Button

@export var skill_data: SkillData
var player_ref: Node = null

var _skill_data_cache: Dictionary = {}


func _ready() -> void:
	if skill_data == null:
		return
	_rebuild_tooltip()
	self.pressed.connect(_on_skill_pressed)
	update_visual_state(false)


func _rebuild_tooltip() -> void:
	if skill_data == null:
		return

	var lines: PackedStringArray = []
	lines.append(skill_data.display_name if skill_data.display_name != "" else skill_data.id)

	# Show current level if player ref available
	if player_ref != null:
		var skills: Node = player_ref.get_node_or_null("Skills")
		if skills != null:
			var level: int = skills.get_skill_level(skill_data.id)
			if level > 0:
				lines.append("Level: %d / %d" % [level, skill_data.max_level])

	if skill_data.description != "":
		lines.append(skill_data.description)

	lines.append("─────────────────────")
	lines.append("%s  |  Max Level: %d" % [
		"Passiv" if skill_data.is_passive else "Aktiv",
		skill_data.max_level
	])
	if skill_data.base_stamina_cost > 0.0:
		lines.append("Stamina-Kosten: %.0f" % skill_data.base_stamina_cost)
	if skill_data.base_damage_multiplier != 1.0:
		lines.append("Schadensmod: x%.2f" % skill_data.base_damage_multiplier)
	if skill_data.cooldown > 0.0:
		lines.append("Abklingzeit: %.1fs" % skill_data.cooldown)
	if skill_data.required_player_level > 1:
		lines.append("Benötigt Spieler-Level: %d" % skill_data.required_player_level)
	if not skill_data.prerequisite_skills.is_empty():
		# Show display names instead of raw IDs
		var prereq_names: PackedStringArray = []
		for prereq_id in skill_data.prerequisite_skills:
			var prereq_res := _load_skill_data(prereq_id)
			if prereq_res != null and prereq_res.display_name != "":
				prereq_names.append(prereq_res.display_name)
			else:
				prereq_names.append(prereq_id)
		lines.append("Voraussetzungen: " + ", ".join(prereq_names))
	tooltip_text = "\n".join(lines)


func _load_skill_data(skill_id: String) -> SkillData:
	if _skill_data_cache.has(skill_id):
		return _skill_data_cache[skill_id]
	var path := "res://scripts/skills/" + skill_id + ".tres"
	if ResourceLoader.exists(path):
		var res := load(path) as SkillData
		_skill_data_cache[skill_id] = res
		return res
	return null


func update_visual_state(is_unlocked: bool, level: int = 0) -> void:
	if is_unlocked:
		if skill_data != null and level >= skill_data.max_level:
			self.modulate = Color(1.0, 0.85, 0.2, 1.0)  # Gold = max level
		else:
			self.modulate = Color(0.2, 1.0, 0.2, 1.0)   # Green = unlocked
	else:
		self.modulate = Color(0.3, 0.3, 0.3, 1.0)        # Gray = locked

	# Update button text with level
	if skill_data != null:
		var name_text := skill_data.display_name if skill_data.display_name != "" else skill_data.id
		if level > 0 and skill_data.max_level > 1:
			text = "%s (Lv %d/%d)" % [name_text, level, skill_data.max_level]
		else:
			text = name_text


func _on_skill_pressed() -> void:
	if player_ref == null:
		return
	var skills: Node = player_ref.get_node_or_null("Skills")
	if skills == null:
		return

	if not skills.can_unlock_skill(skill_data, 99):
		return

	if multiplayer.has_multiplayer_peer():
		skills.request_buy_skill.rpc_id(1, skill_data.id)
	else:
		skills._do_unlock_skill(skill_data.id)
		var level: int = skills.get_skill_level(skill_data.id)
		update_visual_state(true, level)
		_rebuild_tooltip()
		var menu: Node = get_parent().get_parent()
		if menu != null and menu.has_method("refresh_ui"):
			menu.refresh_ui()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if skill_data == null or player_ref == null:
		return null
	var skills: Node = player_ref.get_node_or_null("Skills")
	if skills == null or skills.get_skill_level(skill_data.id) <= 0:
		return null

	var preview: Control = Control.new()
	var lbl: Label = Label.new()
	lbl.text = skill_data.display_name if skill_data.display_name != "" else skill_data.id
	preview.add_child(lbl)
	lbl.position = -lbl.size / 2.0
	set_drag_preview(preview)

	return {"type": "skill", "id": skill_data.id}
