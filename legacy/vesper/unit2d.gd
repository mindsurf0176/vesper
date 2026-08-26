extends Node2D

## Vesper 전투 전용 2D 픽셀 유닛.
## 위치/판정은 LineBattle이 소유하고, 이 노드는 스프라이트와 상태 연출만 담당한다.

var main
var team := 0
var utype := 0
var uname := ""
var col := Color.WHITE
var max_hp := 10.0
var hp := 10.0
var dmg := 1.0
var atk_range := 1.0
var atk_interval := 1.0
var move_speed := 1.0
var heal := 0.0
var imprint: Dictionary = {}
var orb_skills: Dictionary = {}
var visual: Dictionary = {}
var radius := 0.45
var vh := 1.6
var dead := false
var ashen := false
var manual_simulation := false
var dir := 1
var atk_timer := 0.0
var moving := false
var in_combat := false
var atk_anim := 0.0
var hit_anim := 0.0
var hitflash := 0.0
var anim_t := 0.0
var phase := 0.0
var use_sprite := false
var has_attack := false
var asp: AnimatedSprite2D
var sprite: Sprite2D
var sprite_base_y := 0.0
var sprite_scale := 0.06
var _death_tween: Tween

const ANIMATION_COMPLETION_GRACE := 0.02

func setup(_main, _team: int, def: Dictionary, tex: Texture2D) -> void:
	main = _main
	team = _team
	utype = int(def["type"])
	uname = str(def["name"])
	col = main.TYPE_COL[utype]
	max_hp = float(def["hp"]); hp = max_hp
	dmg = float(def["dmg"])
	atk_range = float(def["range"])
	atk_interval = 1.0 / maxf(float(def["aspd"]), 0.05)
	move_speed = float(def["move"])
	heal = float(def.get("heal", 0.0))
	imprint = def.get("imprint", {}).duplicate(true)
	orb_skills = def.get("orb_skills", {}).duplicate(true)
	visual = def.get("visual", {}).duplicate(true)
	dir = 1 if team == main.ALLY else -1
	if def.has("sprite"):
		_setup_sprite(def)
	else:
		_setup_placeholder(def, tex)
	phase = randf() * TAU
	queue_redraw()

func _setup_sprite(def: Dictionary) -> void:
	use_sprite = true
	sprite_scale = float(def.get("sps", 0.0266))
	var frames := SpriteFrames.new()
	for spec in [["walk", 10.0, true], ["idle", 4.0, true], ["attack", 12.0, false], ["aim", 6.0, true], ["hit", 10.0, false], ["death", 8.0, false]]:
		_add_anim(frames, str(spec[0]), str(def["sprite"]), float(spec[1]), bool(spec[2]))
	has_attack = frames.has_animation("attack")
	asp = AnimatedSprite2D.new()
	asp.sprite_frames = frames
	asp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	asp.scale = Vector2(sprite_scale, sprite_scale)
	asp.flip_h = dir < 0
	var tex_h := 92.0
	if frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
		var first := frames.get_frame_texture("idle", 0)
		if first != null:
			tex_h = float(first.get_height())
	vh = tex_h * sprite_scale * (1.0 if def.get("tightsprite", false) else 0.7)
	sprite_base_y = vh * 0.35
	asp.position.y = -sprite_base_y
	asp.play("idle" if frames.has_animation("idle") else "walk")
	add_child(asp)

func _setup_placeholder(def: Dictionary, tex: Texture2D) -> void:
	sprite_scale = float(def.get("ps", 0.06))
	var sh := float(tex.get_height()) * sprite_scale
	vh = sh
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	sprite.position.y = -sh * 0.5
	sprite.flip_h = dir < 0
	add_child(sprite)

func _add_anim(frames: SpriteFrames, anim_name: String, folder: String, fps: float, loop: bool) -> void:
	var count := 0
	while count < 64 and ResourceLoader.exists("%s/%s_%d.png" % [folder, anim_name, count]):
		count += 1
	if count == 0:
		return
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, loop)
	frames.set_animation_speed(anim_name, fps)
	for i in count:
		frames.add_frame(anim_name, load("%s/%s_%d.png" % [folder, anim_name, i]))

func top_world() -> Vector3:
	return Vector3(position.x, vh - position.y, 0.0)

func set_manual_motion(moving_state: bool, engaged_state: bool) -> void:
	moving = moving_state
	in_combat = engaged_state
	queue_redraw()

func play_manual_attack() -> void:
	in_combat = true
	atk_anim = 0.55
	queue_redraw()

func play_manual_hit() -> void:
	in_combat = true
	if asp != null and asp.sprite_frames.has_animation("hit"):
		hit_anim = _animation_duration("hit") + ANIMATION_COMPLETION_GRACE
		asp.stop(); asp.play("hit")
	queue_redraw()

func _animation_duration(anim_name: String) -> float:
	if asp == null or not asp.sprite_frames.has_animation(anim_name):
		return 0.0
	return float(asp.sprite_frames.get_frame_count(anim_name)) / maxf(asp.sprite_frames.get_animation_speed(anim_name), 0.01)

func _physics_process(delta: float) -> void:
	if dead or main == null or not main.running:
		return
	anim_t += delta
	if hit_anim > 0.0:
		hit_anim = maxf(0.0, hit_anim - delta)
		if asp != null and asp.sprite_frames.has_animation("hit"):
			asp.play("hit")
	elif atk_anim > 0.0:
		atk_anim = maxf(0.0, atk_anim - delta)
		if asp != null and asp.sprite_frames.has_animation("attack"):
			asp.play("attack")
	else:
		var next := "idle"
		if in_combat and asp != null and asp.sprite_frames.has_animation("aim"):
			next = "aim"
		elif moving:
			next = "walk"
		if asp != null and asp.sprite_frames.has_animation(next) and asp.animation != next:
			asp.play(next)
	if not manual_simulation:
		moving = false
	queue_redraw()

func take_damage(amount: float, mult: float) -> void:
	if dead:
		return
	hp = maxf(0.0, hp - amount)
	hitflash = 0.18
	play_manual_hit()
	if main != null:
		main.float_world(str(int(round(amount))), top_world(), Color("fff1a8"))
		main.shake(minf(0.45, 0.04 + amount * 0.009))
	if hp <= 0.0:
		die()

func recv_heal(amount: float) -> void:
	if dead:
		return
	hp = minf(max_hp, hp + amount)
	queue_redraw()

func die() -> void:
	if dead:
		return
	dead = true
	if main != null:
		main.on_death(self)
		main.death_fx(top_world(), Color(visual.get("accent", col)))
	if asp != null and asp.sprite_frames.has_animation("death"):
		asp.play("death")
		await get_tree().create_timer(_animation_duration("death") + 0.04).timeout
	_death_out()

func _death_out() -> void:
	_death_tween = create_tween()
	_death_tween.tween_property(self, "scale", Vector2(0.05, 0.05), 0.18)
	_death_tween.tween_callback(queue_free)

func _draw() -> void:
	var accent: Color = Color(visual.get("accent", col))
	var primary: Color = Color(visual.get("primary", col))
	draw_shadow_ellipse(Vector2(0, 0.03), Vector2(0.48, 0.14), Color(0.0, 0.0, 0.0, 0.42))
	if not use_sprite:
		var body := PackedVector2Array([Vector2(-0.34, -0.20), Vector2(0.34, -0.20), Vector2(0.27, -1.15), Vector2(-0.27, -1.15)])
		draw_colored_polygon(body, primary)
		draw_polyline(body, accent, 0.055, true)
		var eye_x := 0.16 * dir
		draw_rect(Rect2(Vector2(eye_x - 0.06, -0.87), Vector2(0.12, 0.08)), accent)
	var weapon := float(visual.get("weapon", 0.58))
	draw_line(Vector2(dir * 0.18, -0.62), Vector2(dir * (0.18 + weapon), -0.62), accent, 0.07, true)
	if ["shield", "ossuary", "tank"].has(str(visual.get("shape", ""))):
		draw_rect(Rect2(Vector2(dir * 0.30 - 0.06, -0.88), Vector2(0.12, 0.45)), primary.lightened(0.18))
	draw_circle(Vector2(-dir * 0.25, -vh - 0.10), 0.07, accent)
	if hp < max_hp:
		var ratio := clampf(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(Vector2(-0.42, -vh - 0.32), Vector2(0.84, 0.07)), Color(0.02, 0.03, 0.04, 0.86))
		draw_rect(Rect2(Vector2(-0.40, -vh - 0.305), Vector2(0.80 * ratio, 0.04)), Color("80e0c6") if team == main.ALLY else Color("f0787c"))
	if hitflash > 0.0:
		draw_circle(Vector2(0, -vh * 0.55), 0.52, Color(1.0, 0.9, 0.55, 0.16))

func draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)
