extends Node3D
## HD-2D 룩 테스트 — 픽셀 스프라이트 빌보드 + 3D 디오라마 회랑.
## 블룸 / 볼류메트릭 안개 / 피사계심도(틸트시프트) / 실시간 그림자 / 청록 포자.
## Forward+ 렌더러에서 실행: godot --rendering-method forward_plus --path . res://hdtest.tscn

const AMBER := Color(1.0, 0.72, 0.34)
const CYAN := Color(0.35, 0.85, 0.92)

func _ready() -> void:
	_environment()
	_camera()
	_lights()
	_diorama()
	_cores()
	_spores()
	# 아군(좌, 호박빛) / 적(우, 청록)
	_soldier(Vector3(-3.6, 0, 0.3), AMBER, false)
	_soldier(Vector3(-2.4, 0, -0.4), Color(0.55, 0.62, 0.92), false)
	_soldier(Vector3(-1.3, 0, 0.6), Color(0.92, 0.47, 0.42), false)
	_soldier(Vector3(1.6, 0, 0.4), CYAN, true)
	_soldier(Vector3(3.0, 0, -0.3), Color(0.6, 0.85, 0.55), true)
	if "--shot" in OS.get_cmdline_user_args():
		_shoot()

# ---------- 환경 ----------
func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.08, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.46, 0.5)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	# 블룸
	env.glow_enabled = true
	env.glow_intensity = 1.15
	env.glow_strength = 1.2
	env.glow_bloom = 0.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.9
	# 깊이 안개 + 볼류메트릭
	env.fog_enabled = true
	env.fog_light_color = Color(0.20, 0.40, 0.43)
	env.fog_density = 0.022
	env.fog_aerial_perspective = 0.5
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.032
	env.volumetric_fog_emission = Color(0.10, 0.30, 0.32)
	env.volumetric_fog_emission_energy = 0.5
	env.volumetric_fog_length = 64.0
	# 접촉 음영
	env.ssao_enabled = true
	env.ssao_radius = 0.7
	env.ssao_intensity = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

# ---------- 카메라(틸트시프트 피사계심도) ----------
func _camera() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.9, 9.2)
	cam.fov = 44.0
	add_child(cam)
	cam.look_at(Vector3(0, 1.1, 0), Vector3.UP)
	var ca := CameraAttributesPractical.new()
	ca.dof_blur_far_enabled = true
	ca.dof_blur_far_distance = 13.0
	ca.dof_blur_far_transition = 3.0
	ca.dof_blur_near_enabled = true
	ca.dof_blur_near_distance = 6.6
	ca.dof_blur_near_transition = 2.0
	ca.dof_blur_amount = 0.12
	cam.attributes = ca
	cam.current = true

# ---------- 조명 ----------
func _lights() -> void:
	var dl := DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-48, -36, 0)
	dl.light_color = Color(1.0, 0.93, 0.82)
	dl.light_energy = 0.7
	dl.shadow_enabled = true
	add_child(dl)
	# 아군 등불 빛(따뜻)
	var ol := OmniLight3D.new()
	ol.position = Vector3(-6.0, 1.7, 0.6)
	ol.light_color = AMBER
	ol.light_energy = 6.0
	ol.omni_range = 11.0
	ol.shadow_enabled = true
	add_child(ol)
	# 적 매듭 빛(차가움)
	var oc := OmniLight3D.new()
	oc.position = Vector3(6.0, 1.7, 0.6)
	oc.light_color = CYAN
	oc.light_energy = 4.2
	oc.omni_range = 10.0
	add_child(oc)

# ---------- 머티리얼/메시 헬퍼 ----------
func _mat(col: Color, rough := 0.92, metal := 0.0, emis := Color(0, 0, 0), ee := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if ee > 0.0:
		m.emission_enabled = true
		m.emission = emis
		m.emission_energy_multiplier = ee
	return m

func _box(size: Vector3, pos: Vector3, col: Color, rough := 0.92, emis := Color(0, 0, 0), ee := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(col, rough, 0.0, emis, ee)
	add_child(mi)
	return mi

func _plane(size: Vector2, pos: Vector3, col: Color, rough := 0.95) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = size
	mi.mesh = pm
	mi.position = pos
	mi.material_override = _mat(col, rough)
	add_child(mi)
	return mi

# ---------- 디오라마(바닥/기둥/벽/전경 프레임/잔해) ----------
func _diorama() -> void:
	_plane(Vector2(50, 18), Vector3(0, 0, -1), Color(0.07, 0.125, 0.13))
	_plane(Vector2(50, 3.6), Vector3(0, 0.02, 0.2), Color(0.10, 0.18, 0.18))  # 회랑 띠
	# 뒤쪽 폐허 벽(안개에 잠김 + 원경 블러)
	_box(Vector3(50, 9, 0.6), Vector3(0, 4.0, -4.2), Color(0.06, 0.11, 0.12))
	# 기둥들 — 라인 위로 긴 그림자
	for x in [-5.0, -1.8, 1.8, 5.0]:
		_box(Vector3(0.7, 5.4, 0.7), Vector3(x, 2.7, -2.8), Color(0.08, 0.13, 0.14), 0.8)
	# 전경 프레임(근경 블러 — 디오라마 미니어처 느낌)
	_box(Vector3(1.4, 8, 1.4), Vector3(-10.6, 3.5, 2.7), Color(0.03, 0.06, 0.07))
	_box(Vector3(1.4, 8, 1.4), Vector3(10.6, 3.5, 2.7), Color(0.03, 0.06, 0.07))
	_box(Vector3(23, 1.0, 1.2), Vector3(0, 7.4, 2.6), Color(0.03, 0.06, 0.07))
	# 잔해 박스(그림자/디테일)
	_box(Vector3(0.8, 0.8, 0.8), Vector3(-1.2, 0.4, 1.1), Color(0.09, 0.14, 0.15), 0.85)
	_box(Vector3(0.6, 0.6, 0.6), Vector3(1.8, 0.3, -0.8), Color(0.09, 0.14, 0.15), 0.85)
	_box(Vector3(1.0, 0.5, 0.7), Vector3(0.4, 0.25, 1.4), Color(0.09, 0.14, 0.15), 0.85)

# ---------- 코어(블룸 발광체) ----------
func _cores() -> void:
	# 아군 등불(관)
	_box(Vector3(1.0, 1.6, 1.0), Vector3(-6.3, 0.8, 0), Color(0.12, 0.10, 0.08))
	var lamp := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.55; sm.height = 1.1
	lamp.mesh = sm; lamp.position = Vector3(-6.3, 1.9, 0)
	lamp.material_override = _mat(AMBER, 0.3, 0.0, AMBER, 8.0)
	add_child(lamp)
	# 적 매듭(면역핵)
	var knot := MeshInstance3D.new()
	var km := SphereMesh.new(); km.radius = 0.7; km.height = 1.4
	knot.mesh = km; knot.position = Vector3(6.3, 1.3, 0)
	knot.material_override = _mat(CYAN.darkened(0.2), 0.4, 0.0, CYAN, 5.5)
	add_child(knot)

# ---------- 픽셀 병사 스프라이트(빌보드, 조명 받음 + 블롭 그림자) ----------
func _soldier(pos: Vector3, body: Color, enemy: bool) -> void:
	var tex := _make_soldier_tex(body, enemy)
	var ps := 0.062
	var sw: float = tex.get_width() * ps
	var sh: float = tex.get_height() * ps
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(sw, sh)
	mi.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST   # 픽셀 크리스프
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y        # 카메라 향함(직립)
	mat.billboard_keep_scale = true
	mat.roughness = 1.0
	mi.material_override = mat                                   # 셰이딩=조명 받음
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, sh * 0.5, 0)
	add_child(mi)
	# 블롭 그림자
	var blob := MeshInstance3D.new()
	var bq := QuadMesh.new(); bq.size = Vector2(1.2, 0.7)
	blob.mesh = bq
	blob.rotation_degrees = Vector3(-90, 0, 0)
	blob.position = pos + Vector3(0, 0.03, 0.05)
	var bm := StandardMaterial3D.new()
	bm.albedo_texture = _make_blob_tex()
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0, 0, 0, 0.55)
	blob.material_override = bm
	add_child(blob)

func _make_soldier_tex(body: Color, enemy: bool) -> ImageTexture:
	var w := 14; var h := 26
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rim := AMBER if not enemy else CYAN
	# 실루엣 채우기
	_fill(img, 5, 2, 8, 6, body.lightened(0.08))     # 머리
	_fill(img, 6, 3, 7, 4, rim)                       # 바이저
	_fill(img, 4, 7, 9, 16, body)                     # 몸통
	_fill(img, 2, 8, 3, 14, body.darkened(0.12))      # 왼팔
	_fill(img, 10, 8, 11, 14, body.darkened(0.12))    # 오른팔
	_fill(img, 4, 17, 6, 25, body.darkened(0.18))     # 왼다리
	_fill(img, 7, 17, 9, 25, body.darkened(0.18))     # 오른다리
	_fill(img, 8, 9, 13, 11, body.darkened(0.25))     # 무기(팔 연장)
	_outline(img, Color(0.04, 0.05, 0.06, 1.0))
	return ImageTexture.create_from_image(img)

func _fill(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, c)

func _outline(img: Image, oc: Color) -> void:
	var w := img.get_width(); var h := img.get_height()
	var src := img.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			var near := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.0:
					near = true; break
			if near:
				img.set_pixel(x, y, oc)

func _make_blob_tex() -> ImageTexture:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - s / 2.0, y - s / 2.0).length() / (s / 2.0)
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * a))
	return ImageTexture.create_from_image(img)

# ---------- 포자 입자(청록 부유물) ----------
func _spores() -> void:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 7.0
	p.preprocess = 4.0
	p.position = Vector3(0, 1.5, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(11, 2.4, 2.5)
	pm.gravity = Vector3(0, 0.05, 0)
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.2
	pm.scale_min = 0.4
	pm.scale_max = 1.1
	pm.color = Color(CYAN.r, CYAN.g, CYAN.b, 0.7)
	p.process_material = pm
	var qm := QuadMesh.new(); qm.size = Vector2(0.06, 0.06)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.albedo_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.8)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.emission_enabled = true
	dm.emission = CYAN
	dm.emission_energy_multiplier = 2.0
	qm.material = dm
	p.draw_pass_1 = qm
	add_child(p)

# ---------- 스크린샷 ----------
func _shoot() -> void:
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/private/tmp/claude-501/-Users-minseo/bcc13760-12c9-44df-a122-9aad86b82c83/scratchpad/vesper_hd2d_fp.png")
	get_tree().quit()
