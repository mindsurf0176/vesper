class_name BattleStage3D
extends Node3D

## Vesper의 HD-2D 전장을 Web-safe presentation으로 분리한 stage.
## 전투 수치나 승패를 소유하지 않고 camera, core, VFX만 담당한다.

const ALLY_X := -17.0
const ENEMY_X := 17.0
const CAMERA_TRAVEL := 7.0
const TEAM_COLOR := [Color("f0a85c"), Color("5fd3df")]

var camera: Camera3D
var actors_root: Node3D
var playback_speed := 1.0
var _camera_base := Vector3.ZERO
var _trauma := 0.0
var _core_materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	if camera == null:
		_build_world()


func set_playback_speed(value: float) -> void:
	playback_speed = maxf(value, 0.1)


func set_field_scroll(normalized: float) -> void:
	var center_x := lerpf(-CAMERA_TRAVEL, CAMERA_TRAVEL, clampf(normalized, 0.0, 1.0))
	_camera_base.x = center_x
	if camera != null:
		camera.position.x = center_x
		camera.look_at(Vector3(center_x, 1.15, 0), Vector3.UP)


func core_position(team: int) -> Vector3:
	return Vector3(ALLY_X if team == 0 else ENEMY_X, 1.45, 0.0)


func set_core_state(core_hp: Array, max_hp: float) -> void:
	for team in mini(_core_materials.size(), core_hp.size()):
		var ratio := clampf(float(core_hp[team]) / maxf(max_hp, 1.0), 0.0, 1.0)
		var mat := _core_materials[team]
		mat.emission_energy_multiplier = 1.4 + ratio * 4.6
		mat.albedo_color = TEAM_COLOR[team].darkened(0.45 * (1.0 - ratio))


func deploy_fx(position: Vector3, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.38
	mesh.outer_radius = 0.49
	ring.mesh = mesh
	ring.position = position + Vector3(0, 0.035, 0)
	ring.scale = Vector3(0.25, 0.25, 0.25)
	var material := _fx_material(color, 2.2)
	ring.material_override = material
	add_child(ring)
	var tween := create_tween()
	tween.set_speed_scale(playback_speed)
	tween.tween_property(ring, "scale", Vector3(1.45, 1.45, 1.45), 0.24)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.24)
	tween.tween_callback(ring.queue_free)


func attack_fx(from: Vector3, to: Vector3, color: Color, ranged: bool) -> void:
	if ranged:
		_line_fx(from, to, color, 0.14)
	else:
		_line_fx(to + Vector3(-0.24, 0.24, 0.03), to + Vector3(0.26, -0.10, 0.03), color, 0.11)


func impact_fx(position: Vector3, color: Color, heavy: bool = false) -> void:
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.28 * (1.35 if heavy else 1.0)
	mesh.height = mesh.radius * 2.0
	flash.mesh = mesh
	flash.position = position
	var material := _fx_material(color, 3.2)
	flash.material_override = material
	add_child(flash)
	var tween := create_tween()
	tween.set_speed_scale(playback_speed)
	tween.tween_property(flash, "scale", Vector3(1.8, 1.8, 1.8), 0.15)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)
	shake(0.34 if heavy else 0.16)


func core_impact(team: int) -> void:
	impact_fx(core_position(team), TEAM_COLOR[team], true)
	shake(0.45)


func ability_fx(position: Vector3, color: Color) -> void:
	for i in 3:
		var ring_pos := position + Vector3(0, 0.04 + float(i) * 0.03, 0)
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.32 + float(i) * 0.12
		mesh.outer_radius = mesh.inner_radius + 0.045
		ring.mesh = mesh
		ring.position = ring_pos
		var material := _fx_material(color.lightened(float(i) * 0.08), 2.5)
		ring.material_override = material
		add_child(ring)
		var tween := create_tween()
		tween.set_speed_scale(playback_speed)
		tween.tween_interval(float(i) * 0.05)
		tween.tween_property(ring, "scale", Vector3(1.55, 1.55, 1.55), 0.28)
		tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.28)
		tween.tween_callback(ring.queue_free)


func relic_fx(position: Vector3, color: Color) -> void:
	## 유물 발동은 일반 피격보다 오래 남는 이중 파동으로 읽힌다.
	for i in 2:
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.28 + float(i) * 0.18
		mesh.outer_radius = mesh.inner_radius + 0.065
		ring.mesh = mesh
		ring.position = position + Vector3(0, 0.06 + float(i) * 0.12, 0)
		ring.rotation_degrees.x = 90.0
		var material := _fx_material(color.lightened(0.18), 3.8)
		ring.material_override = material
		add_child(ring)
		var tween := create_tween()
		tween.set_speed_scale(playback_speed)
		tween.tween_interval(float(i) * 0.08)
		tween.tween_property(ring, "scale", Vector3(1.8, 1.8, 1.8), 0.42)
		tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.42)
		tween.tween_callback(ring.queue_free)
	shake(0.12)


func death_fx(position: Vector3, color: Color) -> void:
	for i in 4:
		var offset := Vector3(float(i - 2) * 0.11, 0.12 + float(i % 2) * 0.16, 0.03)
		impact_fx(position + offset, color.darkened(float(i) * 0.06), false)


func shake(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func _process(delta: float) -> void:
	if camera == null:
		return
	_trauma = maxf(0.0, _trauma - delta * 2.8 * minf(playback_speed, 2.0))
	var phase := Time.get_ticks_msec() * 0.031
	var strength := _trauma * _trauma
	camera.position = _camera_base + Vector3(sin(phase) * 0.065, cos(phase * 1.41) * 0.045, 0) * strength


func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071317")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("466e72")
	environment.ambient_light_energy = 0.68
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	camera = Camera3D.new()
	camera.position = Vector3(0, 3.65, 13.2)
	camera.fov = 36.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0, 1.15, 0), Vector3.UP)
	_camera_base = camera.position
	set_field_scroll(0.5)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48, -34, 0)
	key_light.light_color = Color("ffe9cb")
	key_light.light_energy = 0.82
	key_light.shadow_enabled = false
	add_child(key_light)
	for team in 2:
		var light := OmniLight3D.new()
		light.position = core_position(team) + Vector3(0, 0.4, 0.5)
		light.light_color = TEAM_COLOR[team]
		light.light_energy = 3.2
		light.omni_range = 9.0
		light.shadow_enabled = false
		add_child(light)

	_build_diorama()
	_build_cores()
	_build_motes()
	actors_root = Node3D.new()
	actors_root.name = "Actors"
	add_child(actors_root)


func _build_diorama() -> void:
	_plane(Vector2(46, 18), Vector3(0, 0, -1), Color("101f21"))
	_plane(Vector2(46, 4), Vector3(0, 0.02, 0.2), Color("183032"))
	_box(Vector3(46, 10, 0.6), Vector3(0, 5, -4.6), Color("0d1b1d"))
	for x in [-6.0, -2.0, 2.0, 6.0]:
		_box(Vector3(0.7, 5.6, 0.7), Vector3(x, 2.8, -3.0), Color("142729"))
	_box(Vector3(1.5, 9, 1.5), Vector3(-11.5, 4.0, 2.9), Color("071012"))
	_box(Vector3(1.5, 9, 1.5), Vector3(11.5, 4.0, 2.9), Color("071012"))
	_box(Vector3(26, 1.1, 1.2), Vector3(0, 8.2, 2.7), Color("071012"))
	_box(Vector3(0.9, 0.9, 0.9), Vector3(-1.4, 0.45, 1.2), Color("17292b"))
	_box(Vector3(0.7, 0.7, 0.7), Vector3(2.0, 0.35, -0.9), Color("17292b"))


func _build_cores() -> void:
	for team in 2:
		var x := ALLY_X if team == 0 else ENEMY_X
		_box(Vector3(1.15, 1.7, 1.15), Vector3(x, 0.85, 0), Color("171817"))
		var core := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.62 if team == 0 else 0.76
		sphere.height = sphere.radius * 2.0
		core.mesh = sphere
		core.position = core_position(team)
		var material := _material(TEAM_COLOR[team].darkened(0.15), 0.32, TEAM_COLOR[team], 6.0)
		core.material_override = material
		_core_materials.append(material)
		add_child(core)


func _build_motes() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 52
	particles.lifetime = 7.0
	particles.preprocess = 3.5
	particles.position = Vector3(0, 1.7, 0.3)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(16, 2.5, 1.8)
	particles.gravity = Vector3(0, 0.025, 0)
	particles.initial_velocity_min = 0.03
	particles.initial_velocity_max = 0.10
	particles.scale_amount_min = 0.75
	particles.scale_amount_max = 1.35
	particles.color = Color(0.45, 0.86, 0.88, 0.42)
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.material = _fx_material(Color(0.45, 0.86, 0.88, 0.55), 1.2)
	particles.mesh = mesh
	add_child(particles)


func _line_fx(from: Vector3, to: Vector3, color: Color, lifetime: float) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	var line := MeshInstance3D.new()
	line.mesh = mesh
	var material := _fx_material(color, 2.4)
	line.material_override = material
	add_child(line)
	var tween := create_tween()
	tween.set_speed_scale(playback_speed)
	tween.tween_property(material, "albedo_color:a", 0.0, lifetime)
	tween.tween_callback(line.queue_free)


func _material(color: Color, roughness := 0.92, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


func _fx_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.45, color, energy)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return material


func _box(size: Vector3, position: Vector3, color: Color, roughness := 0.9) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material(color, roughness)
	add_child(instance)


func _plane(size: Vector2, position: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material(color, 0.95)
	add_child(instance)
