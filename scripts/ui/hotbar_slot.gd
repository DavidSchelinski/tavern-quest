extends Panel

@export var slot_index: int = 0


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		typeof(data) == TYPE_DICTIONARY
		and data.has("type")
		and data["type"] == "skill"
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	player.get_node("Skills").equip_skill(data["id"], slot_index)

	var lbl: Label = get_node_or_null("SkillLabel")
	if lbl == null:
		lbl = Label.new()
		lbl.name = "SkillLabel"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(lbl)

	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.size = self.size
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = data["id"]
