extends Resource

class_name SkillData

@export var id                    : String = ""
@export var display_name         : String = ""
@export var is_passive           : bool   = false
@export var max_level            : int    = 1
@export var required_player_level: int    = 1
@export var unlock_condition     : String = "level"   # "level", "quest", "item"
@export var base_stamina_cost     : float         = 0.0
@export var base_damage_multiplier: float         = 1.0
@export var prerequisite_skills   : Array[String] = []
