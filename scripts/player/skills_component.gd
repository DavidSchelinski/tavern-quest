extends Node

## Tracks which skills the player has unlocked and their current levels,
## plus the 7-slot active-skill hotbar.

# Key: skill id (String) → Value: current level (int)
var _unlocked_skills : Dictionary = {}

# 7 hotbar slots, each holds a skill id or "" for empty.
var _hotbar : Array = ["", "", "", "", "", "", ""]


func can_unlock_skill(skill_data: SkillData, current_player_level: int) -> bool:
	if current_player_level < skill_data.required_player_level:
		return false
	var current_level : int = _unlocked_skills.get(skill_data.id, 0) as int
	if current_level >= skill_data.max_level:
		return false
	for prereq_id : String in skill_data.prerequisite_skills:
		if not _unlocked_skills.has(prereq_id):
			return false
	return true


func unlock_or_upgrade_skill(skill_data: SkillData) -> void:
	var current_level : int = _unlocked_skills.get(skill_data.id, 0) as int
	_unlocked_skills[skill_data.id] = current_level + 1


func equip_skill(skill_id: String, hotbar_index: int) -> void:
	if hotbar_index < 0 or hotbar_index > 6:
		return
	_hotbar[hotbar_index] = skill_id
