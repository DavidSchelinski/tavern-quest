extends Node

signal stats_changed
signal stats_initialized

# ── Stat definitions ──────────────────────────────────────────────────────────

const STAT_NAMES : Array[String] = [
	"strength", "agility", "defense", "endurance", "charisma", "stamina"
]

const STAT_LABELS : Dictionary = {
	"strength":  "Stärke",
	"agility":   "Beweglichkeit",
	"defense":   "Verteidigung",
	"endurance": "Ausdauer",
	"charisma":  "Charisma",
	"stamina":   "Stamina",
}

const STAT_DESC : Dictionary = {
	"strength":  "+10% Schaden pro Punkt",
	"agility":   "+5% Tempo & Angriff",
	"defense":   "-5% Eingehender Schaden",
	"endurance": "+20 Max-HP pro Punkt",
	"charisma":  "Quests & Handel",
	"stamina":   "+10 Max-Stamina pro Punkt",
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
	"stamina":   1,
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


## Client sendet diese RPC-Anfrage an den Server (rpc_id(1, ...)).
## allocations: Dictionary { stat_name → anzahl_punkte }
## Der Server validiert, wendet an und sendet sync_stats_data zurück.
@rpc("any_peer", "call_local", "reliable")
func request_spend_points(allocations: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	# Gesamtzahl prüfen
	var total := 0
	for stat: String in allocations:
		if not stats.has(stat):
			push_warning("StatsComponent: Ungültiger Stat '%s'" % stat)
			return
		var amount: int = int(allocations[stat])
		if amount < 0:
			push_warning("StatsComponent: Negativer Betrag für '%s'" % stat)
			return
		total += amount

	if total > stat_points:
		push_warning("StatsComponent: Nicht genug Statpunkte (%d verfügbar, %d angefragt)" % [stat_points, total])
		return

	# Anwenden
	for stat: String in allocations:
		stats[stat] = (stats[stat] as int) + int(allocations[stat])
	stat_points -= total
	stats_changed.emit()

	# Autoritative Daten zurück an den anfragenden Client senden.
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != 0:
		sync_stats_data.rpc_id(sender_id, stat_points, stats.duplicate())


## Server sendet die autoritativen Stat-Daten an einen Client.
@rpc("any_peer", "call_local", "reliable")
func sync_stats_data(points: int, new_stats: Dictionary) -> void:
	stat_points = points
	for key: String in new_stats:
		if stats.has(key):
			stats[key] = int(new_stats[key])
	stats_changed.emit()
	stats_initialized.emit()


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

## Maximum stamina pool (Stamina). 100 base + 10 per point above 1.
func get_max_stamina() -> float:
	return 100.0 + ((stats.get("stamina", 1) as int) - 1) * 10.0
