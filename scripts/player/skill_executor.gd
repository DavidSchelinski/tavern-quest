extends Node

## Handles skill activation from the hotbar.
## Manages cooldowns, stamina costs, and spawning skill effects in the world.

var _player : CharacterBody3D = null
var _cooldowns : Dictionary = {}   # skill_id → remaining cooldown (float)
var _skill_data_cache : Dictionary = {}


func setup(player: CharacterBody3D) -> void:
	_player = player


func _process(delta: float) -> void:
	# Tick cooldowns
	var to_remove : Array[String] = []
	for skill_id: String in _cooldowns:
		_cooldowns[skill_id] = (_cooldowns[skill_id] as float) - delta
		if (_cooldowns[skill_id] as float) <= 0.0:
			to_remove.append(skill_id)
	for skill_id: String in to_remove:
		_cooldowns.erase(skill_id)


func try_activate_slot(slot_index: int) -> void:
	if _player == null:
		return
	var skills: Node = _player.get_node_or_null("Skills")
	if skills == null:
		return
	var hotbar: Array = skills._hotbar
	if slot_index < 0 or slot_index >= hotbar.size():
		return
	var skill_id: String = hotbar[slot_index] as String
	if skill_id.is_empty():
		return

	# Must have unlocked the skill
	var level: int = skills.get_skill_level(skill_id)
	if level <= 0:
		return

	var sd := _get_skill_data(skill_id)
	if sd == null:
		return

	# Check cooldown
	if _cooldowns.has(skill_id):
		return

	# Check stamina cost
	var cost: float = sd.base_stamina_cost + sd.stamina_cost_per_level * (level - 1)
	if _player._stamina < cost:
		return

	# Deduct stamina
	_player._stamina -= cost

	# Set cooldown
	var cd: float = sd.cooldown - sd.cooldown_reduction_per_level * (level - 1)
	if cd > 0.0:
		_cooldowns[skill_id] = cd

	# Calculate damage
	var dmg: float = sd.base_damage_multiplier + sd.damage_per_level * (level - 1)
	dmg *= _player.get_node("Stats").get_damage_multiplier()

	# Spawn the skill effect
	_spawn_skill_effect(skill_id, dmg, level)


func _spawn_skill_effect(skill_id: String, damage: float, level: int) -> void:
	var effect_path := "res://scripts/skills/effects/" + skill_id + "_effect.gd"
	if not ResourceLoader.exists(effect_path):
		push_warning("SkillExecutor: No effect script for '%s'" % skill_id)
		return

	var effect_script: GDScript = load(effect_path) as GDScript
	var effect: Node3D = effect_script.new()
	effect.set("damage", damage)
	effect.set("skill_level", level)

	# Spawn position: in front of the player
	var player_pos := _player.global_position
	var forward := -_player.get_node("Pivot").global_transform.basis.z.normalized()
	effect.global_position = player_pos + forward * 1.5 + Vector3(0, 1.0, 0)
	effect.global_rotation.y = _player.get_node("Pivot").global_rotation.y

	# Add to world, not player (so player can walk away)
	_player.get_tree().current_scene.add_child(effect)


func get_cooldown_remaining(skill_id: String) -> float:
	return _cooldowns.get(skill_id, 0.0) as float


func _get_skill_data(skill_id: String) -> SkillData:
	if _skill_data_cache.has(skill_id):
		return _skill_data_cache[skill_id]
	var path := "res://scripts/skills/" + skill_id + ".tres"
	if ResourceLoader.exists(path):
		var res := load(path) as SkillData
		_skill_data_cache[skill_id] = res
		return res
	return null
