extends CharacterBody3D

# ── Interaction state ─────────────────────────────────────────────────────────
enum State { NORMAL, BOARD_VIEW, MENU, DIALOG, INVENTORY }

# ── Animation state machine ───────────────────────────────────────────────────
enum AnimState { IDLE, WALK, SPRINT, JUMP, FALL, LAND }

# ── Tuning ────────────────────────────────────────────────────────────────────
const WALK_SPEED        := 4.0
const SPRINT_SPEED      := 9.0
const JUMP_VELOCITY     := 6.0
const GRAVITY           := 20.0
const MOUSE_SENSITIVITY := 0.003
const PITCH_MIN         := -70.0
const PITCH_MAX         := 20.0
const RAY_LENGTH        := 5.0
const ROT_SPEED         := 12.0   # pivot turn speed (rad/s)
const AIR_CONTROL       := 0.2    # fraction of ground speed usable while airborne

# Animation names from UAL1_Standard.glb (library is root "", so no prefix).
const ANIM_IDLE   := "Idle"
const ANIM_WALK   := "Walk"
const ANIM_SPRINT := "Sprint"
const ANIM_JUMP   := "Jump_Start"   # plays while ascending
const ANIM_FALL   := "Jump"         # plays at peak / while descending
const ANIM_LAND   := "Jump_Land"    # plays on touch-down (one-shot)

# ── Sword offset on hand_r bone (tweak in-editor if needed) ──────────────────
const SWORD_POSITION := Vector3(-0.05,  0.1,  0.0)
const SWORD_ROTATION := Vector3(0.0,  0.0,  0.0)   # radians
const SWORD_SCALE    := Vector3(1.0,  1.0,  1.0)

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var pivot      : Node3D      = $Pivot
@onready var camera_yaw : Node3D      = $CameraYaw
@onready var spring_arm : SpringArm3D = $CameraYaw/SpringArm3D
@onready var camera     : Camera3D    = $CameraYaw/SpringArm3D/Camera3D

# ── State ─────────────────────────────────────────────────────────────────────
var state                 : State     = State.NORMAL
var _current_interactable : Node3D    = null
var _game_menu            : CanvasLayer = null
var _dialog_ui            : CanvasLayer = null
var _inventory_ui         : CanvasLayer = null

# ── Pickup focus ──────────────────────────────────────────────────────────────
const PICKUP_RADIUS        : float = 3.0
const FOCUS_SWITCH_DELAY   : float = 0.25   # seconds before focus can switch to a new item
const FOCUS_STICK_BIAS     : float = 0.15   # score advantage needed to steal focus from current
const PICKABLE_CACHE_SECS  : float = 0.4    # how often to refresh the nearby-pickables list
var _focus_cooldown        : float = 0.0
var _pickable_cache_timer  : float = 0.0
var _cached_pickables      : Array[Node3D] = []

# ── Animation ─────────────────────────────────────────────────────────────────
var _anim_player  : AnimationPlayer = null
var _anim_state   : AnimState       = AnimState.IDLE
var _current_anim : String          = ""
var _was_on_floor : bool            = true
var _air_time     : float           = 0.0

# ── Combat ────────────────────────────────────────────────────────────────────
var is_attacking  : bool = false
var _combat       : CombatHandler = null
var _sword_hitbox : Area3D = null

# Synced over the network so remote players show correct animations.
var net_anim   : int = 0
var net_combat : int = 0


func _ready() -> void:
	add_to_group("player")
	if not multiplayer.has_multiplayer_peer():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		camera.current = true
	_setup_animations.call_deferred()
	_setup_multiplayer.call_deferred()
	_setup_game_menu.call_deferred()
	_setup_dialog_ui.call_deferred()
	_setup_inventory_ui.call_deferred()
	_setup_combat.call_deferred()


# ── Multiplayer authority ─────────────────────────────────────────────────────

func _is_mine() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()


func _setup_multiplayer() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if _is_mine():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		camera.current = true
	else:
		camera.current = false


# ── Game menu ─────────────────────────────────────────────────────────────────

func _setup_game_menu() -> void:
	if not _is_mine():
		return
	var menu_script := load("res://scripts/ui/game_menu.gd")
	_game_menu = CanvasLayer.new()
	_game_menu.set_script(menu_script)
	add_child(_game_menu)
	_game_menu.resumed.connect(_on_menu_resumed)


func _open_game_menu() -> void:
	if _game_menu == null:
		return
	state = State.MENU
	velocity.x = 0.0
	velocity.z = 0.0
	_enter_anim_state(AnimState.IDLE)
	_game_menu.open()


func _on_menu_resumed() -> void:
	state = State.NORMAL


# ── Dialog ────────────────────────────────────────────────────────────────────

func _setup_dialog_ui() -> void:
	if not _is_mine():
		return
	var ui_script := load("res://scripts/dialog/dialog_ui.gd")
	_dialog_ui = CanvasLayer.new()
	_dialog_ui.set_script(ui_script)
	add_child(_dialog_ui)


func enter_dialog() -> void:
	state = State.DIALOG
	velocity = Vector3.ZERO
	_enter_anim_state(AnimState.IDLE)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func exit_dialog() -> void:
	state = State.NORMAL
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ── Inventory ─────────────────────────────────────────────────────────────────

func _setup_inventory_ui() -> void:
	if not _is_mine():
		return
	var ui_script := load("res://scripts/ui/inventory_ui.gd")
	_inventory_ui = CanvasLayer.new()
	_inventory_ui.set_script(ui_script)
	add_child(_inventory_ui)
	_inventory_ui.closed.connect(_on_inventory_closed)


func _open_inventory() -> void:
	if _inventory_ui == null:
		return
	state = State.INVENTORY
	velocity.x = 0.0
	velocity.z = 0.0
	_enter_anim_state(AnimState.IDLE)
	_inventory_ui.open(self)


func _on_inventory_closed() -> void:
	state = State.NORMAL
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ── Animation setup ───────────────────────────────────────────────────────────

func _setup_animations() -> void:
	_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player == null:
		push_warning("Player: AnimationPlayer not found in character subtree.")
		return
	_anim_player.animation_finished.connect(_on_anim_finished)
	_play_anim(ANIM_IDLE)


func _play_anim(anim: String, speed_scale: float = 1.0, blend: float = 0.15) -> void:
	if _anim_player == null or anim == "" or _current_anim == anim:
		return
	_current_anim = anim
	_anim_player.speed_scale = speed_scale
	_anim_player.play(anim, blend)


func _on_anim_finished(anim_name: String) -> void:
	# Delegate sword attacks to the combat handler first.
	if _combat != null:
		_combat.on_anim_finished(anim_name)

	# LAND is a one-shot — automatically continue to idle or movement.
	if anim_name == ANIM_LAND:
		var h_speed := Vector2(velocity.x, velocity.z).length()
		if h_speed > 0.5 and state == State.NORMAL:
			_enter_anim_state(AnimState.SPRINT if Input.is_action_pressed("sprint") else AnimState.WALK)
		else:
			_enter_anim_state(AnimState.IDLE)

	# After an attack finishes (no chained combo), resume movement animation.
	# The combat handler already cleared _current_anim and is_attacking.
	if anim_name == "Sword_Attack" and not is_attacking:
		var h_speed := Vector2(velocity.x, velocity.z).length()
		if h_speed > 0.5:
			_enter_anim_state(AnimState.SPRINT if Input.is_action_pressed("sprint") else AnimState.WALK)
		else:
			_enter_anim_state(AnimState.IDLE)


# ── Animation state machine ───────────────────────────────────────────────────

func _update_anim_state(moving: bool, sprinting: bool) -> void:
	if is_attacking:
		return   # never interrupt an attack with a movement animation

	var on_floor := is_on_floor()
	var new_state : AnimState

	if not on_floor and not _was_on_floor:
		new_state = AnimState.JUMP if velocity.y > 0.5 else AnimState.FALL
	elif on_floor and not _was_on_floor:
		var hard_landing := _air_time >= 2.0
		_air_time = 0.0
		if hard_landing:
			new_state = AnimState.LAND
		else:
			new_state = AnimState.SPRINT if (moving and sprinting) \
					else AnimState.WALK  if moving \
					else AnimState.IDLE
	elif on_floor:
		if _anim_state == AnimState.LAND:
			_was_on_floor = on_floor
			return
		new_state = AnimState.SPRINT if (moving and sprinting) \
				else AnimState.WALK  if moving \
				else AnimState.IDLE

	_was_on_floor = on_floor

	if new_state == _anim_state:
		return
	_enter_anim_state(new_state)


func _enter_anim_state(new_state: AnimState) -> void:
	if is_attacking:
		_anim_state = new_state   # remember for when attack finishes
		return
	_anim_state = new_state
	match new_state:
		AnimState.IDLE:   _play_anim(ANIM_IDLE)
		AnimState.WALK:   _play_anim(ANIM_WALK)
		AnimState.SPRINT: _play_anim(ANIM_SPRINT)
		AnimState.JUMP:   _play_anim(ANIM_JUMP, 1.0, 0.1)
		AnimState.FALL:   _play_anim(ANIM_FALL, 1.0, 0.1)
		AnimState.LAND:   _play_anim(ANIM_LAND, 1.0, 0.1)


# ── Combat setup ──────────────────────────────────────────────────────────────

func _setup_combat() -> void:
	_combat = get_node_or_null("CombatHandler") as CombatHandler
	if _combat == null:
		push_warning("Player: CombatHandler node not found.")
		return

	if not _is_mine():
		return   # only local player needs an active combat handler

	# Find AnimationPlayer (may not be ready yet if _setup_animations is still deferred)
	if _anim_player == null:
		_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer

	# Find Skeleton3D by type — its node name varies by GLB import settings
	var sk_nodes   := find_children("*", "Skeleton3D", true, false)
	var skeleton   := sk_nodes[0] as Skeleton3D if not sk_nodes.is_empty() else null

	if skeleton == null:
		push_error("Player: no Skeleton3D found in character subtree.")
	else:
		var bone_idx := skeleton.find_bone("hand_r")
		if bone_idx < 0:
			push_error("Player: bone 'hand_r' not found. Bone count: %d" % skeleton.get_bone_count())
		else:
			# BoneAttachment must be added to the skeleton first,
			# then bone_name is set so the index can resolve correctly.
			var attach := BoneAttachment3D.new()
			attach.name = "SwordAttach"
			skeleton.add_child(attach)
			attach.bone_name = "hand_r"

			# Sword mesh
			var sword_scene : PackedScene = load("res://assets/models/sword_one_handed/sword.fbx")
			if sword_scene:
				var sword := sword_scene.instantiate()
				sword.position = SWORD_POSITION
				sword.rotation = SWORD_ROTATION
				sword.scale    = SWORD_SCALE
				attach.add_child(sword)

			# Hitbox — large capsule to reliably cover the blade arc
			_sword_hitbox = Area3D.new()
			_sword_hitbox.name            = "SwordHitbox"
			_sword_hitbox.collision_layer = 0
			_sword_hitbox.collision_mask  = 7   # layers 1 (world) + 2 (players) + 4 (dummies)
			var col   := CollisionShape3D.new()
			var shape := CapsuleShape3D.new()
			shape.radius = 0.35   # wider → easier to land hits
			shape.height = 1.2
			col.shape    = shape
			col.position = Vector3(0.0, 0.5, 0.0)
			_sword_hitbox.add_child(col)
			attach.add_child(_sword_hitbox)

	_combat.setup(self, _anim_player, _sword_hitbox)

	# Combo window HUD (only for the local player)
	var hud_script := load("res://scripts/ui/combo_hud.gd")
	var hud := CanvasLayer.new()
	hud.set_script(hud_script)
	add_child(hud)
	hud.set_combat_handler(_combat)


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _is_mine():
		return
	if state == State.BOARD_VIEW:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			exit_board_view()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_mine():
		return
	if state != State.NORMAL:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_yaw.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		spring_arm.rotation.x = clamp(
			spring_arm.rotation.x - event.relative.y * MOUSE_SENSITIVITY,
			deg_to_rad(PITCH_MIN),
			deg_to_rad(PITCH_MAX)
		)
	if event.is_action_pressed("ui_cancel"):
		_open_game_menu()
		return
	if event.is_action_pressed("inventory"):
		_open_inventory()
		return
	if event.is_action_pressed("interact") and _current_interactable:
		_current_interactable.interact(self)
		return
	# Forward attack inputs to the combat handler
	if _combat != null and (event.is_action("attack")):
		_combat.handle_input(event)


# ── Physics ───────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not _is_mine():
		# Remote player: apply synced animations.
		_apply_remote_animations()
		return

	if state == State.BOARD_VIEW:
		return

	if state == State.MENU or state == State.DIALOG or state == State.INVENTORY:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Tick combat handler
	if _combat != null:
		_combat.tick(delta)

	var on_floor := is_on_floor()

	if not on_floor:
		_air_time += delta
		velocity.y -= GRAVITY * delta

	if Input.is_action_just_pressed("jump") and on_floor and not is_attacking:
		velocity.y = JUMP_VELOCITY

	var sprinting  : bool    = Input.is_action_pressed("sprint")
	var speed      : float   = (SPRINT_SPEED if sprinting else WALK_SPEED) \
							   * CharacterStats.get_speed_multiplier()
	var input_dir  : Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var direction : Vector3 = Vector3.ZERO
	if input_dir != Vector2.ZERO:
		direction = (camera_yaw.transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var moving : bool = direction != Vector3.ZERO

	_update_anim_state(moving, sprinting)

	if is_attacking:
		# Allow limited movement during attacks for dynamic feel (50% speed)
		var atk_speed := speed * 0.5
		if direction != Vector3.ZERO:
			velocity.x = move_toward(velocity.x, direction.x * atk_speed, 10.0 * delta)
			velocity.z = move_toward(velocity.z, direction.z * atk_speed, 10.0 * delta)
			var target_angle := atan2(-direction.x, -direction.z)
			pivot.rotation.y = rotate_toward(pivot.rotation.y, target_angle, ROT_SPEED * 0.5 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
	elif not on_floor:
		if direction != Vector3.ZERO:
			var air_speed := speed * AIR_CONTROL
			velocity.x = move_toward(velocity.x, direction.x * air_speed, 5.0 * delta)
			velocity.z = move_toward(velocity.z, direction.z * air_speed, 5.0 * delta)
	elif _anim_state == AnimState.WALK or _anim_state == AnimState.SPRINT:
		if direction != Vector3.ZERO:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			var target_angle := atan2(-direction.x, -direction.z)
			pivot.rotation.y = rotate_toward(pivot.rotation.y, target_angle, ROT_SPEED * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	net_anim = int(_anim_state)
	# net_combat is written directly by CombatHandler (_player.net_combat = …)
	move_and_slide()


func _apply_remote_animations() -> void:
	if net_combat > 0:
		# Play the attack animation indicated by the host
		if not is_attacking:
			is_attacking = true
			var key : String = _combat.COMBO_KEYS[net_combat - 1] if _combat != null \
								else ""
			if key != "" and _anim_player != null:
				var d : Dictionary = _combat.ATTACKS[key] if _combat != null else {}
				if not d.is_empty():
					_anim_player.speed_scale = d["speed"]
					if d["reverse"]:
						_anim_player.play_backwards("Sword_Attack", 0.1)
					else:
						_anim_player.play("Sword_Attack", 0.1)
	elif is_attacking:
		is_attacking = false
		if _anim_player:
			_anim_player.speed_scale = 1.0
		_current_anim = ""
	else:
		var synced_state := net_anim as AnimState
		if synced_state != _anim_state:
			_enter_anim_state(synced_state)


# ── Interaction ray ───────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _is_mine() or state != State.NORMAL:
		return
	_focus_cooldown       = maxf(_focus_cooldown - delta, 0.0)
	_pickable_cache_timer = maxf(_pickable_cache_timer - delta, 0.0)
	if _pickable_cache_timer == 0.0:
		_pickable_cache_timer = PICKABLE_CACHE_SECS
		_refresh_pickable_cache()
	_update_interactable_focus()


func _refresh_pickable_cache() -> void:
	_cached_pickables.clear()
	for p : Node in get_tree().get_nodes_in_group("pickable"):
		if p is Node3D:
			_cached_pickables.append(p as Node3D)


func _update_interactable_focus() -> void:
	# 1) Raycast — prioritises non-pickable interactables (NPCs, quest board, etc.)
	var space  : PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin : Vector3 = camera.global_position
	var fwd    : Vector3 = -camera.global_transform.basis.z
	var query  : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + fwd * RAY_LENGTH)
	query.exclude = [get_rid()]
	var result : Dictionary = space.intersect_ray(query)

	var ray_hit : Node3D = null
	if result and result.collider.is_in_group("interactable"):
		var node : Node = result.collider
		while node != null:
			if node.has_method("interact"):
				ray_hit = node as Node3D
				break
			node = node.get_parent()

	# If the raycast found a non-pickable interactable, use it directly.
	if ray_hit != null and not ray_hit.is_in_group("pickable"):
		_set_interactable(ray_hit)
		return

	# 2) Among nearby pickable items, choose the best one (distance + aim).
	# Uses a cached list refreshed every PICKABLE_CACHE_SECS instead of
	# calling get_nodes_in_group every frame.
	var best       : Node3D = null
	var best_score : float  = -INF

	for p : Node3D in _cached_pickables:
		if not is_instance_valid(p):
			continue
		var dist : float = global_position.distance_to(p.global_position)
		if dist > PICKUP_RADIUS:
			continue
		var to_item := (p.global_position - origin).normalized() as Vector3
		var dot : float = fwd.dot(to_item)
		# Only consider items roughly in front of the camera (> ~60 deg cone).
		if dot < 0.3:
			continue
		# Score: higher dot = more centered, closer = better.
		var score : float = dot - dist * 0.15
		if score > best_score:
			best_score = score
			best = p

	# Also accept a raycast-hit pickable that scored well.
	if ray_hit != null and ray_hit.is_in_group("pickable") and best == null:
		best = ray_hit

	# 3) Hysteresis — resist switching if the current target is still valid.
	if best != _current_interactable and _current_interactable != null \
		and is_instance_valid(_current_interactable) \
		and _current_interactable.is_in_group("pickable"):
		var cur_dist := global_position.distance_to(_current_interactable.global_position)
		if cur_dist <= PICKUP_RADIUS:
			var to_cur := (_current_interactable.global_position - origin).normalized()
			var cur_dot := fwd.dot(to_cur)
			# Current target must still be roughly in front of the camera.
			if cur_dot >= 0.25:
				var cur_score := cur_dot - cur_dist * 0.15
				if best != null and best_score - cur_score < FOCUS_STICK_BIAS:
					best = _current_interactable
			# If current target is no longer in front, let it go (no sticking).

	_set_interactable(best)


func _set_interactable(target: Node3D) -> void:
	if target == _current_interactable:
		return
	if _current_interactable and is_instance_valid(_current_interactable) \
		and _current_interactable.has_method("on_look_away"):
		_current_interactable.on_look_away()
	_current_interactable = target
	if _current_interactable and _current_interactable.has_method("on_look_at"):
		_current_interactable.on_look_at()
	_focus_cooldown = FOCUS_SWITCH_DELAY


# ── Board view ────────────────────────────────────────────────────────────────

func enter_board_view(board_camera: Camera3D) -> void:
	state = State.BOARD_VIEW
	board_camera.current = true
	pivot.visible = false
	get_tree().call_group("npc", "hide")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	velocity = Vector3.ZERO
	_enter_anim_state(AnimState.IDLE)


func exit_board_view() -> void:
	state = State.NORMAL
	camera.current  = true
	pivot.visible   = true
	get_tree().call_group("npc", "show")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _current_interactable and _current_interactable.has_method("on_interact_exit"):
		_current_interactable.on_interact_exit()
