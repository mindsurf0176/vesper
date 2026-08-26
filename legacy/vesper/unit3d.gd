extends Node3D
## HD-2D 유닛. 캐릭터 스프라이트가 있으면 AnimatedSprite3D(walk/idle), 없으면 QuadMesh 플레이스홀더.

var main
var team := 0
var utype := 0
var uname := ""
var col := Color.WHITE
var max_hp := 10.0
var hp := 10.0
var dmg := 1.0
var atk_range := 1.0     # meters
var atk_interval := 1.0
var move_speed := 1.0     # m/s
var heal := 0.0
var imprint: Dictionary = {}
var orb_skills: Dictionary = {}
var visual: Dictionary = {}
var radius := 0.45
var dead := false
var ashen := false
var manual_simulation := false

var dir := 1
var atk_timer := 0.0
var hitflash := 0.0
var vh := 1.6
var moving := false
var use_sprite := false
var has_attack := false
var atk_anim := 0.0
var hit_anim := 0.0
var in_combat := false
var vis: MeshInstance3D
var mat: StandardMaterial3D
var asp: AnimatedSprite3D
var vnode: Node3D
var hp_back: MeshInstance3D
var hp_fill: MeshInstance3D
var visual_contract_applied := false
var sprite_base_y := 0.0
var base_bright := 1.0
var phase := 0.0
var anim_t := 0.0
var _mtween: Tween = null

const ANIMATION_COMPLETION_GRACE := 0.02

func setup(_main, _team: int, def: Dictionary, tex: Texture2D) -> void:
	main = _main
	team = _team
	utype = def["type"]; uname = def["name"]; col = main.TYPE_COL[def["type"]]
	max_hp = def["hp"]; hp = max_hp; dmg = def["dmg"]
	atk_range = def["range"]; atk_interval = 1.0 / float(def["aspd"]); move_speed = def["move"]
	heal = def.get("heal", 0.0)
	imprint = def.get("imprint", {}).duplicate(true)
	orb_skills = def.get("orb_skills", {}).duplicate(true)
	visual = def.get("visual", {}).duplicate(true)
	dir = 1 if team == main.ALLY else -1
	if def.has("sprite"):
		_setup_sprite(def)
	else:
		_setup_placeholder(def, tex)
	atk_timer = randf_range(0.0, atk_interval * 0.6)  # 스폰 시 발사 위상 분산

func _setup_sprite(def: Dictionary) -> void:
	use_sprite = true
	var folder: String = def["sprite"]
	var ps: float = def.get("sps", 0.0266)
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_anim(frames, "walk", folder, 10.0, true)
	_add_anim(frames, "idle", folder, 4.0, true)
	_add_anim(frames, "attack", folder, 12.0, false)
	_add_anim(frames, "aim", folder, 6.0, true)  # 교전 대기(견착 유지) — 있으면 사거리 내에서 idle 대신 재생
	_add_anim(frames, "hit", folder, 10.0, false)
	_add_anim(frames, "death", folder, 8.0, false)
	has_attack = frames.has_animation("attack")
	asp = AnimatedSprite3D.new()
	asp.sprite_frames = frames
	asp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	if def.get("hdsprite", false):
		# HD 일러 프레임(로토 파이프라인): 부드러운 엣지 유지
		asp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		asp.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	else:
		asp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		asp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	asp.shaded = true
	asp.pixel_size = ps
	asp.flip_h = dir < 0
	var fh: float
	var tight: bool = def.get("tightsprite", false)
	if tight:
		# 캐릭터가 프레임을 꽉 채운 타이트 크롭 스프라이트: 실제 텍스처 높이 기준
		var tex_h: float = 150.0
		if frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
			var t0: Texture2D = frames.get_frame_texture("idle", 0)
			if t0 != null:
				tex_h = float(t0.get_height())
		fh = tex_h * ps
		vh = fh
		sprite_base_y = fh * 0.5
		radius = fh * 0.16
		base_bright = 1.25  # 어두운 군장이 HD-2D 조명에 묻히지 않게 살짝 리프트
	else:
		# 기존 PixelLab 표준/여백 스프라이트 동작 보존(관지기 등)
		fh = 92.0 * ps
		vh = fh * 0.7
		sprite_base_y = fh * 0.35
		radius = fh * 0.26
	asp.modulate = Color(base_bright, base_bright, base_bright, 1.0)
	asp.position = Vector3(0, sprite_base_y, 0)
	if frames.has_animation("idle"):
		asp.play("idle")
	var holder := Node3D.new()
	add_child(holder)
	holder.add_child(asp)
	vnode = holder
	phase = randf() * TAU
	_add_blob(fh * (0.4 if tight else 0.5))
	_add_contract_layers(fh, true)

func _add_anim(frames: SpriteFrames, name: String, folder: String, fps: float, loop: bool) -> void:
	var count := 0
	while count < 64 and ResourceLoader.exists("%s/%s_%d.png" % [folder, name, count]):
		count += 1
	if count == 0:
		return
	frames.add_animation(name)
	frames.set_animation_loop(name, loop)
	frames.set_animation_speed(name, fps)
	for i in count:
		frames.add_frame(name, load("%s/%s_%d.png" % [folder, name, i]))

func _setup_placeholder(def: Dictionary, tex: Texture2D) -> void:
	var ps: float = def.get("ps", 0.06)
	var sw: float = tex.get_width() * ps
	var sh: float = tex.get_height() * ps
	vh = sh
	# 전장 비주얼 텍스처 폭은 바뀌어도 전투 간격/충돌 반경은 기존 14px 기준을 유지한다.
	radius = 14.0 * ps * 0.55
	vis = MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(sw, sh)
	vis.mesh = qm
	mat = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.roughness = 1.0
	vis.material_override = mat
	vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vis.position = Vector3(0, sh * 0.5, 0)
	add_child(vis)
	vnode = vis
	_add_blob(sw * 0.95)
	_add_contract_layers(max(sw, sh), false)

func _add_blob(w: float) -> void:
	var blob := MeshInstance3D.new()
	var bq := QuadMesh.new(); bq.size = Vector2(w, w * 0.55)
	blob.mesh = bq
	blob.rotation_degrees = Vector3(-90, 0, 0)
	blob.position = Vector3(0, 0.02, 0.06)
	var bm := StandardMaterial3D.new()
	bm.albedo_texture = main.blob_tex
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0, 0, 0, 0.5)
	blob.material_override = bm
	add_child(blob)

func _contract_color(key: String, fallback: Color) -> Color:
	return visual.get(key, fallback)

func _mat_unshaded(c: Color, additive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.6
	m.albedo_color = c
	return m

func _add_contract_layers(base_size: float, sprite_backed: bool) -> void:
	visual_contract_applied = true
	var primary := _contract_color("primary", col)
	var accent := _contract_color("accent", col.lightened(0.25))
	var shape := str(visual.get("shape", "unit"))
	var h := float(visual.get("height", max(vh, base_size)))
	vh = max(vh, h)
	var badge := MeshInstance3D.new()
	var badge_mesh := SphereMesh.new()
	badge_mesh.radius = 0.055 if sprite_backed else 0.085
	badge_mesh.height = badge_mesh.radius * 2.0
	badge.mesh = badge_mesh
	badge.position = Vector3(-dir * 0.25, vh + 0.12, 0.02)
	badge.material_override = _mat_unshaded(accent, true)
	add_child(badge)
	var weapon_len := float(visual.get("weapon", 0.58))
	var weapon := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(max(0.18, weapon_len), 0.035, 0.035)
	weapon.mesh = wm
	weapon.position = Vector3(dir * (0.20 + weapon_len * 0.20), vh * 0.56, 0.03)
	weapon.material_override = _mat_unshaded(accent.lightened(0.08), true)
	add_child(weapon)
	if ["shield", "ossuary", "tank"].has(shape):
		var shield := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.12, vh * 0.36, 0.04)
		shield.mesh = sm
		shield.position = Vector3(dir * 0.34, vh * 0.50, 0.05)
		shield.material_override = _mat_unshaded(primary.lightened(0.12), false)
		add_child(shield)
	elif ["relic", "relay"].has(shape):
		var halo := MeshInstance3D.new()
		var hm := TorusMesh.new()
		hm.inner_radius = 0.09
		hm.outer_radius = 0.14
		halo.mesh = hm
		halo.position = Vector3(0, vh + 0.03, 0.02)
		halo.material_override = _mat_unshaded(accent, true)
		add_child(halo)
	_add_hp_bar(max(0.58, base_size * 0.45), accent)

func _add_hp_bar(width: float, accent: Color) -> void:
	hp_back = MeshInstance3D.new()
	var back_mesh := QuadMesh.new()
	back_mesh.size = Vector2(width, 0.055)
	hp_back.mesh = back_mesh
	hp_back.position = Vector3(0, vh + 0.28, 0.02)
	hp_back.material_override = _mat_unshaded(Color(0.02, 0.03, 0.035, 0.72), false)
	add_child(hp_back)
	hp_fill = MeshInstance3D.new()
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(width, 0.042)
	hp_fill.mesh = fill_mesh
	hp_fill.position = hp_back.position + Vector3(0, 0.002, 0.01)
	hp_fill.material_override = _mat_unshaded(accent, true)
	add_child(hp_fill)
	_update_hp_bar()

func _update_hp_bar() -> void:
	if hp_fill == null or hp_back == null:
		return
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	hp_back.visible = ratio < 0.999
	hp_fill.visible = hp_back.visible
	hp_fill.scale.x = max(0.01, ratio)
	var q := hp_back.mesh as QuadMesh
	if q != null:
		hp_fill.position.x = -q.size.x * (1.0 - ratio) * 0.5

func top_world() -> Vector3:
	return global_position + Vector3(0, vh + 0.3, 0)

func _set_anim(name: String) -> void:
	if asp != null and asp.animation != name and asp.sprite_frames.has_animation(name):
		asp.play(name)

func set_manual_motion(moving_state: bool, engaged_state: bool) -> void:
	# 코어가 확정한 상태를 다음 물리 프레임까지 보존한다. 위치 차이를
	# 렌더러가 다시 추정하지 않으므로 작은 delta에서도 walk가 끊기지 않는다.
	moving = moving_state
	in_combat = engaged_state

func play_manual_attack() -> void:
	in_combat = true
	atk_anim = 0.55

func play_manual_hit() -> void:
	in_combat = true
	if use_sprite:
		_begin_hit_animation()

func _flash(f: float) -> void:
	if use_sprite:
		var v: float = base_bright + f * 6.0
		asp.modulate = Color(v, v, v, 1.0)
	elif mat != null:
		if f > 0.0:
			mat.emission_enabled = true
			mat.emission = Color(1, 1, 1)
			mat.emission_energy_multiplier = f * 7.0
		else:
			mat.emission_enabled = false

func _animation_duration(name: String) -> float:
	if asp == null or not asp.sprite_frames.has_animation(name):
		return 0.0
	var frame_count := asp.sprite_frames.get_frame_count(name)
	var fps := asp.sprite_frames.get_animation_speed(name)
	if frame_count <= 0 or fps <= 0.0:
		return 0.0
	return float(frame_count) / fps

func _begin_hit_animation() -> void:
	if asp == null or not asp.sprite_frames.has_animation("hit"):
		return
	# 피격은 이미 판정이 끝난 공격 연출을 즉시 취소한다. 공격을 다시 재생하면
	# 실제 판정과 화면이 어긋나므로, hit 완주 뒤 현재 전투 상태로 바로 복귀한다.
	atk_anim = 0.0
	hit_anim = _animation_duration("hit") + ANIMATION_COMPLETION_GRACE
	# 연속 피격도 매번 첫 프레임부터 읽히도록 같은 clip 재생 중이어도 재시작한다.
	asp.stop()
	asp.play("hit")

func _update_sprite_animation(delta: float) -> bool:
	var hit_locked := hit_anim > 0.0
	if hit_locked:
		# hit과 attack 타이머를 동시에 흘리지 않는다. 피격이 공격을 선점·취소한다.
		atk_anim = 0.0
		hit_anim = max(0.0, hit_anim - delta)
		if hit_anim > 0.0:
			_set_anim("hit")
		else:
			_resolve_locomotion_animation()
	elif has_attack and atk_anim > 0.0:
		_set_anim("attack")
		atk_anim = max(0.0, atk_anim - delta)
	else:
		_resolve_locomotion_animation()
	_anim_motion(delta)
	if not manual_simulation:
		moving = false
	return hit_locked

func _resolve_locomotion_animation() -> void:
	if in_combat and asp.sprite_frames.has_animation("aim"):
		_set_anim("aim")
	elif moving:
		_set_anim("walk")
	else:
		_set_anim("idle")

func _physics_process(delta: float) -> void:
	if dead or not main.running:
		return
	var hit_locked := false
	if use_sprite:
		hit_locked = _update_sprite_animation(delta)
	atk_timer = max(0.0, atk_timer - delta)
	if hitflash > 0.0:
		hitflash = max(0.0, hitflash - delta)
		_flash(hitflash)
	_update_hp_bar()
	if manual_simulation:
		return
	# 4프레임 피격 연출 중에는 새 공격·회복·이동을 시작하지 않는다. 쿨다운은
	# 계속 흐르므로 연출이 끝난 다음 프레임부터 현재 상황에 맞게 자연스럽게 복귀한다.
	if hit_locked:
		return

	if utype == main.SUPPORT and heal > 0.0:
		var a = _wounded()
		if a != null:
			if atk_timer <= 0.0:
				var heal_amount: float = heal * _heal_imprint_mult(a)
				a.recv_heal(heal_amount)
				if main.has_method("attack_fx"):
					main.attack_fx(self, a, Color(0.6, 1.0, 0.7), "heal")
				main.float_world("+%d" % int(heal_amount), a.top_world(), Color(0.6, 1.0, 0.7))
				atk_timer = _next_attack_delay()
		else:
			_advance(delta)
		return

	var t = _acquire()
	in_combat = t != null
	if t == null:
		_advance(delta)
	elif t is String:
		if atk_timer <= 0.0:
			main.damage_core(team, dmg * _damage_imprint_mult(null))
			var cx: float = main.ENEMY_X if team == main.ALLY else main.ALLY_X
			main.spark(Vector3(cx, 1.0, 0), col)
			if main.has_method("attack_fx_to_pos"):
				main.attack_fx_to_pos(self, Vector3(cx, 1.0, 0), col, "core")
			atk_timer = _next_attack_delay()
			atk_anim = 0.55
			_recoil()
	else:
		if atk_timer <= 0.0:
			var m: float = main.type_mult(utype, t.utype) * _damage_imprint_mult(t)
			t.take_damage(dmg * m, m)
			if main.has_method("attack_fx"):
				main.attack_fx(self, t, col, str(visual.get("shape", "")))
			main.spark(t.global_position + Vector3(0, 0.8, 0), col)
			atk_timer = _next_attack_delay()
			atk_anim = 0.55
			_recoil()

func _acquire():
	var best = null
	var bd := atk_range + 1.0
	for u in main.units:
		if u == self or u.dead or u.team == team:
			continue
		var d: float = abs(u.position.x - position.x)
		if d <= atk_range and d < bd:
			bd = d; best = u
	if best != null:
		return best
	var cx: float = main.ENEMY_X if team == main.ALLY else main.ALLY_X
	if abs(cx - position.x) <= atk_range:
		return "CORE"
	return null

func _advance(delta: float) -> void:
	for u in main.units:
		if u == self or u.dead or u.team != team:
			continue
		var ahead: float = (u.position.x - position.x) * dir
		if ahead > 0.0 and ahead < radius * 2.0 + 0.18 and abs(u.position.z - position.z) < 0.55:
			return
	var nx: float = position.x + dir * move_speed * delta
	nx = clamp(nx, main.ALLY_X + 0.7, main.ENEMY_X - 0.7)
	if abs(nx - position.x) > 0.0001:
		moving = true
	position.x = nx

func _wounded():
	var best = null
	var bd := atk_range + 1.0
	for u in main.units:
		if u == self or u.dead or u.team != team or u.utype == main.SUPPORT:
			continue
		if u.hp >= u.max_hp:
			continue
		var d: float = abs(u.position.x - position.x)
		if d <= atk_range and d < bd:
			bd = d; best = u
	return best

func _imprint_kind() -> String:
	return str(imprint.get("kind", ""))

func _ally_core_ratio() -> float:
	if main == null or main.ally_hp_max <= 0.0:
		return 1.0
	return main.ally_hp / main.ally_hp_max

func _damage_imprint_mult(target) -> float:
	if team != main.ALLY or imprint.is_empty():
		return 1.0
	match _imprint_kind():
		"counter":
			if target != null and target.utype == int(imprint.get("target", -1)):
				return 1.0 + float(imprint.get("bonus", 0.0))
		"low_core_damage":
			if _ally_core_ratio() <= float(imprint.get("threshold", 0.5)):
				return float(imprint.get("mult", 1.0))
		"defender_aura_damage":
			for u in main.units:
				if not u.dead and u.team == main.ALLY and u.utype == main.DEFENDER:
					return float(imprint.get("mult", 1.0))
		"execute":
			if target != null and target.max_hp > 0.0 and target.hp / target.max_hp <= float(imprint.get("threshold", 0.35)):
				return float(imprint.get("mult", 1.0))
	return 1.0

func _heal_imprint_mult(target) -> float:
	if team != main.ALLY or imprint.is_empty():
		return 1.0
	if _imprint_kind() == "low_core_heal" and _ally_core_ratio() <= float(imprint.get("threshold", 0.5)):
		return float(imprint.get("mult", 1.0))
	if _imprint_kind() == "critical_heal" and target.max_hp > 0.0 and target.hp / target.max_hp <= float(imprint.get("threshold", 0.3)):
		return float(imprint.get("mult", 1.0))
	return 1.0

func _next_attack_delay() -> float:
	var delay := atk_interval * randf_range(0.85, 1.2)
	if team == main.ALLY and _imprint_kind() == "low_core_haste" and _ally_core_ratio() <= float(imprint.get("threshold", 0.5)):
		delay *= float(imprint.get("mult", 1.0))
	return delay

func take_damage(d: float, m: float) -> void:
	if dead:
		return
	if team == main.ALLY and _imprint_kind() == "near_core_guard" and position.x <= float(imprint.get("max_x", -3.5)):
		d *= float(imprint.get("mult", 1.0))
	hp -= d
	_update_hp_bar()
	hitflash = 0.22
	if use_sprite and asp != null and asp.sprite_frames.has_animation("hit"):
		_begin_hit_animation()
	_knockback(min(0.34, d * 0.008))
	main.shake(min(0.45, 0.04 + d * 0.009))
	var c := Color(1, 1, 0.5) if m > 1.05 else (Color(0.72, 0.72, 0.72) if m < 0.95 else Color(1, 1, 1))
	main.float_world(str(int(round(d))), top_world(), c)
	if main.has_method("combat_hit_fx"):
		main.combat_hit_fx(self, d, m)
	if hp <= 0.0:
		main.hitstop(0.10)
		main.shake(0.4)
		die()
	elif d >= 22.0:
		main.hitstop(0.05)

func _punch_x(off: float, t1: float, t2: float) -> void:
	if vnode == null:
		return
	if _mtween != null and _mtween.is_valid():
		_mtween.kill()
	_mtween = create_tween()
	_mtween.tween_property(vnode, "position:x", off, t1)
	_mtween.tween_property(vnode, "position:x", 0.0, t2)

func _knockback(amt: float) -> void:
	_punch_x(-dir * amt, 0.05, 0.10)

func _recoil() -> void:
	# 사격/타격 시 시각 노드를 뒤로 살짝 차줌(반동)
	_punch_x(-dir * vh * 0.06, 0.04, 0.12)

func _anim_motion(delta: float) -> void:
	# 승인된 다중 프레임 클립에는 프레임 자체의 동작만 사용한다.
	# 한 장짜리 idle 같은 폴백에만 절제된 절차형 호흡을 더한다.
	if asp == null:
		return
	anim_t += delta
	if asp.sprite_frames.has_animation(asp.animation) and asp.sprite_frames.get_frame_count(asp.animation) > 1:
		asp.position.x = 0.0
		asp.position.y = sprite_base_y
		return
	var bob := 0.0
	var sway := 0.0
	if has_attack and atk_anim > 0.0:
		bob = 0.0
	elif moving:
		bob = absf(sin(anim_t * 9.0 + phase)) * vh * 0.045
		sway = sin(anim_t * 9.0 + phase) * vh * 0.012
	else:
		bob = sin(anim_t * 2.3 + phase) * vh * 0.012
	asp.position.x = sway
	asp.position.y = sprite_base_y + bob

func recv_heal(h: float) -> void:
	if dead:
		return
	hp = min(max_hp, hp + h)
	_update_hp_bar()

func die() -> void:
	if dead:
		return
	dead = true
	if main.has_method("death_fx"):
		main.death_fx(global_position + Vector3(0, vh * 0.55, 0), _contract_color("accent", col))
	main.on_death(self)
	if use_sprite and asp != null and asp.sprite_frames.has_animation("death"):
		# 사망 애니 1회 재생 후 기존 축소·제거 연출로 연결 (없는 유닛은 기존 동작)
		asp.play("death")
		asp.animation_finished.connect(_death_out, CONNECT_ONE_SHOT)
	else:
		_death_out()

func _death_out() -> void:
	var t := create_tween()
	t.tween_property(vnode, "scale", Vector3(0.05, 0.05, 0.05), 0.2)
	t.tween_callback(queue_free)
