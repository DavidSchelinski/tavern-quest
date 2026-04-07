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
	stats[stat] += 1
	stat_points  -= 1
	stats_changed.emit()
	return true


# ── Derived values (used by combat + movement) ────────────────────────────────

## Multiplier on outgoing attack damage (Strength).
func get_damage_multiplier() -> float:
	return 1.0 + (stats["strength"] - 1) * 0.10

## Multiplier on player movement speed (Agility).
func get_speed_multiplier() -> float:
	return 1.0 + (stats["agility"] - 1) * 0.05

## Multiplier on attack animation speed (Agility).
func get_attack_speed_multiplier() -> float:
	return 1.0 + (stats["agility"] - 1) * 0.05

## Maximum HP pool (Endurance).
func get_max_hp() -> int:
	return 100 + (stats["endurance"] - 1) * 20

## Fraction of incoming damage reduced (Defense), capped at 75 %.
func get_damage_reduction() -> float:
	return minf((stats["defense"] - 1) * 0.05, 0.75)
