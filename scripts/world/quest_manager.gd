extends Node

signal quests_changed

## A quest Dictionary must contain:
##   "title_key"  : String  – translation key for the title
##   "giver_key"  : String  – translation key for the NPC name
##   "desc_key"   : String  – translation key for the description
##   "reward_key" : String  – translation key for the reward text
##   "rank"       : String  – rank letter (F / E / D / C / B / A / S / S+ / S++)

var _active_quests    : Array[Dictionary] = []
var _completed_quests : Array[Dictionary] = []


func _ready() -> void:
	DialogManager.quest_offered.connect(accept_quest)


# ── Public API ────────────────────────────────────────────────────────────────

## Accept a quest. Returns false if already active or completed.
func accept_quest(quest: Dictionary) -> bool:
	var id : String = _quest_id(quest)
	if id.is_empty() or is_quest_active(id) or is_quest_completed(id):
		return false
	_active_quests.append(quest.duplicate())
	quests_changed.emit()
	return true


## Mark an active quest as completed. Returns false if not found.
func complete_quest(quest_id: String) -> bool:
	for i : int in _active_quests.size():
		if _quest_id(_active_quests[i]) == quest_id:
			var q : Dictionary = _active_quests[i]
			_active_quests.remove_at(i)
			_completed_quests.append(q)
			quests_changed.emit()
			return true
	return false


func is_quest_active(quest_id: String) -> bool:
	for q : Dictionary in _active_quests:
		if _quest_id(q) == quest_id:
			return true
	return false


func is_quest_completed(quest_id: String) -> bool:
	for q : Dictionary in _completed_quests:
		if _quest_id(q) == quest_id:
			return true
	return false


func get_active_quests() -> Array[Dictionary]:
	return _active_quests


func get_completed_quests() -> Array[Dictionary]:
	return _completed_quests


func get_active_count() -> int:
	return _active_quests.size()


# ── Internal ──────────────────────────────────────────────────────────────────

func _quest_id(quest: Dictionary) -> String:
	return quest.get("title_key", "") as String
