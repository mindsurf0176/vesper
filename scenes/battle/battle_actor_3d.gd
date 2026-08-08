class_name BattleActor3D
extends Node3D

## CombatSim snapshot과 event를 표현하는 passive 3D 배우.
## target, damage, cooldown, winner를 계산하지 않는다.

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

var uid := -1
var def_id := ""
var team := 0
var star := 1
var role := 0
var element := 0
var retiring := false
var playback_speed := 1.0
var target_position := Vector3.ZERO
var visual_height := 1.6

var _sprite: AnimatedSprite3D
var _visual_root: Node3D
var _hp_back: MeshInstance3D
var _hp_fill: MeshInstance3D
var _shield_fill: MeshInstance3D
var _action_lock := ""
var _action_left := 0.0
var _last_sim_x := 0.0
var _base_brightness := 1.14
var _hit_flash := 0.0
var _base_scale := 1.0


func setup(state: Dictionary, world_position: Vector3) -> void:
	uid = int(state["uid"])
	def_id = String(state["def_id"])
	team = int(state["team"])
	star = int(state.get("star", 1))
	role = int(state.get("role", 0))
	element = int(UnitDB.get_def(def_id)["element"])
	position = world_position
	target_position = world_position
	_last_sim_x = float(state.get("x", 0.0))
	_build_visual()
	apply_snapshot(state, world_position, true)


func apply_snapshot(state: Dictionary, world_position: Vector3, snap: bool = false) -> void:
	target_position = world_position
	if snap:
		position = target_position
	var hp_ratio := clampf(float(state.get("hp", 0.0)) / maxf(float(state.get("max_hp", 1.0)), 1.0), 0.0, 1.0)
	var shield_ratio := clampf(float(state.get("shield", 0.0)) / maxf(float(state.get("max_hp", 1.0)), 1.0), 0.0, 1.0)
	_update_bars(hp_ratio, shield_ratio)
	var sim_x := float(state.get("x", _last_sim_x))
	var moving := absf(sim_x - _last_sim_x) > 0.005
	_last_sim_x = sim_x
	if _action_lock.is_empty() and not retiring:
		_play_loop("walk" if moving else ("aim" if _sprite.sprite_frames.has_animation("aim") else "idle"))
	if not bool(state.get("alive", true)) and not retiring:
		play_death()


func set_playback_speed(value: float) -> void:
	playback_speed = maxf(value, 0.1)
	if _sprite != null:
		_sprite.speed_scale = playback_speed


func play_deploy() -> void:
	if retiring:
		return
	_visual_root.scale = Vector3(_base_scale * 0.65, _base_scale * 1.2, _base_scale)
	_sprite.modulate = Color(1.35, 1.15, 0.9, 0.0)
	var tween := create_tween()
	tween.set_speed_scale(playback_speed)
	tween.tween_property(_sprite, "modulate", Color(_base_brightness, _base_brightness, _base_brightness, 1), 0.24)
	tween.parallel().tween_property(_visual_root, "scale", Vector3.ONE * _base_scale, 0.24)


func play_attack() -> void:
	_play_action("attack")
	_punch(-0.13 if team == 0 else 0.13)


func play_skill(_ability_name: String = "") -> void:
	_play_action("attack")
	var tween := create_tween()
	tween.set_speed_scale(playback_speed)
	tween.tween_property(_sprite, "modulate", Color(1.45, 1.18, 0.72, 1), 0.08)
	tween.tween_property(_sprite, "modulate", Color(_base_brightness, _base_brightness, _base_brightness, 1), 0.22)


func play_hit() -> void:
	if retiring:
		return
	_play_action("hit", true)
	_hit_flash = 0.16
	_punch(0.10 if team == 0 else -0.10)


func play_death() -> void:
	if retiring:
		return
	retiring = true
	if _sprite.sprite_frames.has_animation("death"):
		_play_action("death", true)
	else:
		_action_lock = "death"
		_action_left = 0.45
	var tween := create_tween()
	tween.set_speed_scale(playback_speed)
	tween.tween_interval(maxf(_action_left - 0.18, 0.0))
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.18)
	tween.parallel().tween_property(_visual_root, "scale", Vector3(_base_scale * 0.72, _base_scale * 0.56, _base_scale), 0.18)


func play_victory() -> void:
	if retiring:
		return
	_action_lock = "victory"
	_action_left = 0.75
	_play_loop("idle")
	var tween := create_tween()
	tween.set_speed_scale(playback_speed)
	tween.tween_property(_visual_root, "position:y", 0.13, 0.20)
	tween.tween_property(_visual_root, "position:y", 0.0, 0.20)
	tween.tween_property(_visual_root, "position:y", 0.09, 0.16)
	tween.tween_property(_visual_root, "position:y", 0.0, 0.16)


func can_remove() -> bool:
	return retiring and _action_left <= 0.0


func attack_socket_global() -> Vector3:
	return global_position + Vector3(0.34 if team == 0 else -0.34, visual_height * 0.60, 0.02)


func hit_socket_global() -> Vector3:
	return global_position + Vector3(0, visual_height * 0.56, 0.02)


func top_world() -> Vector3:
	return global_position + Vector3(0, visual_height + 0.24, 0)


func _process(delta: float) -> void:
	position = position.lerp(target_position, clampf(delta * 12.0 * minf(playback_speed, 2.0), 0.0, 1.0))
	if _action_left > 0.0:
		_action_left = maxf(0.0, _action_left - delta * playback_speed)
		if _action_left <= 0.0 and not retiring:
			_action_lock = ""
			_play_loop("idle")
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta * playback_speed)
		var flash := _hit_flash / 0.16
		_sprite.modulate = Color(_base_brightness + flash * 2.8, _base_brightness + flash * 2.8, _base_brightness + flash * 2.8, 1)
	elif _sprite != null:
		_sprite.modulate = Color(_base_brightness, _base_brightness, _base_brightness, 1)


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
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = true
	_sprite.pixel_size = float(spec.get("sps", 0.0081))
	_sprite.flip_h = team == 1
	_sprite.speed_scale = playback_speed

	var texture_height := 150.0
	if frames.get_frame_count("idle") > 0:
		var first := frames.get_frame_texture("idle", 0)
		if first != null:
			texture_height = float(first.get_height())
	visual_height = texture_height * _sprite.pixel_size
	if not bool(spec.get("tight", true)):
		visual_height *= 0.70
	_sprite.position.y = texture_height * _sprite.pixel_size * (0.5 if bool(spec.get("tight", true)) else 0.35)
	_base_scale = 1.0 + 0.10 * float(star - 1)

	_visual_root = Node3D.new()
	_visual_root.name = "Visual"
	_visual_root.scale = Vector3.ONE * _base_scale
	add_child(_visual_root)
	_visual_root.add_child(_sprite)
	_sprite.play("idle")
	_add_blob()
	_add_hp_bars()


func _add_animation(frames: SpriteFrames, animation: String, folder: String) -> void:
	var count := CharacterVisuals.animation_frame_count(def_id, animation)
	if count <= 0:
		return
	frames.add_animation(animation)
	frames.set_animation_loop(animation, bool(LOOPED.get(animation, false)))
	frames.set_animation_speed(animation, float(ANIMATION_FPS[animation]))
	for i in count:
		frames.add_frame(animation, load("%s/%s_%d.png" % [folder, animation, i]))


func _build_debug_frame(frames: SpriteFrames) -> void:
	var image := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var colors: Array[Color] = [Color("ef8354"), Color("b8a56b"), Color("7cc5cf"), Color("5d8db7")]
	var color: Color = colors[element]
	image.fill_rect(Rect2i(18, 18, 28, 64), color)
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
	var width := maxf(0.62, visual_height * 0.42)
	_hp_back = _bar(width, 0.065, Color(0.015, 0.025, 0.03, 0.82))
	_hp_back.position = Vector3(0, visual_height + 0.20, 0.02)
	_hp_fill = _bar(width, 0.046, Color("86dc9a"))
	_hp_fill.position = _hp_back.position + Vector3(0, 0.002, 0.01)
	_shield_fill = _bar(width, 0.026, Color("f5d77b"))
	_shield_fill.position = _hp_back.position + Vector3(0, 0.072, 0.01)


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
	if _hp_fill == null:
		return
	_set_bar_ratio(_hp_fill, hp_ratio)
	_hp_back.visible = hp_ratio < 0.999 or shield_ratio > 0.001
	_hp_fill.visible = _hp_back.visible
	_shield_fill.visible = shield_ratio > 0.001
	_set_bar_ratio(_shield_fill, minf(shield_ratio, 1.0))


func _set_bar_ratio(bar: MeshInstance3D, ratio: float) -> void:
	bar.scale.x = maxf(ratio, 0.001)
	var mesh := bar.mesh as QuadMesh
	if mesh != null:
		bar.position.x = -mesh.size.x * (1.0 - ratio) * 0.5


func _play_loop(animation: String) -> void:
	if _sprite == null or not _sprite.sprite_frames.has_animation(animation):
		animation = "idle"
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)


func _play_action(animation: String, restart: bool = false) -> void:
	if retiring and animation != "death":
		return
	if not _sprite.sprite_frames.has_animation(animation):
		animation = "attack" if _sprite.sprite_frames.has_animation("attack") else "idle"
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
	var tween := create_tween()
	tween.set_speed_scale(playback_speed)
	tween.tween_property(_visual_root, "position:x", offset, 0.045)
	tween.tween_property(_visual_root, "position:x", 0.0, 0.13)
