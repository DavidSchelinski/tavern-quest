class_name WorldSelectionMenu
extends Control

## Overlay-Menü zur Welten-Auswahl und -Erstellung.
## Wird vom Hauptmenü vor dem Start (Solo oder Host) geöffnet.
## Emittiert world_confirmed(world_name) wenn der Spieler eine Welt bestätigt.

signal world_confirmed(world_name: String)

var _world_list   : ItemList
var _new_name_fld : LineEdit
var _load_btn     : Button
var _delete_btn   : Button
var _error_label  : Label
var _delete_confirm_panel : Panel = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_ui()


## Öffnet das Menü und aktualisiert die Weltliste.
func show_menu() -> void:
	_refresh_list()
	_new_name_fld.text  = ""
	_error_label.text   = ""
	_load_btn.disabled  = true
	_delete_btn.disabled = true
	visible             = true


# ── UI-Aufbau ─────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Dunkler Hintergrund
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(520, 500)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   24)
	margin.add_theme_constant_override("margin_right",  24)
	margin.add_theme_constant_override("margin_top",    20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	# ── Titel ─────────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "Welt auswählen"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)

	# ── Vorhandene Welten ─────────────────────────────────────────────────────
	var list_lbl := Label.new()
	list_lbl.text    = "Vorhandene Welten:"
	list_lbl.modulate = Color(0.75, 0.75, 0.75)
	col.add_child(list_lbl)

	_world_list = ItemList.new()
	_world_list.custom_minimum_size = Vector2(0, 180)
	_world_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_world_list.item_selected.connect(_on_world_selected)
	col.add_child(_world_list)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	col.add_child(btn_row)

	_load_btn          = Button.new()
	_load_btn.text     = "Ausgewählte Welt laden"
	_load_btn.disabled = true
	_load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_btn.pressed.connect(_on_load_pressed)
	btn_row.add_child(_load_btn)

	_delete_btn          = Button.new()
	_delete_btn.text     = "Löschen"
	_delete_btn.disabled = true
	_delete_btn.custom_minimum_size = Vector2(100, 0)
	_delete_btn.pressed.connect(_on_delete_pressed)
	btn_row.add_child(_delete_btn)

	# ── Trennlinie ────────────────────────────────────────────────────────────
	col.add_child(HSeparator.new())

	# ── Neue Welt ─────────────────────────────────────────────────────────────
	var new_lbl := Label.new()
	new_lbl.text    = "Neue Welt erstellen:"
	new_lbl.modulate = Color(0.75, 0.75, 0.75)
	col.add_child(new_lbl)

	var new_row := HBoxContainer.new()
	new_row.add_theme_constant_override("separation", 8)
	col.add_child(new_row)

	_new_name_fld                   = LineEdit.new()
	_new_name_fld.placeholder_text  = "Weltname (z.B. Meine_Welt)..."
	_new_name_fld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_name_fld.text_submitted.connect(func(_t: String) -> void: _on_create_pressed())
	new_row.add_child(_new_name_fld)

	var create_btn := Button.new()
	create_btn.text = "Erstellen"
	create_btn.pressed.connect(_on_create_pressed)
	new_row.add_child(create_btn)

	# ── Fehler / Status ───────────────────────────────────────────────────────
	_error_label                      = Label.new()
	_error_label.text                 = ""
	_error_label.modulate             = Color(1.0, 0.4, 0.4)
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_error_label)

	# ── Abbrechen ─────────────────────────────────────────────────────────────
	var cancel := Button.new()
	cancel.text = "Abbrechen"
	cancel.pressed.connect(func() -> void: visible = false)
	col.add_child(cancel)


# ── Weltliste ─────────────────────────────────────────────────────────────────

func _refresh_list() -> void:
	_world_list.clear()
	var worlds := SaveManager.list_available_worlds()
	if worlds.is_empty():
		_world_list.add_item("(Noch keine Welten vorhanden – erstelle eine!)")
		_world_list.set_item_selectable(0, false)
		return
	for w: String in worlds:
		var meta : Dictionary = SaveManager.get_world_meta(w)
		var last : String     = _fmt_date(meta.get("last_played", 0.0))
		var mode : String     = meta.get("mode", "?")
		_world_list.add_item("%s   –   %s   [%s]" % [w, last, mode])
		_world_list.set_item_metadata(_world_list.item_count - 1, w)


func _fmt_date(unix: float) -> String:
	if unix == 0.0:
		return "nie gespielt"
	var dt := Time.get_datetime_dict_from_unix_time(int(unix))
	return "%02d.%02d.%d" % [dt["day"], dt["month"], dt["year"]]


# ── Callbacks ─────────────────────────────────────────────────────────────────

func _on_world_selected(_idx: int) -> void:
	_load_btn.disabled = false
	_delete_btn.disabled = false
	_error_label.text  = ""


func _on_load_pressed() -> void:
	var selected := _world_list.get_selected_items()
	if selected.is_empty():
		return
	var world_name: String = _world_list.get_item_metadata(selected[0]) as String
	if world_name.is_empty():
		return
	visible = false
	world_confirmed.emit(world_name)


func _on_create_pressed() -> void:
	var raw: String    = _new_name_fld.text.strip_edges()
	var clean: String  = _sanitize_name(raw)
	if clean.is_empty():
		_error_label.text = "Ungültiger Name. Erlaubt: Buchstaben, Zahlen, _ und -"
		return
	_error_label.text = ""
	visible = false
	world_confirmed.emit(clean)


func _on_delete_pressed() -> void:
	var selected := _world_list.get_selected_items()
	if selected.is_empty():
		return
	var world_name: String = _world_list.get_item_metadata(selected[0]) as String
	if world_name.is_empty():
		return

	_close_delete_confirm()
	_delete_confirm_panel = Panel.new()
	_delete_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := UITheme.make_panel_style(UITheme.BG_DARK, UITheme.CANCEL_COLOR)
	_delete_confirm_panel.add_theme_stylebox_override("panel", style)
	add_child(_delete_confirm_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(16, 12)
	vbox.add_theme_constant_override("separation", 8)
	_delete_confirm_panel.add_child(vbox)

	var msg := Label.new()
	msg.text = "Welt '%s' wirklich löschen?\nAlle Spieler-Saves gehen verloren!" % world_name
	msg.add_theme_font_size_override("font_size", 14)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(msg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	var yes_btn := Button.new()
	yes_btn.text = "Ja, löschen"
	yes_btn.custom_minimum_size = Vector2(120, 36)
	yes_btn.pressed.connect(func() -> void:
		SaveManager.delete_world(world_name)
		_close_delete_confirm()
		_refresh_list()
		_load_btn.disabled = true
		_delete_btn.disabled = true
	)
	row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "Abbrechen"
	no_btn.custom_minimum_size = Vector2(120, 36)
	no_btn.pressed.connect(_close_delete_confirm)
	row.add_child(no_btn)

	_delete_confirm_panel.size = Vector2(360, 120)
	var vp := get_viewport().get_visible_rect().size
	_delete_confirm_panel.position = Vector2(
		(vp.x - 360) / 2.0, (vp.y - 120) / 2.0
	)


func _close_delete_confirm() -> void:
	if _delete_confirm_panel != null:
		_delete_confirm_panel.queue_free()
		_delete_confirm_panel = null


## Bereinigt den Weltnamen: nur Buchstaben, Zahlen, Unterstrich und Bindestrich.
## Verhindert Directory-Traversal und ungültige Pfade.
func _sanitize_name(raw: String) -> String:
	var result := ""
	for i: int in raw.length():
		var code: int = raw.unicode_at(i)
		var is_alpha  := (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var is_digit  := code >= 48 and code <= 57
		var is_safe   := code == 95 or code == 45   # _ or -
		if is_alpha or is_digit or is_safe:
			result += raw[i]
	return result
