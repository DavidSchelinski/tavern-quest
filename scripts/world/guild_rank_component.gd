extends Node

## Tracks the player's guild rank and quest-point progression.
## Board quests award points; enough points unlocks a promotion quest
## from the Guild Leader. Completing it calls promote().

signal rank_changed(new_rank: String)
signal points_changed(points: int, needed: int)

# Rank order: index 0 = lowest
const RANKS : Array[String] = ["F", "E", "D", "C", "B", "A", "S"]

# Quest points required to unlock the promotion quest for each rank.
const POINTS_TO_PROMOTE : Dictionary = {
	"F": 3, "E": 5, "D": 8, "C": 12, "B": 18, "A": 25
}

# Points awarded per completed board quest, based on quest rank.
const QUEST_POINT_VALUE : Dictionary = {
	"F": 1, "E": 2, "D": 3, "C": 5, "B": 8, "A": 13, "S": 21
}

# Promotion quest title_key used for each rank's promotion.
const PROMO_QUEST_KEY : Dictionary = {
	"F": "QUEST_PROMO_F",
	"E": "QUEST_PROMO_E",
	"D": "QUEST_PROMO_D",
	"C": "QUEST_PROMO_C",
	"B": "QUEST_PROMO_B",
	"A": "QUEST_PROMO_A",
}

var _rank_index : int = 0
var _points     : int = 0


func _ready() -> void:
	get_parent().get_node("Quests").quest_completed.connect(_on_quest_completed)


# ── Public API ────────────────────────────────────────────────────────────────

func get_rank() -> String:
	return RANKS[_rank_index]


func get_rank_index() -> int:
	return _rank_index


func get_points() -> int:
	return _points


func get_points_needed() -> int:
	return POINTS_TO_PROMOTE.get(get_rank(), 0) as int


func is_max_rank() -> bool:
	return _rank_index >= RANKS.size() - 1


## True if the player has enough points and has not yet accepted or
## completed the current promotion quest.
func is_promotion_ready() -> bool:
	if is_max_rank():
		return false
	if _points < get_points_needed():
		return false
	var promo_key := get_promo_quest_key()
	var quests    := get_parent().get_node("Quests")
	return not quests.is_quest_active(promo_key) \
		and not quests.is_quest_completed(promo_key)


## True if the player has enough points (promotion quest may already be active).
func has_enough_points() -> bool:
	if is_max_rank():
		return false
	return _points >= get_points_needed()


## Returns true if the given quest rank is ≤ the player's current rank.
func can_accept_quest_rank(quest_rank: String) -> bool:
	var idx : int = RANKS.find(quest_rank)
	if idx < 0:
		return false
	return idx <= _rank_index


func get_promo_quest_key() -> String:
	return PROMO_QUEST_KEY.get(get_rank(), "") as String


func promote() -> void:
	if is_max_rank():
		return
	_rank_index += 1
	_points      = 0
	rank_changed.emit(get_rank())
	points_changed.emit(_points, get_points_needed())


# ── Internal ──────────────────────────────────────────────────────────────────

func _on_quest_completed(quest: Dictionary) -> void:
	var source : String = quest.get("source", "") as String

	if source == "board":
		var pts : int = QUEST_POINT_VALUE.get(quest.get("rank", "F"), 0) as int
		_points += pts
		points_changed.emit(_points, get_points_needed())

	elif source == "promotion":
		var promo_key := get_promo_quest_key()
		if quest.get("title_key", "") == promo_key:
			promote()
