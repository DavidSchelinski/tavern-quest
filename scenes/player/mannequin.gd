extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.2

# Zoom-Einstellungen für das Mausrad
const MIN_ZOOM = 1.5
const MAX_ZOOM = 8.0
const ZOOM_SPEED = 0.5

# Wir greifen jetzt direkt auf das Skelett zu, nicht mehr auf einen "Visuals" Ordner
@onready var skeleton = $Skeleton3D
@onready var anim_player = $AnimationPlayer
@onready var spring_arm = $SpringArm3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Maus im Spielfenster fangen
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Sehr wichtig: Verhindert, dass der Kamera-Arm mit dem Spieler selbst kollidiert
	spring_arm.add_excluded_object(self.get_rid())

func _input(event):
	# Spiel abbrechen / Maus freigeben
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# 1. Umsehen (Kamera um den Player rotieren)
		if event is InputEventMouseMotion:
			# X-Achse (Hoch/Runter)
			spring_arm.rotation_degrees.x -= event.relative.y * MOUSE_SENSITIVITY
			spring_arm.rotation_degrees.x = clamp(spring_arm.rotation_degrees.x, -70, 30)
			
			# Y-Achse (Links/Rechts)
			spring_arm.rotation_degrees.y -= event.relative.x * MOUSE_SENSITIVITY
			spring_arm.rotation_degrees.y = wrapf(spring_arm.rotation_degrees.y, 0.0, 360.0)

		# 2. Zoomen (Mausrad)
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				spring_arm.spring_length -= ZOOM_SPEED
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				spring_arm.spring_length += ZOOM_SPEED
			
			# Begrenzung für den Zoom
			spring_arm.spring_length = clamp(spring_arm.spring_length, MIN_ZOOM, MAX_ZOOM)

func _physics_process(delta):
	# Schwerkraft
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Sprung
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Eingabe-Richtung
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Bewegungsrichtung RELATIV ZUR KAMERA berechnen
	var direction = (spring_arm.transform.basis * Vector3(input_dir.x, 0, input_dir.y))
	direction.y = 0
	direction = direction.normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		
		# NUR DAS SKELETT in die Laufrichtung drehen
		var look_angle = atan2(direction.x, direction.z)
		skeleton.rotation.y = lerp_angle(skeleton.rotation.y, look_angle, 10.0 * delta)
		
		# Lauf-Animation
		if anim_player.current_animation != "Walking/mixamo_com":
			anim_player.play("Walking/mixamo_com")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
		# Idle-Animation
		if anim_player.current_animation != "mixamo_com":
			anim_player.play("mixamo_com")

	move_and_slide()
