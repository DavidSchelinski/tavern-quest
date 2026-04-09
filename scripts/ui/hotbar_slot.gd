extends Panel

@export var slot_index: int = 0   # 0 – 6

@onready var _icon_rect  : TextureRect = $Icon  if has_node("Icon")  else null
@onready var _name_label : Label       = $Label if has_node("Label") else null


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
	var skills: Node = player.get_node_or_null("Skills")
	if skills == null:
		return

	skills.equip_skill(data["id"], slot_index)
	_show_skill(data)


func _show_skill(data: Dictionary) -> void:
	if _icon_rect != null:
		var icon: Texture2D = data.get("icon") as Texture2D
		_icon_rect.texture  = icon
		_icon_rect.visible  = icon != null

	if _name_label != null:
		_name_label.text    = data.get("id", "")
		_name_label.visible = true
