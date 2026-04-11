extends Resource

class_name SkillData

@export_category("Identität")
@export var id                    : String = ""
@export var display_name         : String = ""
@export var description          : String = ""
@export var icon                 : Texture2D = null

@export_category("Mechanik")
@export var is_passive           : bool   = false
@export var max_level            : int    = 1
@export var required_player_level: int    = 1
@export_enum("level", "quest", "item")
var unlock_condition     : String = "level"

@export_category("Kampf")
@export var base_stamina_cost     : float = 0.0
@export var base_damage_multiplier: float = 1.0
@export var cooldown              : float = 0.0

@export_category("Voraussetzungen")
@export var prerequisite_skills   : Array[String] = []

@export_category("Leveling")
@export var damage_per_level          : float = 0.0
@export var stamina_cost_per_level    : float = 0.0
@export var cooldown_reduction_per_level : float = 0.0
