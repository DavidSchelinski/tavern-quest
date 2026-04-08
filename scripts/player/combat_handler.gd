extends Node
class_name CombatHandler

# ── Timing ────────────────────────────────────────────────────────────────────
const HOLD_THRESHOLD  : float = 0.25   # seconds: hold longer = heavy attack
const COMBO_WINDOW    : float = 0.65   # seconds: time window to chain next hit
const MAX_COMBO       : int   = 3      # maximum hits in one combo
const HITBOX_DURATION : float = 0.25   # seconds the hitbox stays active

# ── Combo key order (index+1 = net_combat value, 0 = idle) ───────────────────
const COMBO_KEYS : Array[String] = [
	"L","LL","LLL",
	"H","HH","HHH",
	"LH","HL",
	"LLH","LHL","HLL","HHL","HLH","LHH",
]

# ── Per-combo animation parameters ───────────────────────────────────────────
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

const ANIM_SWORD_ATTACK : String = "Sword_Attack"
const ANIM_SWORD_IDLE   : String = "Sword_Idle"

# ── Runtime state ─────────────────────────────────────────────────────────────
var _press_time    : float  = 0.0
var _pressing      : bool   = false
var _combo         : String = ""
var _combo_timer   : float  = 0.0
var _pending       : String = ""
var _hitbox_active : bool   = false
var _hitbox_time   : float  = 0.0
var _hitbox_hit_ids : Array[int] = []

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

	if _hitbox_active and _hitbox != null:
		_hitbox_time += delta
		if _hitbox_time >= HITBOX_DURATION:
			_hitbox_active = false
			_hitbox_hit_ids.clear()
			_hitbox.set_deferred("monitoring", false)
		elif _hitbox.monitoring:
			for body : Node3D in _hitbox.get_overlapping_bodies():
				if body.get_instance_id() not in _hitbox_hit_ids:
					_on_hitbox_entered(body)
			for area : Area3D in _hitbox.get_overlapping_areas():
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
	_player._current_anim = ""
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
		if _combo_timer > 0.0 and (_combo.length() + _pending.length()) < MAX_COMBO:
			_pending = hit
		return
	_combo += hit
	if _combo.length() > MAX_COMBO:
		_combo = _combo.right(MAX_COMBO)
	_execute()


func _execute() -> void:
	var found_key : String = ""
	for l : int in range(mini(_combo.length(), MAX_COMBO), 0, -1):
		var key : String = _combo.right(l)
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

	_player._current_anim = ANIM_SWORD_ATTACK

	# Apply Agility multiplier to animation speed.
	var spd_mult : float = CharacterStats.get_attack_speed_multiplier()
	var actual_speed : float = (d["speed"] as float) * spd_mult
	_anim.speed_scale = actual_speed

	if d["reverse"]:
		_anim.play_backwards(ANIM_SWORD_ATTACK, 0.1)
	else:
		_anim.play(ANIM_SWORD_ATTACK, 0.1)

	# Arm hitbox at the contact point.
	# Forward: contact at ~20% → arm at 0.15
	# Reverse: contact at ~80% of backwards playback → arm at 0.65
	var anim_length  : float = _anim.get_animation(ANIM_SWORD_ATTACK).length
	var hit_fraction : float = 0.65 if d["reverse"] else 0.15
	var delay        : float = anim_length / actual_speed * hit_fraction
	var dmg          : float = d["dmg"]

	# Guard the timer callback: the player might be freed before the timer fires.
	get_tree().create_timer(delay).timeout.connect(
		func() -> void:
			if is_instance_valid(self) and is_instance_valid(_player):
				_arm_hitbox(dmg)
	)


func _arm_hitbox(dmg: float) -> void:
	if _hitbox == null or not _player.is_attacking:
		return
	# Apply Strength multiplier to outgoing damage.
	_hitbox.set_meta("dmg", dmg * CharacterStats.get_damage_multiplier())
	_hitbox.monitoring = true
	_hitbox_active     = true
	_hitbox_time       = 0.0


func _on_hitbox_area_entered(area: Area3D) -> void:
	var body := area.get_parent()
	if body != null and body.has_method("take_damage"):
		_do_damage(body)


func _on_hitbox_entered(body: Node3D) -> void:
	if body == _player:
		return
	_do_damage(body)


func _do_damage(body: Node3D) -> void:
	if not _player._is_mine():
		return
	if body.get_instance_id() in _hitbox_hit_ids:
		return
	if not body.has_method("take_damage"):
		return
	_hitbox_hit_ids.append(body.get_instance_id())
	var dmg : float = _hitbox.get_meta("dmg", 10.0)
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
