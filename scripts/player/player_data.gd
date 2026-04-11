class_name PlayerData
extends Resource

## Einheitliche Datenstruktur für alle Spielerinformationen.
## Aggregiert Skills, Inventory, Equipment, Stats, Quests, Guild und Vitals.

@export var player_name: String = ""
@export var password_hash: String = ""
@export var verification_code: String = ""

@export var skills: Dictionary = {}
@export var hotbar: Array = ["", "", "", "", "", "", ""]
@export var skill_points: int = 5

@export var last_position: Vector3 = Vector3(0.0, 1.0, 22.0)

@export var inventory: Array = []
@export var equipment: Dictionary = {
	"helm": null, "torso": null, "pants": null,
	"shoes": null, "left_hand": null, "right_hand": null, "neck": null,
}

@export var stats: Dictionary = {
	"strength": 1, "agility": 1, "defense": 1,
	"endurance": 1, "charisma": 1, "stamina": 1,
}
@export var stat_points: int = 5

@export var active_quests: Array = []
@export var completed_quests: Array = []

@export var rank_index: int = 0
@export var guild_points: int = 0

@export var hp: float = -1.0
@export var stamina_value: float = 100.0


func to_dict() -> Dictionary:
	var pos_dict := {"x": last_position.x, "y": last_position.y, "z": last_position.z}
	return {
		"player_name": player_name,
		"password_hash": password_hash,
		"verification_code": verification_code,
		"skills": skills.duplicate(),
		"hotbar": hotbar.duplicate(),
		"points": skill_points,
		"last_position": pos_dict,
		"inventory": inventory.duplicate(true),
		"equipment": equipment.duplicate(true),
		"stats_data": {
			"stats": stats.duplicate(),
			"stat_points": stat_points,
		},
		"quests_data": {
			"active": active_quests.duplicate(true),
			"completed": completed_quests.duplicate(true),
		},
		"guild_data": {
			"rank_index": rank_index,
			"points": guild_points,
		},
		"hp": hp,
		"stamina": stamina_value,
	}


static func from_dict(data: Dictionary) -> PlayerData:
	var pd := PlayerData.new()
	pd.player_name = data.get("player_name", "")
	pd.password_hash = data.get("password_hash", "")
	pd.verification_code = data.get("verification_code", "")

	pd.skills = data.get("skills", {})
	pd.hotbar = data.get("hotbar", ["", "", "", "", "", "", ""])
	pd.skill_points = int(data.get("points", 5))

	var pos = data.get("last_position", {})
	if pos is Dictionary:
		pd.last_position = Vector3(
			float(pos.get("x", 0.0)),
			float(pos.get("y", 1.0)),
			float(pos.get("z", 22.0))
		)

	pd.inventory = data.get("inventory", [])
	pd.equipment = data.get("equipment", {
		"helm": null, "torso": null, "pants": null,
		"shoes": null, "left_hand": null, "right_hand": null, "neck": null,
	})

	var stats_data = data.get("stats_data", {})
	if stats_data is Dictionary:
		pd.stats = (stats_data as Dictionary).get("stats", pd.stats)
		pd.stat_points = int((stats_data as Dictionary).get("stat_points", 5))

	var quests_data = data.get("quests_data", {})
	if quests_data is Dictionary:
		pd.active_quests = (quests_data as Dictionary).get("active", [])
		pd.completed_quests = (quests_data as Dictionary).get("completed", [])

	var guild_data = data.get("guild_data", {})
	if guild_data is Dictionary:
		pd.rank_index = int((guild_data as Dictionary).get("rank_index", 0))
		pd.guild_points = int((guild_data as Dictionary).get("points", 0))

	pd.hp = float(data.get("hp", -1.0))
	pd.stamina_value = float(data.get("stamina", 100.0))
	return pd
