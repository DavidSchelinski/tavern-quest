extends Camera3D

var _intensity : float = 0.0
var _decay     : float = 15.0 # Erhöht, da LERP höhere Werte für den Abbau benötigt


func apply_shake(intensity: float, decay_rate: float = 15.0) -> void:
	print("Shake ausgelöst mit Intensität: ", intensity)
	_intensity = intensity
	_decay     = decay_rate


func _process(delta: float) -> void:
	if _intensity == 0.0:
		return
		
	h_offset = randf_range(-_intensity, _intensity)
	v_offset = randf_range(-_intensity, _intensity)
	
	_intensity = lerpf(_intensity, 0.0, _decay * delta)
	
	if _intensity < 0.001:
		_intensity = 0.0
		h_offset = 0.0
		v_offset = 0.0
