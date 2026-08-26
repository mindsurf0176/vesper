extends Node
## HD 스프라이트 인게임 캡처 하네스(임시). --burst: 0.8~9.5s 격프레임 캡처.

var battle: Node
var t := 0.0
var spawned := false
var burst := false
var cap_i := 0
var skip := 0
var done := false
var shots := [1.0, 3.2, 5.2]
var idx := 0
var focus := false
var focus_unit: Node3D

func _ready() -> void:
	burst = "--burst" in OS.get_cmdline_user_args()
	focus = "--focus" in OS.get_cmdline_user_args()
		battle = load("res://legacy/vesper/battle3d.tscn").instantiate()
	add_child(battle)

func _process(delta: float) -> void:
	if done:
		return
	t += delta
	if not spawned and t > 0.4:
		spawned = true
		var sod: Dictionary
		var tank: Dictionary
		for d in battle.DECK:
			if d["name"] == "소등사": sod = d
			if d["name"] == "관지기": tank = d
		if "--solo" in OS.get_cmdline_user_args():
			battle._spawn(sod, battle.ALLY)
			focus_unit = battle.units.back()
		else:
			battle._spawn(tank, battle.ALLY)
			battle._spawn(sod, battle.ALLY)
			battle._spawn(battle.EDEF["tank"], battle.ENEMY)
	if focus:
		_update_focus_camera()
	if burst:
		if t >= 0.8 and t <= 9.5:
			skip += 1
			if skip % 2 == 0:
				_cap()
		elif t > 9.5:
			done = true
			get_tree().quit()
	else:
		if idx < shots.size() and t >= shots[idx]:
			_shot(idx)
			idx += 1
		elif idx >= shots.size():
			done = true
			get_tree().quit()

func _cap() -> void:
	var i := cap_i
	cap_i += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"/Users/minseo/vesper-rig-kits/sodeungsa-cel/roto/_burst/b_%03d.png" % i)

func _update_focus_camera() -> void:
	if focus_unit == null or not is_instance_valid(focus_unit) or battle.cam == null:
		return
	var target := focus_unit.global_position + Vector3(0, max(0.8, focus_unit.vh * 0.48), 0)
	var camera_pos := Vector3(target.x, 2.65, target.z + 6.8)
	battle.cam.fov = 25.0
	battle.cam.position = camera_pos
	battle.cam_base = camera_pos
	battle.cam.look_at(target, Vector3.UP)
	if battle.cam.attributes != null:
		battle.cam.attributes.dof_blur_far_enabled = false
		battle.cam.attributes.dof_blur_near_enabled = false

func _shot(i: int) -> void:
	await RenderingServer.frame_post_draw
	var filename := "_ingame_focus_%d.png" % i if focus else "_ingame_%d.png" % i
	get_viewport().get_texture().get_image().save_png(
		"/Users/minseo/vesper-rig-kits/sodeungsa-cel/roto/%s" % filename)
