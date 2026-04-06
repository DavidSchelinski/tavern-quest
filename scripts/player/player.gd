extends CharacterBody3D

# ── Interaction state ─────────────────────────────────────────────────────────
enum State { NORMAL, BOARD_VIEW, MENU, DIALOG }

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

# ── Animation ─────────────────────────────────────────────────────────────────
var _anim_player  : AnimationPlayer = null
var _anim_state   : AnimState       = AnimState.IDLE
var _current_anim : String          = ""
var _was_on_floor : bool            = true
var _air_time     : float           = 0.0

# Synced over the network so remote players show the correct animation.
var net_anim : int = 0


func _ready() -> void:
	add_to_group("player")
	# In multiplayer, mouse capture is deferred to _setup_multiplayer so
	# non-authoritative (remote) instances don't interfere with the local mouse.
	if not multiplayer.has_multiplayer_peer():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		camera.current = true
	_setup_animations.call_deferred()
	_setup_multiplayer.call_deferred()
	_setup_game_menu.call_deferred()
	_setup_dialog_ui.call_deferred()


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


# ── Animation setup ───────────────────────────────────────────────────────────

func _setup_animations() -> void:
	_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player == null:
		push_warning("Player: AnimationPlayer not found in character subtree.")
		return
	# UAL1_Standard.glb already contains all animations in its root library.
	# No extra loading required.
	_anim_player.animation_finished.connect(_on_anim_finished)
	_play_anim(ANIM_IDLE)


func _play_anim(anim: String, speed_scale: float = 1.0, blend: float = 0.15) -> void:
	if _anim_player == null or anim == "" or _current_anim == anim:
		return
	_current_anim = anim
	_anim_player.speed_scale = speed_scale
	_anim_player.play(anim, blend)


func _on_anim_finished(anim_name: String) -> void:
	# LAND is a one-shot — automatically continue to idle or movement.
	if anim_name == ANIM_LAND:
		var h_speed := Vector2(velocity.x, velocity.z).length()
		if h_speed > 0.5 and state == State.NORMAL:
			_enter_anim_state(AnimState.SPRINT if Input.is_action_pressed("sprint") else AnimState.WALK)
		else:
			_enter_anim_state(AnimState.IDLE)


# ── Animation state machine ───────────────────────────────────────────────────

func _update_anim_state(moving: bool, sprinting: bool) -> void:
	var on_floor := is_on_floor()
	var new_state : AnimState

	if not on_floor and not _was_on_floor:
		# Already airborne
		new_state = AnimState.JUMP if velocity.y > 0.5 else AnimState.FALL
	elif on_floor and not _was_on_floor:
		# Just landed — only play the full land animation for falls longer than 2 s.
		var hard_landing := _air_time >= 2.0
		_air_time = 0.0
		if hard_landing:
			new_state = AnimState.LAND
		else:
			# Short fall: blend straight into movement or idle.
			new_state = AnimState.SPRINT if (moving and sprinting) \
					else AnimState.WALK  if moving \
					else AnimState.IDLE
	elif on_floor:
		if _anim_state == AnimState.LAND:
			# Let _on_anim_finished handle the exit
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
	_anim_state = new_state
	match new_state:
		AnimState.IDLE:   _play_anim(ANIM_IDLE)
		AnimState.WALK:   _play_anim(ANIM_WALK)
		AnimState.SPRINT: _play_anim(ANIM_SPRINT)
		AnimState.JUMP:   _play_anim(ANIM_JUMP, 1.0, 0.1)
		AnimState.FALL:   _play_anim(ANIM_FALL, 1.0, 0.1)
		AnimState.LAND:   _play_anim(ANIM_LAND, 1.0, 0.1)


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
	if event.is_action_pressed("interact") and _current_interactable:
		_current_interactable.interact(self)


# ── Physics ───────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not _is_mine():
		# Remote player: apply animation from the synced value.
		var synced_state := net_anim as AnimState
		if synced_state != _anim_state:
			_enter_anim_state(synced_state)
		return

	if state == State.BOARD_VIEW:
		return

	if state == State.MENU or state == State.DIALOG:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var on_floor := is_on_floor()

	if not on_floor:
		_air_time += delta
		velocity.y -= GRAVITY * delta

	if Input.is_action_just_pressed("jump") and on_floor:
		velocity.y = JUMP_VELOCITY

	var sprinting := Input.is_action_pressed("sprint")
	var speed     := SPRINT_SPEED if sprinting else WALK_SPEED
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var direction := Vector3.ZERO
	if input_dir != Vector2.ZERO:
		direction = (camera_yaw.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var moving := direction != Vector3.ZERO

	# Update animation state first — movement constraints depend on it.
	_update_anim_state(moving, sprinting)

	if not on_floor:
		# Weak air control: player can nudge direction but cannot steer freely.
		if direction != Vector3.ZERO:
			var air_speed := speed * AIR_CONTROL
			velocity.x = move_toward(velocity.x, direction.x * air_speed, 5.0 * delta)
			velocity.z = move_toward(velocity.z, direction.z * air_speed, 5.0 * delta)
	elif _anim_state == AnimState.WALK or _anim_state == AnimState.SPRINT:
		# Full ground movement only while walk/sprint animation is active.
		if direction != Vector3.ZERO:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			var target_angle := atan2(-direction.x, -direction.z)
			pivot.rotation.y = rotate_toward(pivot.rotation.y, target_angle, ROT_SPEED * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
	else:
		# On floor but not in a movement animation (idle, land, …): stop immediately.
		velocity.x = 0.0
		velocity.z = 0.0

	net_anim = int(_anim_state)
	move_and_slide()


# ── Interaction ray ───────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _is_mine() and state == State.NORMAL:
		_cast_interaction_ray()


func _cast_interaction_ray() -> void:
	var space  := get_world_3d().direct_space_state
	var origin := camera.global_position
	var fwd    := -camera.global_transform.basis.z
	var query  := PhysicsRayQueryParameters3D.create(origin, origin + fwd * RAY_LENGTH)
	query.exclude = [get_rid()]
	var result := space.intersect_ray(query)

	var found: Node3D = null
	if result and result.collider.is_in_group("interactable"):
		var node: Node = result.collider
		while node != null:
			if node.has_method("interact"):
				found = node as Node3D
				break
			node = node.get_parent()

	if found != _current_interactable:
		if _current_interactable and _current_interactable.has_method("on_look_away"):
			_current_interactable.on_look_away()
		_current_interactable = found
		if _current_interactable and _current_interactable.has_method("on_look_at"):
			_current_interactable.on_look_at()


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
