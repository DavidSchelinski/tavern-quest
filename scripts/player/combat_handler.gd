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
	"L":   { "speed": 1.4,  "reverse": false, "dmg": 10.0 },
	"LL":  { "speed": 1.4,  "reverse": true,  "dmg": 12.0 },
	"LLL": { "speed": 1.6,  "reverse": false, "dmg": 14.0 },
	"H":   { "speed": 0.70, "reverse": false, "dmg": 22.0 },
	"HH":  { "speed": 0.65, "reverse": true,  "dmg": 26.0 },
	"HHH": { "speed": 0.55, "reverse": false, "dmg": 32.0 },
	"LH":  { "speed": 0.90, "reverse": true,  "dmg": 18.0 },
	"HL":  { "speed": 1.00, "reverse": false,  "dmg": 17.0 },
	"LLH": { "speed": 0.75, "reverse": true,  "dmg": 24.0 },
	"LHL": { "speed": 1.10, "reverse": false, "dmg": 22.0 },
	"HLL": { "speed": 1.20, "reverse": true,  "dmg": 20.0 },
	"HHL": { "speed": 0.90, "reverse": false, "dmg": 28.0 },
	"HLH": { "speed": 0.80, "reverse": true,  "dmg": 27.0 },
	"LHH": { "speed": 0.85, "reverse": false, "dmg": 26.0 },
}

const ANIM_SWORD_ATTACK := "Sword_Attack"
const ANIM_SWORD_IDLE   := "Sword_Idle"

# ── Runtime state ─────────────────────────────────────────────────────────────
var _press_time  : float  = 0.0
var _pressing    : bool   = false
var _combo       : String = ""   # e.g. "LLH"
var _combo_timer : float  = 0.0
var _pending     : String = ""   # buffered input while an attack is playing

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

	_anim.speed_scale = d["speed"]
	if d["reverse"]:
		_anim.play_backwards(ANIM_SWORD_ATTACK, 0.1)
	else:
		_anim.play(ANIM_SWORD_ATTACK, 0.1)

	# Arm hitbox at ~35% through the swing
	var anim_length : float = _anim.get_animation(ANIM_SWORD_ATTACK).length
	var delay : float = anim_length / (d["speed"] as float) * 0.35
	get_tree().create_timer(delay).timeout.connect(func(): _arm_hitbox(d["dmg"]))


func _arm_hitbox(dmg: float) -> void:
	if _hitbox == null or not _player.is_attacking:
		return
	_hitbox.set_meta("dmg", dmg)
	_hitbox.monitoring = true

	# Godot's body_entered only fires for NEW overlaps. Check bodies that are
	# already inside the area at the moment monitoring is switched on.
	for body in _hitbox.get_overlapping_bodies():
		_on_hitbox_entered(body)

	get_tree().create_timer(0.18).timeout.connect(func():
		if is_instance_valid(_hitbox):
			_hitbox.set_deferred("monitoring", false)
	)


func _on_hitbox_entered(body: Node3D) -> void:
	if not _player._is_mine() or body == _player:
		return
	if not body.has_method("take_damage"):
		return
	var dmg : float = _hitbox.get_meta("dmg", 10.0)
	# Must use set_deferred — can't change monitoring inside a body_entered signal
	_hitbox.set_deferred("monitoring", false)
	# Only non-server peers use rpc_id; server (and SP) calls directly
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		body.take_damage.rpc_id(1, dmg)
	else:
		body.take_damage(dmg)


func _reset() -> void:
	_combo               = ""
	_pending             = ""
	_combo_timer         = 0.0
	_player.is_attacking = false
	_player.net_combat   = 0
	if _hitbox:
		_hitbox.monitoring = false
