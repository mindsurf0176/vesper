class_name BattleActor3D
extends Node3D

## CombatSim snapshot과 event를 표현하는 passive 3D 배우.
## target, damage, cooldown, winner를 계산하지 않는다.

enum State { SPAWN, LOCOMOTION, ATTACK, HIT, DEATH, RETIRED, VICTORY }

const ANIMATION_FPS := {
	"idle": 4.0,
	"walk": 10.0,
	"aim": 6.0,
	"attack": 12.0,
	"hit": 10.0,
	"death": 8.0,
}
const LOOPED := {"idle": true, "walk": true, "aim": true}
const COMPLETION_GRACE := 0.02
const MOVE_DEADZONE := 0.018
const MOVE_HOLD := 0.10
const WALK_CYCLE_WORLD_DISTANCE := 0.72
const DEATH_FADE := 0.20
const DEATH_FALLBACK := 0.45
const DEATH_HARD_LIMIT := 2.0

var uid := -1
var def_id := ""
var team := 0
var star := 1
var role := 0
var element := 0
var retiring := false
var playback_speed := 1.0
var _walk_phase := 0.0
var target_position := Vector3.ZERO
var visual_height := 1.6

var _sprite: AnimatedSprite3D
var _visual_root: Node3D
var _hp_back: MeshInstance3D
var _hp_fill: MeshInstance3D
var _shield_fill: MeshInstance3D
var _state := State.SPAWN
var _action_lock := ""
var _action_left := 0.0
var _engaged := false
var _moving_hold := 0.0
var _base_brightness := 1.14
var _hit_flash := 0.0
var _base_scale := 1.0
var _opacity := 1.0
var _death_left := 0.0
var _death_total := 0.0
var _death_elapsed := 0.0
var _retire_ready := false
var _color_tween: Tween
var _motion_tween: Tween


func setup(state: Dictionary, world_position: Vector3) -> void:
	uid = int(state["uid"])
	def_id = String(state["def_id"])
	team = int(state["team"])
	star = int(state.get("star", 1))
	role = int(state.get("role", 0))
	element = int(UnitDB.get_def(def_id)["element"])
	position = world_position
	target_position = world_position
	_build_visual()
	apply_snapshot(state, world_position, true)
	_state = State.LOCOMOTION
	_resolve_locomotion()


func apply_snapshot(state: Dictionary, world_position: Vector3, snap: bool = false) -> void:
	if retiring:
		return
	target_position = world_position
	_engaged = bool(state.get("engaged", false))
	if snap:
		position = target_position
		_moving_hold = 0.0
	var hp_ratio := clampf(float(state.get("hp", 0.0)) / maxf(float(state.get("max_hp", 1.0)), 1.0), 0.0, 1.0)
	var shield_ratio := clampf(float(state.get("shield", 0.0)) / maxf(float(state.get("max_hp", 1.0)), 1.0), 0.0, 1.0)
	_update_bars(hp_ratio, shield_ratio)


func set_playback_speed(value: float) -> void:
	playback_speed = maxf(value, 0.1)
	if _sprite != null:
		_sprite.speed_scale = playback_speed


func play_deploy() -> void:
	if retiring:
		return
	_state = State.SPAWN
	_visual_root.scale = Vector3(_base_scale * 0.65, _base_scale * 1.2, _base_scale)
	_opacity = 0.0
	_apply_sprite_color()
	_kill_tween(_color_tween)
	_color_tween = create_tween()
	_color_tween.set_speed_scale(playback_speed)
	_color_tween.tween_method(_set_opacity, 0.0, 1.0, 0.24)
	_color_tween.parallel().tween_property(_visual_root, "scale", Vector3.ONE * _base_scale, 0.24)
	_color_tween.tween_callback(_finish_spawn)


func play_attack() -> void:
	if retiring or _state == State.HIT:
		return
	_play_action("attack", State.ATTACK)
	_punch(-0.13 if team == 0 else 0.13)


func play_skill(_ability_name: String = "") -> void:
	if retiring or _state == State.HIT:
		return
	_play_action("attack", State.ATTACK)
	_kill_tween(_color_tween)
	_color_tween = create_tween()
	_color_tween.set_speed_scale(playback_speed)
	_color_tween.tween_method(_set_tint_strength, 1.0, 0.0, 0.22)


func play_hit() -> void:
	if retiring:
		return
	_play_action("hit", State.HIT, true)
	_hit_flash = 0.16
	_punch(0.10 if team == 0 else -0.10)


func play_death() -> void:
	if retiring:
		return
	retiring = true
	_state = State.DEATH
	_action_lock = "death"
	_hit_flash = 0.0
	_engaged = false
	_moving_hold = 0.0
	_hide_bars()
	_kill_tween(_color_tween)
	_kill_tween(_motion_tween)
	var clip_duration := DEATH_FALLBACK
	if _sprite.sprite_frames.has_animation("death"):
		_sprite.stop()
		_sprite.play("death")
		clip_duration = _animation_duration("death") + COMPLETION_GRACE
	else:
		_sprite.stop()
	_death_total = minf(clip_duration + DEATH_FADE, DEATH_HARD_LIMIT)
	_death_left = _death_total
	_death_elapsed = 0.0
	_action_left = clip_duration


func play_victory() -> void:
	if retiring:
		return
	_state = State.VICTORY
	_action_lock = "victory"
	_action_left = 0.75
	_play_loop("idle")
	_kill_tween(_motion_tween)
	_motion_tween = create_tween()
	_motion_tween.set_speed_scale(playback_speed)
	_motion_tween.tween_property(_visual_root, "position:y", 0.13, 0.20)
	_motion_tween.tween_property(_visual_root, "position:y", 0.0, 0.20)
	_motion_tween.tween_property(_visual_root, "position:y", 0.09, 0.16)
	_motion_tween.tween_property(_visual_root, "position:y", 0.0, 0.16)


func can_remove() -> bool:
	return retiring and _retire_ready


func state_name_for_test() -> String:
	return State.keys()[_state].to_lower()


func opacity_for_test() -> float:
	return _opacity


func attack_socket_global() -> Vector3:
	return global_position + Vector3(0.34 if team == 0 else -0.34, visual_height * 0.60, 0.02)


func hit_socket_global() -> Vector3:
	return global_position + Vector3(0, visual_height * 0.56, 0.02)


func top_world() -> Vector3:
	return global_position + Vector3(0, visual_height + 0.24, 0)


func _process(delta: float) -> void:
	if _state == State.RETIRED:
		return
	var scaled_delta := delta * playback_speed
	if retiring:
		_process_death(scaled_delta)
		return

	var previous_position := position
	var distance := position.distance_to(target_position)
	position = position.lerp(target_position, clampf(delta * 12.0 * minf(playback_speed, 2.0), 0.0, 1.0))
	var moved_distance := position.distance_to(previous_position)
	if distance > MOVE_DEADZONE:
		_moving_hold = MOVE_HOLD
	else:
		_moving_hold = maxf(0.0, _moving_hold - scaled_delta)

	if _action_left > 0.0:
		_action_left = maxf(0.0, _action_left - scaled_delta)
		if _action_left <= 0.0 and _state != State.SPAWN:
			_action_lock = ""
			_state = State.LOCOMOTION
	if _action_lock.is_empty() and _state == State.LOCOMOTION:
		_resolve_locomotion()
	_sync_walk_to_motion(moved_distance)
	_process_hit_flash(scaled_delta)


func _process_death(delta: float) -> void:
	_death_elapsed += delta
	_death_left = maxf(0.0, _death_left - delta)
	_action_left = maxf(0.0, _action_left - delta)
	if _death_left <= DEATH_FADE:
		_opacity = clampf(_death_left / DEATH_FADE, 0.0, 1.0)
		var squash := lerpf(0.62, 1.0, _opacity)
		_visual_root.scale = Vector3(_base_scale * lerpf(0.74, 1.0, _opacity), _base_scale * squash, _base_scale)
	_apply_sprite_color()
	if _death_left <= 0.0 or _death_elapsed >= DEATH_HARD_LIMIT:
		_opacity = 0.0
		_apply_sprite_color()
		_retire_ready = true
		_state = State.RETIRED
		_action_lock = ""


func _process_hit_flash(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
	_apply_sprite_color()


func _resolve_locomotion() -> void:
	if retiring or not _action_lock.is_empty():
		return
	_state = State.LOCOMOTION
	if _moving_hold > 0.0:
		_play_loop("walk")
	elif _engaged and _sprite.sprite_frames.has_animation("aim"):
		_play_loop("aim")
	else:
		_play_loop("idle")


func _finish_spawn() -> void:
	if retiring:
		return
	_state = State.LOCOMOTION
	_action_lock = ""
	_resolve_locomotion()


func _build_visual() -> void:
	var spec := CharacterVisuals.spec(def_id)
	var folder := String(spec.get("sprite", ""))
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for animation in CharacterVisuals.REQUIRED_BATTLE_ANIMATIONS:
		_add_animation(frames, animation, folder)
	if not frames.has_animation("idle"):
		_build_debug_frame(frames)

	_sprite = AnimatedSprite3D.new()
	_sprite.sprite_frames = frames
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = _texture_filter_for_spec(spec)
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_sprite.shaded = false
	_sprite.flip_h = team == 1
	_sprite.speed_scale = playback_speed

	var bounds := spec.get("visible_bounds", Rect2i(0, 0, 64, 96)) as Rect2i
	var visible_height := maxf(float(bounds.size.y), 1.0)
	var target_height := float(spec.get("target_height", 2.28))
	_sprite.pixel_size = target_height / visible_height
	visual_height = target_height
	var canvas_height := visible_height
	if frames.get_frame_count("idle") > 0:
		var first := frames.get_frame_texture("idle", 0)
		if first != null:
			canvas_height = float(first.get_height())
	var visible_bottom_from_center := float(bounds.end.y) - canvas_height * 0.5
	# Sprite3D의 texture Y축은 world Y와 반대이므로, 불투명 하단을 지면까지 올린다.
	_sprite.position.y = visible_bottom_from_center * _sprite.pixel_size \
		+ float(spec.get("ground_offset", 0.0))
	_base_scale = (1.0 + 0.08 * float(star - 1)) * float(spec.get("visual_scale", 1.0))

	_visual_root = Node3D.new()
	_visual_root.name = "Visual"
	_visual_root.scale = Vector3.ONE * _base_scale
	add_child(_visual_root)
	_visual_root.add_child(_sprite)
	_sprite.play("idle")
	_apply_sprite_color()
	_add_blob()
	_add_hp_bars()


func _texture_filter_for_spec(spec: Dictionary) -> BaseMaterial3D.TextureFilter:
	if String(spec.get("filtering", "nearest")) == "linear":
		return BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return BaseMaterial3D.TEXTURE_FILTER_NEAREST


func _add_animation(frames: SpriteFrames, animation: String, folder: String) -> void:
	var count := CharacterVisuals.animation_frame_count(def_id, animation)
	if count <= 0:
		return
	var source_animation := CharacterVisuals.animation_source(def_id, animation)
	frames.add_animation(animation)
	frames.set_animation_loop(animation, bool(LOOPED.get(animation, false)))
	frames.set_animation_speed(animation,
		CharacterVisuals.animation_fps(def_id, animation, float(ANIMATION_FPS[animation])))
	for i in count:
		frames.add_frame(animation, load("%s/%s_%d.png" % [folder, source_animation, i]))


func _build_debug_frame(frames: SpriteFrames) -> void:
	# 미제작 캐릭터는 최종 아트로 오인되지 않는 저채도 관측 홀로그램으로 표시한다.
	var image := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var colors: Array[Color] = [Color("8f5f50"), Color("77735d"), Color("58777a"), Color("536a7a")]
	var color: Color = colors[element]
	var glow := Color(color.r, color.g, color.b, 0.26)
	var body := Color(color.r, color.g, color.b, 0.72)
	image.fill_rect(Rect2i(24, 14, 16, 16), glow)
	image.fill_rect(Rect2i(26, 16, 12, 12), body)
	image.fill_rect(Rect2i(18, 31, 28, 7), glow)
	image.fill_rect(Rect2i(22, 34, 20, 34), body)
	image.fill_rect(Rect2i(15, 38, 7, 32), glow)
	image.fill_rect(Rect2i(42, 38, 7, 32), glow)
	image.fill_rect(Rect2i(22, 68, 8, 25), glow)
	image.fill_rect(Rect2i(34, 68, 8, 25), glow)
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.add_frame("idle", ImageTexture.create_from_image(image))


func _add_blob() -> void:
	var blob := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(maxf(visual_height * 0.46, 0.55), maxf(visual_height * 0.20, 0.24))
	blob.mesh = mesh
	blob.rotation_degrees = Vector3(-90, 0, 0)
	blob.position = Vector3(0, 0.025, 0.05)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0, 0, 0, 0.42)
	blob.material_override = material
	add_child(blob)


func _add_hp_bars() -> void:
	var width := maxf(0.82, visual_height * 0.50)
	_hp_back = _bar(width, 0.105, Color(0.008, 0.014, 0.018, 0.96))
	_hp_back.position = Vector3(0, visual_height + 0.22, 0.02)
	var hp_color := Color("78e2a5") if team == 0 else Color("f07e74")
	_hp_fill = _bar(width - 0.035, 0.072, hp_color)
	_hp_fill.position = _hp_back.position + Vector3(0, 0.002, 0.012)
	_shield_fill = _bar(width - 0.04, 0.046, Color("f5d77b"))
	_shield_fill.position = _hp_back.position + Vector3(0, 0.105, 0.012)


func _bar(width: float, height: float, color: Color) -> MeshInstance3D:
	var bar := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, height)
	bar.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.albedo_color = color
	bar.material_override = material
	add_child(bar)
	return bar


func _update_bars(hp_ratio: float, shield_ratio: float) -> void:
	if _hp_fill == null or retiring:
		return
	_set_bar_ratio(_hp_fill, hp_ratio)
	# 체력이 가득 차도 전투원 상태를 읽을 수 있도록 기본적으로 표시한다.
	_hp_back.visible = true
	_hp_fill.visible = true
	_shield_fill.visible = shield_ratio > 0.001
	_set_bar_ratio(_shield_fill, minf(shield_ratio, 1.0))


func _hide_bars() -> void:
	for bar in [_hp_back, _hp_fill, _shield_fill]:
		if bar != null:
			bar.visible = false


func _set_bar_ratio(bar: MeshInstance3D, ratio: float) -> void:
	bar.scale.x = maxf(ratio, 0.001)
	var mesh := bar.mesh as QuadMesh
	if mesh != null:
		bar.position.x = -mesh.size.x * (1.0 - ratio) * 0.5


func _play_loop(animation: String) -> void:
	if _sprite == null or not _sprite.sprite_frames.has_animation(animation):
		animation = "idle"
	if _sprite.animation != animation:
		_sprite.play(animation)
	if animation == "walk":
		_sprite.pause()
	elif not _sprite.is_playing():
		_sprite.play(animation)


func _sync_walk_to_motion(moved_distance: float) -> void:
	if _sprite == null or _sprite.animation != "walk":
		return
	var frame_count := _sprite.sprite_frames.get_frame_count("walk")
	if frame_count <= 0:
		return
	# Walk phase follows actual world displacement so a slowing actor does not foot-slide.
	if moved_distance > 0.00001:
		_walk_phase = fmod(_walk_phase + moved_distance / WALK_CYCLE_WORLD_DISTANCE, 1.0)
	_sprite.frame = mini(int(floor(_walk_phase * float(frame_count))), frame_count - 1)


func _play_action(animation: String, next_state: State, restart: bool = false) -> void:
	if retiring:
		return
	if not _sprite.sprite_frames.has_animation(animation):
		animation = "attack" if _sprite.sprite_frames.has_animation("attack") else "idle"
	_state = next_state
	_action_lock = animation
	_action_left = _animation_duration(animation) + COMPLETION_GRACE
	if restart:
		_sprite.stop()
	_sprite.play(animation)


func _animation_duration(animation: String) -> float:
	if not _sprite.sprite_frames.has_animation(animation):
		return 0.0
	var count := _sprite.sprite_frames.get_frame_count(animation)
	var fps := _sprite.sprite_frames.get_animation_speed(animation)
	return float(count) / maxf(fps, 1.0)


func _punch(offset: float) -> void:
	_kill_tween(_motion_tween)
	_motion_tween = create_tween()
	_motion_tween.set_speed_scale(playback_speed)
	_motion_tween.tween_property(_visual_root, "position:x", offset, 0.045)
	_motion_tween.tween_property(_visual_root, "position:x", 0.0, 0.13)


func _set_opacity(value: float) -> void:
	_opacity = clampf(value, 0.0, 1.0)
	_apply_sprite_color()


func _set_tint_strength(value: float) -> void:
	if retiring:
		return
	var warm := Color(1.45, 1.18, 0.72)
	var base := Color(_base_brightness, _base_brightness, _base_brightness)
	var rgb := base.lerp(warm, clampf(value, 0.0, 1.0))
	_sprite.modulate = Color(rgb.r, rgb.g, rgb.b, _opacity)


func _apply_sprite_color() -> void:
	if _sprite == null:
		return
	var flash := clampf(_hit_flash / 0.16, 0.0, 1.0)
	var value := _base_brightness + flash * 2.8
	_sprite.modulate = Color(value, value, value, _opacity)


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
