extends Node
class_name CombatHandler

# ── Timing ────────────────────────────────────────────────────────────────────
const HOLD_THRESHOLD := 0.25   # seconds: hold longer = heavy attack
const COMBO_WINDOW   := 0.65   # seconds: time window to chain next hit
const MAX_COMBO      := 3      # maximum hits in one combo

# ── Combo key order (index+1 = net_combat value, 0 = idle) ────────────────────
const COMBO_KEYS : Array[String] = [
	"L","LL","LLL",
	"H","HH","HHH",
	"LH","HL",
	"LLH","LHL","HLL","HHL","HLH","LHH",
]

# ── Per-combo animation parameters ────────────────────────────────────────────
# All combos use Sword_Attack as the base; we vary speed and direction for feel.
#   speed   : AnimationPlayer.speed_scale
#   reverse : play animation backwards for a mirrored swing
#   dmg     : base damage dealt
const ATTACKS : Dictionary = {
	"L":   { "speed": 1.8,  "reverse": false, "dmg": 10.0 },
	"LL":  { "speed": 1.9,  "reverse": true,  "dmg": 12.0 },
	"LLL": { "speed": 2.1,  "reverse": false, "dmg": 14.0 },
	"H":   { "speed": 0.95, "reverse": false, "dmg": 22.0 },
	"HH":  { "speed": 0.90, "reverse": true,  "dmg": 26.0 },
	"HHH": { "speed": 0.80, "reverse": false, "dmg": 32.0 },
	"LH":  { "speed": 1.15, "reverse": true,  "dmg": 18.0 },
	"HL":  { "speed": 1.25, "reverse": false, "dmg": 17.0 },
	"LLH": { "speed": 1.00, "reverse": true,  "dmg": 24.0 },
	"LHL": { "speed": 1.40, "reverse": false, "dmg": 22.0 },
	"HLL": { "speed": 1.50, "reverse": true,  "dmg": 20.0 },
	"HHL": { "speed": 1.15, "reverse": false, "dmg": 28.0 },
	"HLH": { "speed": 1.05, "reverse": true,  "dmg": 27.0 },
	"LHH": { "speed": 1.10, "reverse": false, "dmg": 26.0 },
}

const ANIM_SWORD_ATTACK := "Sword_Attack"
const ANIM_SWORD_IDLE   := "Sword_Idle"

# ── Runtime state ─────────────────────────────────────────────────────────────
var _press_time    : float  = 0.0
var _pressing      : bool   = false
var _combo         : String = ""   # e.g. "LLH"
var _combo_timer   : float  = 0.0
var _pending       : String = ""   # buffered input while an attack is playing
var _hitbox_active : bool   = false
var _hitbox_time   : float  = 0.0
const HITBOX_DURATION := 0.25      # seconds the hitbox stays active
var _hitbox_hit_ids : Array = []   # bodies already hit this swing

# ── External references (injected by player.gd) ───────────────────────────────
var _player  : CharacterBody3D = null
var _anim    : AnimationPlayer = null
var _hitbox  : Area3D          = null


func setup(player: CharacterBody3D, anim_player: AnimationPlayer, hitbox: Area3D) -> void:
	_player = player
	_anim   = anim_player
	_hitbox = hitbox
	if _hitbox:
		_hitbox.body_entered.connect(_on_hitbox_entered)
		_hitbox.area_entered.connect(_on_hitbox_area_entered)
		_hitbox.monitoring = false


# ── Public query ─────────────────────────────────────────────────────────────
## Returns 0..1: how much of the combo window is still remaining.
## 0 = no active window, 1 = just opened.
func get_combo_ratio() -> float:
	if _combo_timer <= 0.0:
		return 0.0
	return _combo_timer / COMBO_WINDOW


# ── Called from player._unhandled_input ───────────────────────────────────────
func handle_input(event: InputEvent) -> void:
	if not _can_attack():
		return
	if event.is_action_pressed("attack"):
		_pressing   = true
		_press_time = 0.0
	elif event.is_action_released("attack") and _pressing:
		_pressing = false
		_register("H" if _press_time >= HOLD_THRESHOLD else "L")


# ── Called from player._physics_process ───────────────────────────────────────
func tick(delta: float) -> void:
	if _pressing:
		_press_time += delta

	# Poll hitbox overlaps every physics frame while active
	if _hitbox_active and _hitbox != null:
		_hitbox_time += delta
		if _hitbox_time >= HITBOX_DURATION:
			_hitbox_active = false
			_hitbox_hit_ids.clear()
			_hitbox.set_deferred("monitoring", false)
		elif _hitbox.monitoring:
			for body in _hitbox.get_overlapping_bodies():
				if body.get_instance_id() not in _hitbox_hit_ids:
					_on_hitbox_entered(body)
			for area in _hitbox.get_overlapping_areas():
				var parent := area.get_parent()
				if parent != null and parent.get_instance_id() not in _hitbox_hit_ids:
					_on_hitbox_area_entered(area)

	if not _player.is_attacking and _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_reset()


# ── Called from player._on_anim_finished ──────────────────────────────────────
func on_anim_finished(anim_name: String) -> void:
	if anim_name != ANIM_SWORD_ATTACK:
		return

	_anim.speed_scale     = 1.0
	_player.is_attacking  = false
	_player.net_combat    = 0
	_player._current_anim = ""   # allow movement animations to resume
	if _hitbox:
		_hitbox.set_deferred("monitoring", false)

	if _pending != "":
		var buf  := _pending
		_pending  = ""
		_combo   += buf
		if _combo.length() > MAX_COMBO:
			_combo = _combo.right(MAX_COMBO)
		_execute()


# ── Internal ──────────────────────────────────────────────────────────────────

func _can_attack() -> bool:
	return _player != null \
		and _player.state == _player.State.NORMAL \
		and _player.is_on_floor()


func _register(hit: String) -> void:
	if _player.is_attacking:
		# Buffer at most one hit, only within the combo window
		if _combo_timer > 0.0 and (_combo.length() + _pending.length()) < MAX_COMBO:
			_pending = hit
		return
	_combo += hit
	if _combo.length() > MAX_COMBO:
		_combo = _combo.right(MAX_COMBO)
	_execute()


func _execute() -> void:
	# Find the longest matching combo suffix in our table
	var found_key := ""
	for l in range(min(_combo.length(), MAX_COMBO), 0, -1):
		var key := _combo.right(l)
		if ATTACKS.has(key):
			found_key = key
			break

	if found_key == "":
		_reset()
		return

	_combo = found_key
	var d : Dictionary = ATTACKS[found_key]
	_player.is_attacking = true
	_player.net_combat   = COMBO_KEYS.find(found_key) + 1
	_combo_timer         = COMBO_WINDOW
	_play(d)


func _play(d: Dictionary) -> void:
	if _anim == null or not _anim.has_animation(ANIM_SWORD_ATTACK):
		push_warning("CombatHandler: '%s' animation not found." % ANIM_SWORD_ATTACK)
		_player.is_attacking = false
		return

	# Keep player._current_anim in sync so _play_anim can resume correctly afterwards
	_player._current_anim = ANIM_SWORD_ATTACK

	# Apply Agility multiplier to animation speed.
	var spd_mult := CharacterStats.get_attack_speed_multiplier()
	_anim.speed_scale = d["speed"] * spd_mult
	if d["reverse"]:
		_anim.play_backwards(ANIM_SWORD_ATTACK, 0.1)
	else:
		_anim.play(ANIM_SWORD_ATTACK, 0.1)

	# Arm hitbox at the contact point.
	# Forward: contact at ~20% of playback  → arm at 0.15
	# Reverse (play_backwards): animation plays from 100%→0%, so the contact
	# (at ~20% of the original animation) is reached at ~80% of playback → arm at 0.65
	var anim_length : float = _anim.get_animation(ANIM_SWORD_ATTACK).length
	var hit_fraction := 0.65 if d["reverse"] else 0.15
	var delay : float = anim_length / (d["speed"] as float * spd_mult) * hit_fraction
	get_tree().create_timer(delay).timeout.connect(func(): _arm_hitbox(d["dmg"]))


func _arm_hitbox(dmg: float) -> void:
	if _hitbox == null or not _player.is_attacking:
		return
	# Apply Strength multiplier to outgoing damage.
	_hitbox.set_meta("dmg", dmg * CharacterStats.get_damage_multiplier())
	_hitbox.monitoring = true
	_hitbox_active = true
	_hitbox_time   = 0.0
	print("[CombatHandler] Hitbox armed — pos: ", _hitbox.global_position, " dmg: ", dmg)
	print("[CombatHandler] Hitbox global_transform: ", _hitbox.global_transform)
	# Check for nearby dummies for debug
	for node in _player.get_tree().get_nodes_in_group("dummy"):
		print("[CombatHandler]   Dummy '", node.name, "' at ", node.global_position,
			" dist=", _hitbox.global_position.distance_to(node.global_position))


func _on_hitbox_area_entered(area: Area3D) -> void:
	var body := area.get_parent()
	if body != null and body.has_method("take_damage"):
		print("[CombatHandler] area_entered -> parent: ", body.name)
		_do_damage(body)


func _on_hitbox_entered(body: Node3D) -> void:
	print("[CombatHandler] body_entered: ", body.name, " groups: ", body.get_groups())
	if body == _player:
		return
	_do_damage(body)


func _do_damage(body: Node3D) -> void:
	if not _player._is_mine():
		return
	if body.get_instance_id() in _hitbox_hit_ids:
		return
	if not body.has_method("take_damage"):
		print("[CombatHandler]   skipped (no take_damage method on ", body.name, ")")
		return
	_hitbox_hit_ids.append(body.get_instance_id())
	var dmg : float = _hitbox.get_meta("dmg", 10.0)
	print("[CombatHandler]   HIT! Dealing ", dmg, " damage to ", body.name)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		body.take_damage.rpc_id(1, dmg)
	else:
		body.take_damage(dmg)


func _reset() -> void:
	_combo               = ""
	_pending             = ""
	_combo_timer         = 0.0
	_hitbox_active       = false
	_hitbox_time         = 0.0
	_hitbox_hit_ids.clear()
	_player.is_attacking = false
	_player.net_combat   = 0
	if _hitbox:
		_hitbox.monitoring = false
