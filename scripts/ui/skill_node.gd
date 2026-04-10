extends Button

@export var skill_data: SkillData
var player_ref: Node = null


func _ready() -> void:
	if skill_data == null:
		return

	var lines: PackedStringArray = []
	lines.append(skill_data.display_name if skill_data.display_name != "" else skill_data.id)
	lines.append("─────────────────────")
	lines.append("%s  |  Max Level: %d" % [
		"Passiv" if skill_data.is_passive else "Aktiv",
		skill_data.max_level
	])
	if skill_data.base_stamina_cost > 0.0:
		lines.append("Stamina-Kosten: %.0f" % skill_data.base_stamina_cost)
	if skill_data.base_damage_multiplier != 1.0:
		lines.append("Schadensmod: x%.2f" % skill_data.base_damage_multiplier)
	if skill_data.required_player_level > 1:
		lines.append("Benötigt Spieler-Level: %d" % skill_data.required_player_level)
	if not skill_data.prerequisite_skills.is_empty():
		lines.append("Voraussetzungen: " + ", ".join(skill_data.prerequisite_skills))
	tooltip_text = "\n".join(lines)

	self.pressed.connect(_on_skill_pressed)
	update_visual_state(false)


func update_visual_state(is_unlocked: bool) -> void:
	if is_unlocked:
		self.modulate = Color(0.2, 1.0, 0.2, 1.0)
	else:
		self.modulate = Color(0.3, 0.3, 0.3, 1.0)


func _on_skill_pressed() -> void:
	print("Klick auf: ", skill_data.id)
	if player_ref == null:
		return
	var skills: Node = player_ref.get_node_or_null("Skills")
	if skills == null:
		print("Kauf fehlgeschlagen! Kein Skills-Node gefunden.")
		return

	print("Skillpunkte übrig: ", skills.skill_points)

	if not skills.can_unlock_skill(skill_data, 99):
		print("Kauf fehlgeschlagen! Punkte: ", skills.skill_points, " | Voraussetzungen erfüllt? Prüfe Konsole.")
		return

	if multiplayer.has_multiplayer_peer():
		# Multiplayer: Anfrage an Server schicken (Peer 1).
		# Die UI wird nach der Server-Bestätigung via skill_data_synced-Signal aktualisiert.
		print("Sende Kaufanfrage für '", skill_data.id, "' an Server...")
		skills.request_buy_skill.rpc_id(1, skill_data.id)
	else:
		# Singleplayer: Direkt kaufen.
		skills._do_unlock_skill(skill_data.id)
		print("Skill gekauft: ", skill_data.id, " | Punkte jetzt: ", skills.skill_points)
		update_visual_state(true)
		var menu: Node = get_parent().get_parent()
		if menu != null and menu.has_method("refresh_ui"):
			menu.refresh_ui()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if skill_data == null:
		return null
	if player_ref == null:
		return null
	var player: Node = player_ref
	var skills: Node = player.get_node_or_null("Skills")
	if skills == null or skills.get_skill_level(skill_data.id) <= 0:
		return null

	var preview: Control = Control.new()
	var lbl: Label = Label.new()
	lbl.text = skill_data.display_name if skill_data.display_name != "" else skill_data.id
	preview.add_child(lbl)
	lbl.position = -lbl.size / 2.0
	set_drag_preview(preview)

	return {"type": "skill", "id": skill_data.id}
