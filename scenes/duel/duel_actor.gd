extends Node2D

## 1대1 격투 캐릭터. 입력/판정은 duel.gd가 소유하고 이 노드는
## 픽셀 스프라이트의 상태와 타격 반응만 표현한다.

var definition: Dictionary = {}
var fighter_name := ""
var side := 0
var facing := 1
var action := "idle"
var action_timer := 0.0
var hit_timer := 0.0
var flash_timer := 0.0
var sprite: AnimatedSprite2D
var sprite_scale := 0.72
var visual_height := 170.0
var has_sprite := false

func setup(def: Dictionary, fighter_side: int) -> void:
	definition = def.duplicate(true)
	fighter_name = str(def.get("name", "전사"))
	side = fighter_side
	facing = 1 if side == 0 else -1
	if str(def.get("sprite", "")) != "":
		_build_sprite(str(def["sprite"]))
	queue_redraw()

func _build_sprite(folder: String) -> void:
	var frames := SpriteFrames.new()
	for spec in [["idle", 5.0, true], ["walk", 10.0, true], ["attack", 14.0, false], ["hit", 12.0, false], ["death", 8.0, false]]:
		_add_animation(frames, str(spec[0]), folder, float(spec[1]), bool(spec[2]))
	if not frames.has_animation("idle"):
		return
	has_sprite = true
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.flip_h = side == 1
	var first := frames.get_frame_texture("idle", 0)
	if first != null:
		sprite_scale = minf(0.82, visual_height / maxf(float(first.get_height()), 1.0))
	visual_height = float(first.get_height()) * sprite_scale
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	sprite.position = Vector2(0, -visual_height * 0.52)
	sprite.play("idle")
	add_child(sprite)

func _add_animation(frames: SpriteFrames, animation_name: String, folder: String, fps: float, loop: bool) -> void:
	var count := 0
	while count < 64 and ResourceLoader.exists("%s/%s_%d.png" % [folder, animation_name, count]):
		count += 1
	if count == 0:
		return
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop)
	for i in count:
		frames.add_frame(animation_name, load("%s/%s_%d.png" % [folder, animation_name, i]))

func set_action(next_action: String, duration := 0.0) -> void:
	action = next_action
	action_timer = duration
	if sprite != null:
		var clip := "idle" if next_action == "idle" else next_action
		if sprite.sprite_frames.has_animation(clip):
			sprite.play(clip)
	queue_redraw()

func receive_hit() -> void:
	hit_timer = 0.18
	flash_timer = 0.14
	set_action("hit", 0.24)
	queue_redraw()

func _process(delta: float) -> void:
	action_timer = maxf(0.0, action_timer - delta)
	hit_timer = maxf(0.0, hit_timer - delta)
	flash_timer = maxf(0.0, flash_timer - delta)
	if action_timer <= 0.0 and action != "idle" and action != "walk":
		set_action("idle")
	if sprite != null and flash_timer <= 0.0:
		sprite.modulate = Color.WHITE
	elif sprite != null:
		sprite.modulate = Color("fff0b8")
	queue_redraw()

func _draw() -> void:
	var primary := Color(definition.get("visual", {}).get("primary", Color("6e8294")))
	var accent := Color(definition.get("visual", {}).get("accent", Color("e7a653")))
	# 바닥 그림자는 모든 캐릭터가 공유해 스프라이트의 발 위치를 고정한다.
	var shadow := PackedVector2Array()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		shadow.append(Vector2(cos(angle) * 48.0, sin(angle) * 10.0 + 2.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.48))
	if not has_sprite:
		var body := PackedVector2Array([Vector2(-30, -8), Vector2(30, -8), Vector2(24, -126), Vector2(-24, -126)])
		draw_colored_polygon(body, primary)
		draw_polyline(body, accent, 5.0, true)
		draw_rect(Rect2(Vector2(-12, -102), Vector2(24, 10)), accent)
	# 픽셀식 상태 마커와 공격 예고선.
	draw_circle(Vector2(-facing * 42.0, -visual_height - 12.0), 5.0, accent)
	if action == "attack":
		var start := Vector2(facing * 24.0, -92.0)
		var end := Vector2(facing * 94.0, -108.0)
		draw_line(start, end, Color(accent, 0.9), 6.0)
		draw_line(end, end + Vector2(-facing * 16.0, 11.0), Color(accent, 0.55), 3.0)
	if hit_timer > 0.0:
		draw_rect(Rect2(Vector2(-42, -visual_height - 22), Vector2(84, 5)), Color(1.0, 0.86, 0.48, 0.82))
