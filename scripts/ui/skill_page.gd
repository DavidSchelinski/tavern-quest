extends Control

## Skill page inside the InGameMenu.
## Wraps the existing skill_map_ui.tscn scene.

var _player_ref    : Node3D = null
var _skill_map_inst: Node = null
var _sk_pts_lbl    : Label = null


func setup(player: Node3D) -> void:
	_player_ref = player
	if _skill_map_inst != null and _skill_map_inst.has_method("setup"):
		_skill_map_inst.setup(player)


func refresh() -> void:
	if _skill_map_inst != null and _skill_map_inst.has_method("refresh_ui"):
		_skill_map_inst.refresh_ui()


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	clip_contents = true
	var panel_w := size.x if size.x > 0 else 900.0
	var page_h := size.y if size.y > 0 else 560.0
	var p := 10.0

	var title := Label.new()
	title.name = "SkillTitle"
	title.text = "Fähigkeiten (Skills)"
	title.position = Vector2(p, p)
	title.size = Vector2(500, 28)
	title.add_theme_font_size_override("font_size", UITheme.TITLE_SIZE)
	title.add_theme_color_override("font_color", UITheme.TEXT_TITLE)
	add_child(title)

	_sk_pts_lbl = Label.new()
	_sk_pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sk_pts_lbl.position = Vector2(p, p)
	_sk_pts_lbl.size = Vector2(panel_w - p * 2, 28)
	_sk_pts_lbl.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	_sk_pts_lbl.add_theme_color_override("font_color", UITheme.TEXT_POSITIVE)
	add_child(_sk_pts_lbl)

	var sep := ColorRect.new()
	sep.position = Vector2(p, p + 34)
	sep.size = Vector2(panel_w - p * 2, 1)
	sep.color = UITheme.SEPARATOR
	add_child(sep)

	# Load the visual skill map scene
	var map_scene = load("res://scenes/ui/skill_map_ui.tscn")
	if map_scene:
		var map_inst = map_scene.instantiate()
		map_inst.position = Vector2(0, 40)
		map_inst.size = Vector2(panel_w, page_h - 40)
		map_inst.points_label = _sk_pts_lbl
		add_child(map_inst)
		_skill_map_inst = map_inst
