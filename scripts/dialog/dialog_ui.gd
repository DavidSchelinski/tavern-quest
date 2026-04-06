extends CanvasLayer

## In-game dialog UI. Shows speaker name, dialog text, and choice buttons.
## Listens to DialogManager signals.

var _root         : Control
var _panel        : Panel
var _speaker_lbl  : Label
var _text_lbl     : RichTextLabel
var _choices_box  : VBoxContainer
var _advance_hint : Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	DialogManager.node_displayed.connect(_on_node_displayed)
	DialogManager.dialog_started.connect(func(_npc: Node3D) -> void: visible = true)
	DialogManager.dialog_ended.connect(func(_npc: Node3D) -> void: visible = false)


func _input(event: InputEvent) -> void:
	if not visible or not DialogManager.is_active():
		return
	# If no choices visible, advance on interact/accept
	if _choices_box.get_child_count() == 0:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			DialogManager.advance()
			return
	# ESC cancels dialog
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		DialogManager.end()


func _on_node_displayed(speaker: String, text: String, choices: Array) -> void:
	_speaker_lbl.text = speaker
	_text_lbl.text = text

	# Clear old choice buttons
	for child in _choices_box.get_children():
		child.queue_free()

	if choices.is_empty():
		_advance_hint.visible = true
	else:
		_advance_hint.visible = false
		for i in range(choices.size()):
			var choice : Dictionary = choices[i]
			var btn := Button.new()
			btn.text = "%d. %s" % [i + 1, choice.get("text", "")]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.pressed.connect(_on_choice_pressed.bind(i))
			_choices_box.add_child(btn)
			# Keyboard shortcut: number keys
			if i < 9:
				var shortcut := Shortcut.new()
				var key_event := InputEventKey.new()
				key_event.keycode = KEY_1 + i
				shortcut.events = [key_event]
				btn.shortcut = shortcut


func _on_choice_pressed(index: int) -> void:
	DialogManager.select_choice(index)


# ──────────────────────────────────────────────────────────────────────────────
#  UI CONSTRUCTION
# ──────────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Bottom-aligned dialog box
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	anchor.offset_top    = -260
	anchor.offset_left   = 40
	anchor.offset_right  = -40
	anchor.offset_bottom = -30
	_root.add_child(anchor)

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   20)
	margin.add_theme_constant_override("margin_right",  20)
	margin.add_theme_constant_override("margin_top",    14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Speaker name
	_speaker_lbl = Label.new()
	_speaker_lbl.add_theme_font_size_override("font_size", 20)
	_speaker_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	vbox.add_child(_speaker_lbl)

	# Dialog text
	_text_lbl = RichTextLabel.new()
	_text_lbl.bbcode_enabled = true
	_text_lbl.fit_content = true
	_text_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_lbl.scroll_active = false
	vbox.add_child(_text_lbl)

	# Choices container
	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 4)
	vbox.add_child(_choices_box)

	# Advance hint (for choiceless nodes)
	_advance_hint = Label.new()
	_advance_hint.text = "[E]"
	_advance_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_advance_hint.modulate = Color(0.6, 0.6, 0.6)
	_advance_hint.visible = false
	vbox.add_child(_advance_hint)
