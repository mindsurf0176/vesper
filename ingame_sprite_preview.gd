extends Node

## Runtime sprite preview harness.
## Spawns the current sprite-backed playable lineup in the real battle scene and
## captures a few in-game frames for visual QA.

const OUT_DIR := "/Users/minseo/vesper-preview"
const SHOTS := [0.75, 1.8, 3.2]

var battle: Node
var t := 0.0
var spawned := false
var shot_idx := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	battle = load("res://battle3d.tscn").instantiate()
	add_child(battle)


func _process(delta: float) -> void:
	t += delta
	if not spawned and t >= 0.35:
		_spawn_preview_units()
		spawned = true
	if spawned:
		_update_preview_camera()
	if shot_idx < SHOTS.size() and t >= float(SHOTS[shot_idx]):
		_capture(shot_idx)
		shot_idx += 1
	elif shot_idx >= SHOTS.size() and t > float(SHOTS[-1]) + 0.25:
		get_tree().quit()


func _spawn_preview_units() -> void:
	battle.simulation_mode = true
	battle.cost = 10.0
	var jin := _deck_def("진혼병")
	var sayeol := _deck_def("사열 돌격수")
	var gwan := _deck_def("관지기")
	var napgol := _deck_def("납골 방패병")
	var mangjong := _deck_def("망종 중계사")
	var rifle := _deck_def("운구 소총수")
	var sod := _deck_def("소등사")
	if not jin.is_empty():
		battle._spawn(jin, battle.ALLY, -5.55)
		battle.units[-1].position.z = -0.35
	if not sayeol.is_empty():
		battle._spawn(sayeol, battle.ALLY, -4.90)
		battle.units[-1].position.z = -0.10
	if not gwan.is_empty():
		battle._spawn(gwan, battle.ALLY, -4.25)
		battle.units[-1].position.z = 0.12
	if not napgol.is_empty():
		battle._spawn(napgol, battle.ALLY, -3.60)
		battle.units[-1].position.z = 0.24
	if not mangjong.is_empty():
		battle._spawn(mangjong, battle.ALLY, -3.00)
		battle.units[-1].position.z = 0.32
	if not rifle.is_empty():
		battle._spawn(rifle, battle.ALLY, -2.40)
		battle.units[-1].position.z = 0.44
	if not sod.is_empty():
		battle._spawn(sod, battle.ALLY, -1.85)
		battle.units[-1].position.z = 0.58
	battle._spawn(battle.EDEF["tank"], battle.ENEMY, 1.95)
	battle.units[-1].position.z = 0.0


func _deck_def(unit_name: String) -> Dictionary:
	for d in battle.DECK:
		if str(d.get("name", "")) == unit_name:
			return d
	return {}


func _update_preview_camera() -> void:
	if battle.cam == null:
		return
	var target := Vector3(-2.65, 1.0, 0.05)
	var pos := Vector3(-2.75, 3.15, 11.05)
	battle.cam.fov = 33.0
	battle.cam.position = pos
	battle.cam_base = pos
	battle.cam.look_at(target, Vector3.UP)
	if battle.cam.attributes != null:
		battle.cam.attributes.dof_blur_far_enabled = false
		battle.cam.attributes.dof_blur_near_enabled = false


func _capture(i: int) -> void:
	var path := "%s/vesper_ingame_sprite_preview_%d.png" % [OUT_DIR, i]
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED %s err=%d" % [path, err])
