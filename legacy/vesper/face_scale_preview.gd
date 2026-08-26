extends Node

## Face-scale QA harness.
## Spawns all sprite-backed playable characters in one locked battle scene so
## runtime `sps` tuning can be checked by face size instead of body height.

const OUT_PATH := "/Users/minseo/vesper-preview/vesper_face_scale_preview.png"
const LINEUP := [
	{ "name": "진혼병", "x": -6.05 },
	{ "name": "운구 소총수", "x": -5.05 },
	{ "name": "관지기", "x": -4.05 },
	{ "name": "소등사", "x": -3.05 },
	{ "name": "집전 의무관", "x": -2.10 },
	{ "name": "사열 돌격수", "x": -1.10 },
	{ "name": "납골 방패병", "x": -0.05 },
	{ "name": "망종 중계사", "x": 1.00 },
]

var battle: Node
var t := 0.0
var spawned := false
var captured := false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	battle = load("res://legacy/vesper/battle3d.tscn").instantiate()
	add_child(battle)


func _process(delta: float) -> void:
	t += delta
	if not spawned and t >= 0.35:
		_spawn_lineup()
		spawned = true
	if spawned:
		_update_preview_camera()
	if spawned and not captured and t >= 0.95:
		var err := get_viewport().get_texture().get_image().save_png(OUT_PATH)
		print("CAPTURED %s err=%d" % [OUT_PATH, err])
		captured = true
	elif captured and t >= 1.15:
		get_tree().quit()


func _spawn_lineup() -> void:
	battle.simulation_mode = true
	battle.cost = 10.0
	for item in LINEUP:
		var d := _deck_def(str(item["name"]))
		if d.is_empty():
			continue
		battle._spawn(d, battle.ALLY, float(item["x"]))
		var u = battle.units[-1]
		u.position.z = 0.0
		u.moving = false
		u.in_combat = false
		u.atk_anim = 0.0
	battle.running = false
	battle.paused_by_player = true


func _deck_def(unit_name: String) -> Dictionary:
	for d in battle.DECK:
		if str(d.get("name", "")) == unit_name:
			return d
	return {}


func _update_preview_camera() -> void:
	if battle.cam == null:
		return
	var target := Vector3(-2.55, 1.05, 0.0)
	var pos := Vector3(-2.55, 2.45, 12.4)
	battle.cam.fov = 29.0
	battle.cam.position = pos
	battle.cam_base = pos
	battle.cam.look_at(target, Vector3.UP)
	if battle.cam.attributes != null:
		battle.cam.attributes.dof_blur_far_enabled = false
		battle.cam.attributes.dof_blur_near_enabled = false
