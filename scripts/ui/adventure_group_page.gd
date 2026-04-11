extends Control

## Adventure Group page inside the InGameMenu.
## Shows current group members, online status, shared quest, and group management.

var _player_ref     : Node3D = null
var _member_list    : VBoxContainer = null
var _info_panel     : Control = null
var _no_group_hint  : Label = null
var _group_title    : Label = null
var _shared_quest   : Label = null
var _leave_btn      : Button = null
var _create_panel   : Control = null
var _create_input   : LineEdit = null

const LIST_W   : float = 260.0
const PADDING  : float = 16.0


func setup(player: Node3D) -> void:
	_player_ref = player
	AdventureGroupManager.groups_changed.connect(_on_groups_changed)
	AdventureGroupManager.applications_changed.connect(_on_groups_changed)


func refresh() -> void:
	_refresh_page()


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var panel_w := size.x if size.x > 0 else 900.0
	var page_h := size.y if size.y > 0 else 560.0

	# Title
	var title := Label.new()
	title.text = "Abenteuergruppe"
	title.position = Vector2(PADDING, 8.0)
	title.size = Vector2(panel_w - PADDING * 2.0, 28.0)
	title.add_theme_font_size_override("font_size", UITheme.TITLE_SIZE)
	title.add_theme_color_override("font_color", UITheme.TEXT_TITLE)
	add_child(title)

	var content_y : float = 40.0
	var content_h : float = page_h - content_y - PADDING

	# ── No group hint (shown when player is not in a group) ──────────────────
	_no_group_hint = Label.new()
	_no_group_hint.text = "Du bist in keiner Abenteuergruppe.\nErstelle eine neue oder bewirb dich bei der Rezeptionistin."
	_no_group_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_no_group_hint.position = Vector2(PADDING, content_y + 20.0)
	_no_group_hint.size = Vector2(panel_w - PADDING * 2.0, 60.0)
	_no_group_hint.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	_no_group_hint.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	add_child(_no_group_hint)

	# ── Create group panel (shown when not in a group) ───────────────────────
	_create_panel = Control.new()
	_create_panel.position = Vector2(PADDING, content_y + 90.0)
	_create_panel.size = Vector2(400.0, 80.0)
	add_child(_create_panel)

	var create_label := Label.new()
	create_label.text = "Neue Gruppe erstellen:"
	create_label.position = Vector2(0, 0)
	create_label.size = Vector2(200.0, 24.0)
	create_label.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	create_label.add_theme_color_override("font_color", UITheme.TEXT_NORMAL)
	_create_panel.add_child(create_label)

	_create_input = LineEdit.new()
	_create_input.position = Vector2(0, 28.0)
	_create_input.size = Vector2(250.0, 32.0)
	_create_input.placeholder_text = "Gruppenname..."
	_create_input.max_length = 24
	_create_input.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	_create_panel.add_child(_create_input)

	var create_btn := Button.new()
	create_btn.text = "Erstellen"
	create_btn.position = Vector2(260.0, 28.0)
	create_btn.size = Vector2(100.0, 32.0)
	create_btn.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	create_btn.add_theme_stylebox_override("normal", UITheme.make_panel_style(UITheme.CONFIRM_COLOR.darkened(0.5), UITheme.CONFIRM_COLOR, 4))
	create_btn.add_theme_color_override("font_color", UITheme.TEXT_NORMAL)
	create_btn.pressed.connect(_on_create_pressed)
	_create_panel.add_child(create_btn)

	# ── Group info panel (shown when in a group) ─────────────────────────────
	_info_panel = Control.new()
	_info_panel.position = Vector2(PADDING, content_y)
	_info_panel.size = Vector2(panel_w - PADDING * 2.0, content_h)
	_info_panel.visible = false
	add_child(_info_panel)

	_group_title = Label.new()
	_group_title.position = Vector2(0, 0)
	_group_title.size = Vector2(panel_w - PADDING * 2.0, 28.0)
	_group_title.add_theme_font_size_override("font_size", 16)
	_group_title.add_theme_color_override("font_color", UITheme.TEXT_ACTIVE)
	_info_panel.add_child(_group_title)

	# Separator
	var sep := UITheme.make_hsep(0, 30.0, panel_w - PADDING * 2.0)
	_info_panel.add_child(sep)

	# Shared quest label
	_shared_quest = Label.new()
	_shared_quest.position = Vector2(0, 36.0)
	_shared_quest.size = Vector2(panel_w - PADDING * 2.0, 22.0)
	_shared_quest.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	_shared_quest.add_theme_color_override("font_color", UITheme.TEXT_DIMMED)
	_info_panel.add_child(_shared_quest)

	# Member list (scrollable)
	var member_label := Label.new()
	member_label.text = "Mitglieder:"
	member_label.position = Vector2(0, 64.0)
	member_label.size = Vector2(200.0, 22.0)
	member_label.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	member_label.add_theme_color_override("font_color", UITheme.TEXT_NORMAL)
	_info_panel.add_child(member_label)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 88.0)
	scroll.size = Vector2(LIST_W, content_h - 88.0 - 50.0)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info_panel.add_child(scroll)

	_member_list = VBoxContainer.new()
	_member_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_member_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_member_list)

	# Leave button
	_leave_btn = Button.new()
	_leave_btn.text = "Gruppe verlassen"
	_leave_btn.position = Vector2(0, content_h - 40.0)
	_leave_btn.size = Vector2(180.0, 34.0)
	_leave_btn.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	_leave_btn.add_theme_stylebox_override("normal", UITheme.make_panel_style(UITheme.CANCEL_COLOR.darkened(0.5), UITheme.CANCEL_COLOR, 4))
	_leave_btn.add_theme_color_override("font_color", UITheme.TEXT_NORMAL)
	_leave_btn.pressed.connect(_on_leave_pressed)
	_info_panel.add_child(_leave_btn)

	# ── Applications panel (shown to leader, right side) ─────────────────────
	var apps_label := Label.new()
	apps_label.name = "AppsLabel"
	apps_label.text = "Bewerbungen:"
	apps_label.position = Vector2(LIST_W + 40.0, 64.0)
	apps_label.size = Vector2(200.0, 22.0)
	apps_label.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	apps_label.add_theme_color_override("font_color", UITheme.TEXT_NORMAL)
	_info_panel.add_child(apps_label)

	var apps_scroll := ScrollContainer.new()
	apps_scroll.name = "AppsScroll"
	apps_scroll.position = Vector2(LIST_W + 40.0, 88.0)
	apps_scroll.size = Vector2(LIST_W, content_h - 88.0 - 50.0)
	apps_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	apps_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info_panel.add_child(apps_scroll)

	var apps_box := VBoxContainer.new()
	apps_box.name = "AppsBox"
	apps_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apps_box.add_theme_constant_override("separation", 4)
	apps_scroll.add_child(apps_box)


func _on_groups_changed() -> void:
	if visible:
		_refresh_page()


func _refresh_page() -> void:
	if _player_ref == null:
		return

	var player_name := _get_player_name()
	var group_name := AdventureGroupManager.get_player_group(player_name)

	var in_group := not group_name.is_empty()
	_no_group_hint.visible = not in_group
	_create_panel.visible = not in_group
	_info_panel.visible = in_group

	if not in_group:
		return

	# Update group title
	var is_leader := AdventureGroupManager.is_leader(player_name)
	_group_title.text = group_name + (" (Leiter)" if is_leader else "")

	# Shared quest
	var sq := AdventureGroupManager.get_shared_quest(group_name)
	_shared_quest.text = "Gruppenquest: " + (tr(sq) if not sq.is_empty() else "Keine")

	# Member list
	for child in _member_list.get_children():
		child.queue_free()

	var members : Array = AdventureGroupManager.get_group_members(group_name)
	var online_players := _get_online_players()
	for member_name: String in members:
		var is_online : bool = member_name in online_players
		_add_member_entry(member_name, is_online, member_name == AdventureGroupManager._groups.get(group_name, {}).get("leader", ""))

	# Applications (only visible to leader)
	var apps_label := _info_panel.get_node_or_null("AppsLabel") as Label
	var apps_scroll := _info_panel.get_node_or_null("AppsScroll") as ScrollContainer
	if apps_label and apps_scroll:
		apps_label.visible = is_leader
		apps_scroll.visible = is_leader
		if is_leader:
			var apps_box := apps_scroll.get_node("AppsBox") as VBoxContainer
			for child in apps_box.get_children():
				child.queue_free()
			var apps : Array = AdventureGroupManager.get_group_applications(group_name)
			if apps.is_empty():
				var hint := Label.new()
				hint.text = "Keine Bewerbungen"
				hint.add_theme_font_size_override("font_size", UITheme.SMALL_SIZE)
				hint.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
				apps_box.add_child(hint)
			else:
				for app_name: String in apps:
					_add_application_entry(apps_box, group_name, app_name)


func _add_member_entry(member_name: String, is_online: bool, is_leader: bool) -> void:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(LIST_W - 8.0, 28.0)
	hbox.add_theme_constant_override("separation", 6)

	# Online indicator
	var dot := Label.new()
	dot.text = "●" if is_online else "○"
	dot.add_theme_font_size_override("font_size", 12)
	dot.add_theme_color_override("font_color", UITheme.TEXT_POSITIVE if is_online else UITheme.TEXT_DIMMED)
	dot.custom_minimum_size = Vector2(16.0, 0.0)
	hbox.add_child(dot)

	# Name
	var lbl := Label.new()
	lbl.text = member_name + (" ★" if is_leader else "")
	lbl.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	lbl.add_theme_color_override("font_color", UITheme.TEXT_ACTIVE if is_leader else UITheme.TEXT_NORMAL)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	hbox.add_child(lbl)

	_member_list.add_child(hbox)


func _add_application_entry(parent: VBoxContainer, group_name: String, app_name: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(LIST_W - 8.0, 32.0)
	hbox.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = app_name
	lbl.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	lbl.add_theme_color_override("font_color", UITheme.TEXT_NORMAL)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	hbox.add_child(lbl)

	var accept_btn := Button.new()
	accept_btn.text = "✓"
	accept_btn.custom_minimum_size = Vector2(32.0, 28.0)
	accept_btn.add_theme_font_size_override("font_size", 14)
	accept_btn.add_theme_stylebox_override("normal", UITheme.make_panel_style(UITheme.CONFIRM_COLOR.darkened(0.5), UITheme.CONFIRM_COLOR, 3))
	accept_btn.add_theme_color_override("font_color", Color.WHITE)
	var gn := group_name
	var an := app_name
	accept_btn.pressed.connect(func() -> void: _on_accept_application(gn, an))
	hbox.add_child(accept_btn)

	var reject_btn := Button.new()
	reject_btn.text = "✗"
	reject_btn.custom_minimum_size = Vector2(32.0, 28.0)
	reject_btn.add_theme_font_size_override("font_size", 14)
	reject_btn.add_theme_stylebox_override("normal", UITheme.make_panel_style(UITheme.CANCEL_COLOR.darkened(0.5), UITheme.CANCEL_COLOR, 3))
	reject_btn.add_theme_color_override("font_color", Color.WHITE)
	reject_btn.pressed.connect(func() -> void: _on_reject_application(gn, an))
	hbox.add_child(reject_btn)

	parent.add_child(hbox)


# ── Actions ──────────────────────────────────────────────────────────────────

func _on_create_pressed() -> void:
	var group_name := _create_input.text.strip_edges()
	if group_name.is_empty():
		return
	var player_name := _get_player_name()
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		AdventureGroupManager.rpc_create_group.rpc_id(1, group_name, player_name)
	else:
		AdventureGroupManager.create_group(group_name, player_name)
	_create_input.text = ""
	_refresh_page()


func _on_leave_pressed() -> void:
	var player_name := _get_player_name()
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		AdventureGroupManager.rpc_leave_group.rpc_id(1, player_name)
	else:
		AdventureGroupManager.leave_group(player_name)
	_refresh_page()


func _on_accept_application(group_name: String, app_name: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		AdventureGroupManager.rpc_accept_application.rpc_id(1, group_name, app_name)
	else:
		AdventureGroupManager.accept_application(group_name, app_name)
	_refresh_page()


func _on_reject_application(group_name: String, app_name: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		# No RPC for reject yet, but the leader is likely the server host
		AdventureGroupManager.reject_application(group_name, app_name)
	else:
		AdventureGroupManager.reject_application(group_name, app_name)
	_refresh_page()


# ── Helpers ──────────────────────────────────────────────────────────────────

func _get_player_name() -> String:
	if _player_ref == null:
		return ""
	var skills : Node = _player_ref.get_node_or_null("Skills")
	if skills != null:
		return skills.player_uuid
	return ""


func _get_online_players() -> Array[String]:
	var result : Array[String] = []
	var players_node := _player_ref.get_parent()
	if players_node == null:
		return result
	for child : Node in players_node.get_children():
		var skills : Node = child.get_node_or_null("Skills")
		if skills != null and not (skills.player_uuid as String).is_empty():
			result.append(skills.player_uuid)
	return result
