extends Button

@export var skill_data: SkillData

## Set by skill_menu.gd during setup().
var player_ref: Node = null


func _get_drag_data(_at_position: Vector2) -> Variant:
	if skill_data == null:
		return null
	var player: Node = player_ref
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	var skills: Node = player.get_node_or_null("Skills")
	if skills == null:
		return null
	var level: int = skills._unlocked_skills.get(skill_data.id, 0) as int
	if level <= 0:
		return null

	var preview: Control
	var icon: Texture2D = skill_data.get("icon") as Texture2D
	if icon != null:
		var tex := TextureRect.new()
		tex.texture                  = icon
		tex.custom_minimum_size      = Vector2(48, 48)
		tex.expand_mode              = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		preview = tex
	else:
		var lbl := Label.new()
		lbl.text                      = skill_data.display_name
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.45, 1.0))
		lbl.custom_minimum_size       = Vector2(80, 28)
		preview = lbl

	set_drag_preview(preview)

	var payload: Dictionary = {"type": "skill", "id": skill_data.id}
	if icon != null:
		payload["icon"] = icon
	return payload
