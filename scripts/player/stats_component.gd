extends Node

signal stats_changed

# ── Stat definitions ──────────────────────────────────────────────────────────

const STAT_NAMES : Array[String] = [
	"strength", "agility", "defense", "endurance", "charisma"
]

const STAT_LABELS : Dictionary = {
	"strength":  "Stärke",
	"agility":   "Beweglichkeit",
	"defense":   "Verteidigung",
	"endurance": "Ausdauer",
	"charisma":  "Charisma",
}

const STAT_DESC : Dictionary = {
	"strength":  "+10% Schaden pro Punkt",
	"agility":   "+5% Tempo & Angriff",
	"defense":   "-5% Eingehender Schaden",
	"endurance": "+20 Max-HP pro Punkt",
	"charisma":  "Quests & Handel",
}

# ── Runtime state ─────────────────────────────────────────────────────────────
# NOTE: Each player instance owns its own Stats node — correct per-player model
# for a listen-server architecture where each peer runs their own instance.

var stats : Dictionary = {
	"strength":  1,
	"agility":   1,
	"defense":   1,
	"endurance": 1,
	"charisma":  1,
}

var stat_points : int = 5


# ── Spend a point ─────────────────────────────────────────────────────────────

func spend_point(stat: String) -> bool:
	if stat_points <= 0 or not stats.has(stat):
		return false
	stats[stat] = (stats[stat] as int) + 1
	stat_points -= 1
	stats_changed.emit()
	return true


# ── Save / Load ───────────────────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	return {
		"stats":      stats.duplicate(),
		"stat_points": stat_points,
	}


func apply_save_data(data: Dictionary) -> void:
	if data.has("stats") and data["stats"] is Dictionary:
		for key: String in (data["stats"] as Dictionary).keys():
			if stats.has(key):
				stats[key] = int((data["stats"] as Dictionary)[key])
	if data.has("stat_points"):
		stat_points = int(data["stat_points"])
	stats_changed.emit()


# ── Derived values (used by combat + movement) ────────────────────────────────

## Multiplier on outgoing attack damage (Strength). +10 % per point above 1.
func get_damage_multiplier() -> float:
	return 1.0 + ((stats["strength"] as int) - 1) * 0.10

## Multiplier on player movement speed (Agility). +5 % per point above 1.
func get_speed_multiplier() -> float:
	return 1.0 + ((stats["agility"] as int) - 1) * 0.05

## Multiplier on attack animation speed (Agility). +5 % per point above 1.
func get_attack_speed_multiplier() -> float:
	return 1.0 + ((stats["agility"] as int) - 1) * 0.05

## Maximum HP pool (Endurance). 100 base + 20 per point above 1.
func get_max_hp() -> int:
	return 100 + ((stats["endurance"] as int) - 1) * 20

## Fraction of incoming damage absorbed (Defense). 5 % per point, capped at 75 %.
func get_damage_reduction() -> float:
	return minf(((stats["defense"] as int) - 1) * 0.05, 0.75)
