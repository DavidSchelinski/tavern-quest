## Receptionist NPC — shows the player's guild rank and distributes
## rewards for quests accepted at the quest board.
## Also handles adventure group creation and applications.
extends NpcInteractable

var _group_create_popup : Control = null


func _ready() -> void:
	npc_name_key    = "NPC_RECEPTIONIST"
	interact_radius = 3.5
	super._ready()


func interact(player: Node3D) -> void:
	if _in_dialog:
		return
	if player == null or not is_instance_valid(player):
		return
	_in_dialog    = true
	_hint.visible = false
	_player_ref   = player
	if player.has_method("enter_dialog"):
		player.enter_dialog()
	DialogManager.start_from_data(self, _build_dialog_data(), player)


# ── Dialog construction ───────────────────────────────────────────────────────

func _build_dialog_data() -> Dictionary:
	var choices : Array = []

	# Always offer rank overview.
	choices.append({ "text": "RECEPTIONIST_CHOICE_RANK", "next": "rank_info" })

	# Reward collection if applicable.
	if not _player_ref.get_node("Quests").get_unrewarded_board_quests().is_empty():
		choices.append({ "text": "RECEPTIONIST_COLLECT_ALL", "next": "collect" })

	# Adventure group options
	var player_name := _get_player_name()
	var player_group := AdventureGroupManager.get_player_group(player_name)

	if player_group.is_empty():
		# Not in a group: offer create or browse/apply
		choices.append({
			"text": "Gruppe erstellen",
			"next": "",
			"action": "open_group_create",
			"action_data": {},
		})
		choices.append({ "text": "Abenteuergruppen ansehen", "next": "group_list" })
	else:
		if AdventureGroupManager.is_leader(player_name):
			choices.append({ "text": "Bewerbungen prüfen", "next": "group_applications" })
		choices.append({ "text": "Gruppenquest abschließen", "next": "group_complete_quest" })

	choices.append({ "text": "DIALOG_GOODBYE", "next": "" })

	var nodes : Dictionary = {
		"start": {
			"speaker": "NPC_RECEPTIONIST",
			"text":    "RECEPTIONIST_GREETING",
			"choices": choices
		},
		"rank_info": {
			"speaker": "NPC_RECEPTIONIST",
			"text":    _build_rank_text(),
			"next":    ""
		},
		"collect": {
			"speaker":                  "NPC_RECEPTIONIST",
			"text":                     "RECEPTIONIST_REWARD_GIVEN",
			"collect_all_board_rewards": true,
			"next":                     ""
		},
		"group_list": {
			"speaker": "NPC_RECEPTIONIST",
			"text":    _build_group_list_text(),
			"choices": _build_group_apply_choices()
		},
		"group_applications": {
			"speaker": "NPC_RECEPTIONIST",
			"text":    _build_applications_text(),
			"choices": _build_accept_choices()
		},
		"group_applied": {
			"speaker": "NPC_RECEPTIONIST",
			"text":    "Deine Bewerbung wurde eingereicht!",
			"next":    ""
		},
		"group_accepted": {
			"speaker": "NPC_RECEPTIONIST",
			"text":    "Bewerbung akzeptiert!",
			"next":    ""
		},
		"group_complete_quest": {
			"speaker": "NPC_RECEPTIONIST",
			"text":    _build_group_quest_complete_text(),
			"next":    ""
		}
	}

	return { "nodes": nodes }


func _get_player_name() -> String:
	if _player_ref == null:
		return ""
	var skills : Node = _player_ref.get_node_or_null("Skills")
	return skills.player_uuid if skills != null else ""


func _build_group_list_text() -> String:
	var groups := AdventureGroupManager.get_all_groups()
	if groups.is_empty():
		return "Es gibt derzeit keine Abenteuergruppen.\nDu kannst eine eigene Gruppe erstellen."
	var lines : PackedStringArray = ["Aktuelle Abenteuergruppen:\n"]
	for g : Dictionary in groups:
		lines.append("  %s — Leiter: %s (%d Mitglieder)" % [g["name"], g["leader"], g["member_count"]])
	return "\n".join(lines)


func _build_group_apply_choices() -> Array:
	var choices : Array = []
	var groups := AdventureGroupManager.get_all_groups()
	var player_name := _get_player_name()
	for g : Dictionary in groups:
		choices.append({
			"text": "Bewerben: %s" % g["name"],
			"next": "group_applied",
			"action": "apply_group",
			"action_data": { "group": g["name"], "player": player_name },
		})
	choices.append({ "text": "Zurück", "next": "start" })
	return choices


func _build_applications_text() -> String:
	var player_name := _get_player_name()
	var group_name := AdventureGroupManager.get_player_group(player_name)
	var apps := AdventureGroupManager.get_group_applications(group_name)
	if apps.is_empty():
		return "Keine offenen Bewerbungen für deine Gruppe."
	var lines : PackedStringArray = ["Offene Bewerbungen:\n"]
	for app_name : String in apps:
		lines.append("  - %s" % app_name)
	return "\n".join(lines)


func _build_accept_choices() -> Array:
	var choices : Array = []
	var player_name := _get_player_name()
	var group_name := AdventureGroupManager.get_player_group(player_name)
	var apps := AdventureGroupManager.get_group_applications(group_name)
	for app_name : String in apps:
		choices.append({
			"text": "Akzeptieren: %s" % app_name,
			"next": "group_accepted",
			"action": "accept_application",
			"action_data": { "group": group_name, "player": app_name },
		})
	choices.append({ "text": "Zurück", "next": "start" })
	return choices


func _build_group_quest_complete_text() -> String:
	var player_name := _get_player_name()
	var group_name := AdventureGroupManager.get_player_group(player_name)
	if group_name.is_empty():
		return "Du bist in keiner Gruppe."
	var sq := AdventureGroupManager.get_shared_quest(group_name)
	if sq.is_empty():
		return "Eure Gruppe hat keine aktive Gruppenquest."
	# Check if the quest is completed
	var quests : Node = _player_ref.get_node_or_null("Quests")
	if quests != null and quests.is_quest_completed(sq):
		# Distribute rewards split among group members
		var members := AdventureGroupManager.get_group_members(group_name)
		AdventureGroupManager.clear_shared_quest(group_name)
		return "Gruppenquest abgeschlossen! Belohnung wird auf %d Mitglieder aufgeteilt." % members.size()
	return "Die Gruppenquest '%s' ist noch nicht abgeschlossen." % tr(sq)


func _build_rank_text() -> String:
	var rank     : String = _player_ref.get_node("GuildRank").get_rank()
	var pts      : int    = _player_ref.get_node("GuildRank").get_points()
	var needed   : int    = _player_ref.get_node("GuildRank").get_points_needed()
	var is_max   : bool   = _player_ref.get_node("GuildRank").is_max_rank()
	var is_ready : bool   = _player_ref.get_node("GuildRank").is_promotion_ready()
	var active   : bool   = _player_ref.get_node("Quests").is_quest_active(_player_ref.get_node("GuildRank").get_promo_quest_key())

	var lines : PackedStringArray = []
	lines.append(tr("RECEPTIONIST_RANK_INFO_FMT") % [rank, pts, needed if not is_max else pts])

	if is_max:
		lines.append(tr("RECEPTIONIST_RANK_MAX"))
	elif active:
		lines.append(tr("RECEPTIONIST_PROMO_ACTIVE"))
	elif is_ready:
		lines.append(tr("RECEPTIONIST_RANK_READY"))
	else:
		lines.append(tr("RECEPTIONIST_RANK_PROGRESS") % [needed - pts])

	return "\n".join(lines)


# ── Group creation popup ─────────────────────────────────────────────────────

func show_group_create_popup() -> void:
	if _group_create_popup != null:
		return
	if _player_ref == null:
		return

	# Create a popup on the player's UI layer
	var canvas := _player_ref.get_node_or_null("UILayer") as CanvasLayer
	if canvas == null:
		canvas = _player_ref.get_viewport() as Node

	_group_create_popup = Control.new()
	_group_create_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(_group_create_popup)

	# Dimmed background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.5)
	_group_create_popup.add_child(bg)

	# Panel
	var panel := Panel.new()
	panel.size = Vector2(400.0, 200.0)
	panel.position = Vector2(
		(ProjectSettings.get_setting("display/window/size/viewport_width", 1152) - 400.0) / 2.0,
		(ProjectSettings.get_setting("display/window/size/viewport_height", 648) - 200.0) / 2.0,
	)
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.BG_DARK, UITheme.BORDER, 6))
	_group_create_popup.add_child(panel)

	# Title
	var title := Label.new()
	title.text = "Abenteuergruppe erstellen"
	title.position = Vector2(20.0, 16.0)
	title.size = Vector2(360.0, 28.0)
	title.add_theme_font_size_override("font_size", UITheme.TITLE_SIZE)
	title.add_theme_color_override("font_color", UITheme.TEXT_TITLE)
	panel.add_child(title)

	# Name input
	var name_label := Label.new()
	name_label.text = "Gruppenname:"
	name_label.position = Vector2(20.0, 56.0)
	name_label.size = Vector2(360.0, 22.0)
	name_label.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	name_label.add_theme_color_override("font_color", UITheme.TEXT_NORMAL)
	panel.add_child(name_label)

	var name_input := LineEdit.new()
	name_input.name = "NameInput"
	name_input.position = Vector2(20.0, 80.0)
	name_input.size = Vector2(360.0, 32.0)
	name_input.placeholder_text = "Gruppenname eingeben..."
	name_input.max_length = 24
	name_input.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	panel.add_child(name_input)

	# Buttons
	var confirm_btn := Button.new()
	confirm_btn.text = "Erstellen"
	confirm_btn.position = Vector2(20.0, 130.0)
	confirm_btn.size = Vector2(170.0, 36.0)
	confirm_btn.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	confirm_btn.add_theme_stylebox_override("normal", UITheme.make_panel_style(UITheme.CONFIRM_COLOR.darkened(0.5), UITheme.CONFIRM_COLOR, 4))
	confirm_btn.add_theme_color_override("font_color", UITheme.TEXT_NORMAL)
	confirm_btn.pressed.connect(_on_group_create_confirm.bind(name_input))
	panel.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Abbrechen"
	cancel_btn.position = Vector2(210.0, 130.0)
	cancel_btn.size = Vector2(170.0, 36.0)
	cancel_btn.add_theme_font_size_override("font_size", UITheme.NORMAL_SIZE)
	cancel_btn.add_theme_stylebox_override("normal", UITheme.make_panel_style(UITheme.CANCEL_COLOR.darkened(0.5), UITheme.CANCEL_COLOR, 4))
	cancel_btn.add_theme_color_override("font_color", UITheme.TEXT_NORMAL)
	cancel_btn.pressed.connect(_close_group_create_popup)
	panel.add_child(cancel_btn)

	name_input.grab_focus()


func _on_group_create_confirm(name_input: LineEdit) -> void:
	var group_name := name_input.text.strip_edges()
	if group_name.is_empty():
		return
	var player_name := _get_player_name()
	if player_name.is_empty():
		return

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		AdventureGroupManager.rpc_create_group.rpc_id(1, group_name, player_name)
	else:
		AdventureGroupManager.create_group(group_name, player_name)

	_close_group_create_popup()


func _close_group_create_popup() -> void:
	if _group_create_popup != null:
		_group_create_popup.queue_free()
		_group_create_popup = null
