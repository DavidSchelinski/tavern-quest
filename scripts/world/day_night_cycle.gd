@tool
extends Node

# ── Tuning (editable in the Inspector) ────────────────────────────────────────
@export var day_duration_minutes : float = 24.0
@export_range(0.0, 24.0, 0.1) var start_hour : float = 8.0

# ── Internal state ─────────────────────────────────────────────────────────────
var _t            : float = 0.0   # 0–1 fraction of the full day
var _sun          : DirectionalLight3D
var _world_env    : WorldEnvironment
var _sky          : ProceduralSkyMaterial


func _ready() -> void:
	_find_nodes()
	_t = start_hour / 24.0
	_apply(_t)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		# In the editor just preview the start_hour statically.
		_t = start_hour / 24.0
	else:
		_t = fmod(_t + delta / (day_duration_minutes * 60.0), 1.0)
	_apply(_t)


# ── Node discovery ─────────────────────────────────────────────────────────────

func _find_nodes() -> void:
	var root := get_parent()
	if root == null:
		return
	_sun       = root.find_child("Sun",              true, false) as DirectionalLight3D
	_world_env = root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if _world_env:
		var env := _world_env.environment
		if env and env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			_sky = env.sky.sky_material as ProceduralSkyMaterial


# ── Main apply ────────────────────────────────────────────────────────────────

func _apply(t: float) -> void:
	_apply_sun(t)
	_apply_environment(t)


# ── Sun ───────────────────────────────────────────────────────────────────────

func _apply_sun(t: float) -> void:
	if _sun == null:
		_find_nodes()
		return

	# Rotate around X: noon (t=0.5) → pointing straight down, midnight → below horizon.
	_sun.rotation.x = PI * 0.5 - t * TAU

	var energy := _curve([
		[0.00, 0.00],  # midnight
		[0.21, 0.00],  # pre-dawn
		[0.25, 0.30],  # sunrise
		[0.33, 1.80],  # morning
		[0.50, 2.20],  # noon
		[0.67, 1.80],  # afternoon
		[0.75, 0.30],  # sunset
		[0.79, 0.00],  # post-dusk
		[1.00, 0.00],  # midnight
	], t)

	_sun.light_energy = energy
	_sun.visible      = energy > 0.01

	_sun.light_color = _color_curve([
		[0.25, Color(1.00, 0.45, 0.12)],  # sunrise – deep orange
		[0.33, Color(1.00, 0.82, 0.60)],  # morning – warm
		[0.50, Color(1.00, 0.96, 0.84)],  # noon – white-warm
		[0.67, Color(1.00, 0.82, 0.60)],  # afternoon – warm
		[0.75, Color(1.00, 0.38, 0.10)],  # sunset – deep orange-red
	], t)


# ── Environment ───────────────────────────────────────────────────────────────

func _apply_environment(t: float) -> void:
	if _world_env == null:
		_find_nodes()
		return
	var env := _world_env.environment
	if env == null:
		return

	# Ambient energy: very dark at night, bright at noon.
	env.ambient_light_energy = _curve([
		[0.00, 0.03],
		[0.21, 0.03],
		[0.25, 0.18],
		[0.40, 0.45],
		[0.50, 0.55],
		[0.60, 0.45],
		[0.75, 0.18],
		[0.79, 0.03],
		[1.00, 0.03],
	], t)

	env.ambient_light_color = _color_curve([
		[0.00, Color(0.04, 0.04, 0.12)],  # midnight – cold blue
		[0.25, Color(0.50, 0.28, 0.12)],  # dawn – warm orange tint
		[0.40, Color(0.78, 0.84, 1.00)],  # morning – cool sky
		[0.50, Color(1.00, 0.92, 0.80)],  # noon – warm
		[0.60, Color(0.78, 0.84, 1.00)],  # afternoon
		[0.75, Color(0.50, 0.28, 0.12)],  # dusk – warm orange tint
		[1.00, Color(0.04, 0.04, 0.12)],  # midnight
	], t)

	if _sky == null:
		return

	_sky.sky_top_color = _color_curve([
		[0.00, Color(0.00, 0.00, 0.04)],  # midnight
		[0.21, Color(0.01, 0.01, 0.08)],  # pre-dawn
		[0.25, Color(0.08, 0.10, 0.30)],  # dawn
		[0.33, Color(0.16, 0.32, 0.62)],  # morning
		[0.50, Color(0.08, 0.26, 0.68)],  # noon – deep blue
		[0.67, Color(0.16, 0.32, 0.62)],  # afternoon
		[0.75, Color(0.08, 0.10, 0.30)],  # dusk
		[0.79, Color(0.01, 0.01, 0.08)],  # post-dusk
		[1.00, Color(0.00, 0.00, 0.04)],  # midnight
	], t)

	_sky.sky_horizon_color = _color_curve([
		[0.00, Color(0.01, 0.01, 0.06)],  # midnight
		[0.21, Color(0.03, 0.03, 0.10)],  # pre-dawn
		[0.25, Color(0.82, 0.38, 0.10)],  # sunrise – orange horizon
		[0.33, Color(0.88, 0.62, 0.38)],  # early morning
		[0.40, Color(0.62, 0.76, 0.94)],  # morning
		[0.50, Color(0.48, 0.66, 0.90)],  # noon
		[0.60, Color(0.62, 0.76, 0.94)],  # afternoon
		[0.67, Color(0.88, 0.62, 0.38)],  # late afternoon
		[0.75, Color(0.82, 0.32, 0.08)],  # sunset – orange
		[0.79, Color(0.03, 0.03, 0.10)],  # post-dusk
		[1.00, Color(0.01, 0.01, 0.06)],  # midnight
	], t)

	_sky.ground_horizon_color = _color_curve([
		[0.00, Color(0.01, 0.01, 0.04)],
		[0.25, Color(0.22, 0.12, 0.06)],
		[0.50, Color(0.28, 0.22, 0.16)],
		[0.75, Color(0.22, 0.12, 0.06)],
		[1.00, Color(0.01, 0.01, 0.04)],
	], t)

	_sky.ground_bottom_color = _color_curve([
		[0.00, Color(0.00, 0.00, 0.02)],
		[0.50, Color(0.10, 0.08, 0.06)],
		[1.00, Color(0.00, 0.00, 0.02)],
	], t)


# ── Curve helpers ──────────────────────────────────────────────────────────────

# Linear interpolation over an array of [t, float] keyframes.
func _curve(keys: Array, t: float) -> float:
	if t <= keys[0][0]:
		return float(keys[0][1])
	if t >= keys[-1][0]:
		return float(keys[-1][1])
	for i in range(keys.size() - 1):
		if t <= keys[i + 1][0]:
			var f: float = (t - float(keys[i][0])) / (float(keys[i + 1][0]) - float(keys[i][0]))
			return lerpf(float(keys[i][1]), float(keys[i + 1][1]), f)
	return float(keys[-1][1])


# Linear interpolation over an array of [t, Color] keyframes.
func _color_curve(keys: Array, t: float) -> Color:
	if t <= keys[0][0]:
		return keys[0][1] as Color
	if t >= keys[-1][0]:
		return keys[-1][1] as Color
	for i in range(keys.size() - 1):
		if t <= keys[i + 1][0]:
			var f: float = (t - float(keys[i][0])) / (float(keys[i + 1][0]) - float(keys[i][0]))
			return (keys[i][1] as Color).lerp(keys[i + 1][1] as Color, f)
	return keys[-1][1] as Color
