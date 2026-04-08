extends Node

## Drives dialog playback. Load a dialog JSON, advance through nodes, present choices.
##
## Dialog JSON format:
## {
##   "nodes": {
##     "start": {
##       "speaker": "NPC_BARTENDER",      // translation key for speaker name
##       "text": "BARTENDER_GREETING",     // translation key for dialog text
##       "voice": "BARTENDER_GREETING",    // VoiceOver key (optional)
##       "choices": [                       // omit or empty for auto-advance
##         { "text": "CHOICE_KEY", "next": "node_id" },
##         { "text": "DIALOG_GOODBYE", "next": "" }    // "" or missing = end dialog
##       ],
##       "next": "node_id"                // for choiceless nodes, auto-advance target
##     }
##   }
## }

signal dialog_started(npc: Node3D)
signal dialog_ended(npc: Node3D)
signal node_displayed(speaker: String, text: String, choices: Array)
signal quest_offered(quest: Dictionary)

var _current_npc   : Node3D    = null
var _current_data  : Dictionary = {}
var _current_node  : String    = ""
var _active        : bool      = false


func is_active() -> bool:
	return _active


## Start a dialog from a JSON file path. The NPC reference is stored for signals.
func start(npc: Node3D, dialog_path: String, start_node: String = "start") -> void:
	var file := FileAccess.open(dialog_path, FileAccess.READ)
	if file == null:
		push_error("DialogManager: could not open %s" % dialog_path)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("DialogManager: JSON parse error in %s: %s" % [dialog_path, json.get_error_message()])
		return
	start_from_data(npc, json.data, start_node)


## Start a dialog from an already-parsed Dictionary.
func start_from_data(npc: Node3D, data: Dictionary, start_node: String = "start") -> void:
	_current_npc  = npc
	_current_data = data.get("nodes", {})
	_active       = true
	dialog_started.emit(npc)
	show_node(start_node)


## Display a specific dialog node.
func show_node(node_id: String) -> void:
	if node_id.is_empty() or not _current_data.has(node_id):
		end()
		return

	_current_node = node_id
	var node : Dictionary = _current_data[node_id]

	var speaker := tr(node.get("speaker", ""))
	var text    := tr(node.get("text", ""))

	# Play voice-over if available
	var voice_key : String = node.get("voice", "")
	if not voice_key.is_empty():
		VoiceOver.play(voice_key)

	# Build choices array
	var choices : Array = []
	var raw_choices : Array = node.get("choices", [])
	for c in raw_choices:
		choices.append({
			"text": tr(c.get("text", "")),
			"next": c.get("next", ""),
		})

	node_displayed.emit(speaker, text, choices)

	# Trigger quest offer if this node carries give_quest data.
	var give_quest : Variant = node.get("give_quest", null)
	if give_quest != null and give_quest is Dictionary:
		var quest_id : String = (give_quest as Dictionary).get("title_key", "")
		if not QuestManager.is_quest_active(quest_id) and not QuestManager.is_quest_completed(quest_id):
			quest_offered.emit(give_quest as Dictionary)

	# Collect all pending board quest rewards.
	if node.get("collect_all_board_rewards", false):
		QuestManager.mark_all_board_rewards_collected()

	# Handle quest turn-in: check inventory, remove item, complete quest.
	# If the player lacks the required item, redirect to the fail node instead.
	var turn_in : Variant = node.get("turn_in_quest", null)
	if turn_in != null and turn_in is Dictionary:
		var quest_id : String = (turn_in as Dictionary).get("quest_id", "")
		var item_id  : String = (turn_in as Dictionary).get("item_id", "")
		var fail_node : String = (turn_in as Dictionary).get("fail", "")
		var needs_item : bool = not item_id.is_empty()
		if QuestManager.is_quest_active(quest_id) and (not needs_item or InventoryManager.has_item(item_id)):
			if needs_item:
				InventoryManager.remove_item_by_id(item_id, 1)
			QuestManager.complete_quest(quest_id)
		elif not fail_node.is_empty():
			show_node(fail_node)
			return

	# If no choices, auto-advance on next interaction (or after a delay)
	if choices.is_empty():
		var next : String = node.get("next", "")
		if next.is_empty():
			# Will end on next advance call
			_current_node = ""


## Called when the player selects a choice (by index).
func select_choice(index: int) -> void:
	if not _active:
		return
	var node : Dictionary = _current_data.get(_current_node, {})
	var choices : Array = node.get("choices", [])

	if index >= 0 and index < choices.size():
		var next : String = choices[index].get("next", "")
		show_node(next)
	else:
		# No choices — advance to "next" or end
		var next : String = node.get("next", "")
		show_node(next)


## Advance a choiceless dialog node.
func advance() -> void:
	if not _active:
		return
	var node : Dictionary = _current_data.get(_current_node, {})
	var choices : Array = node.get("choices", [])
	if choices.is_empty():
		var next : String = node.get("next", "")
		show_node(next)


## End the current dialog.
func end() -> void:
	if not _active:
		return
	_active = false
	var npc := _current_npc
	_current_npc  = null
	_current_data = {}
	_current_node = ""
	dialog_ended.emit(npc)
