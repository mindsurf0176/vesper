extends Node2D
## 컷아웃 스켈레탈 리그 프로토타입 — 일러 부위(머리/몸통/다리)를 관절로 애니.
## 다리=베이스, 몸통=골반 관절로 스웨이, 머리=목 관절로 카운터 틸트 + 호흡 bob.

const DIR := "res://assets/rig/sodeungsa/"
const J_NECK := Vector2(307, 196)
const J_HIP := Vector2(307, 492)

var anim_t := 0.0
var walk := true
var capturing := false
var base_pos := Vector2(478, 78)
var rig_root: Node2D
var hip_pivot: Node2D
var neck_pivot: Node2D

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.10, 0.12)
	bg.size = Vector2(1280, 720)
	add_child(bg)
	# 바닥선
	var ground := ColorRect.new()
	ground.color = Color(0.12, 0.16, 0.18)
	ground.position = Vector2(0, 660); ground.size = Vector2(1280, 60)
	add_child(ground)

	rig_root = Node2D.new()
	rig_root.scale = Vector2(0.74, 0.74)
	rig_root.position = base_pos
	add_child(rig_root)
	rig_root.add_child(_spr("legs"))
	hip_pivot = Node2D.new(); hip_pivot.position = J_HIP
	rig_root.add_child(hip_pivot)
	var torso := _spr("torso"); torso.position = -J_HIP
	hip_pivot.add_child(torso)
	neck_pivot = Node2D.new(); neck_pivot.position = J_NECK - J_HIP
	hip_pivot.add_child(neck_pivot)
	var head := _spr("head"); head.position = -J_NECK
	neck_pivot.add_child(head)

	_apply(0.0)
	if "--shot" in OS.get_cmdline_user_args():
		_capture()

func _spr(name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(DIR + name + ".png")
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return s

func _process(delta: float) -> void:
	if capturing:
		return
	anim_t += delta
	_apply(anim_t)

func _apply(t: float) -> void:
	var sway: float = 0.10 if walk else 0.06
	var bob: float = 7.0 if walk else 3.0
	var lat: float = 9.0 if walk else 3.0
	hip_pivot.rotation = sin(t * 1.4) * sway
	neck_pivot.rotation = sin(t * 1.4 + 0.6) * 0.075
	rig_root.position = base_pos + Vector2(sin(t * 1.4) * lat, -abs(sin(t * 2.8)) * bob)
	rig_root.rotation = sin(t * 1.4) * 0.014

func _capture() -> void:
	capturing = true
	var n := 16
	var period := 2.0 * PI / 1.4
	for i in n:
		_apply(period * float(i) / float(n))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/private/tmp/claude-501/-Users-minseo/bcc13760-12c9-44df-a122-9aad86b82c83/scratchpad/rg_%02d.png" % i)
	get_tree().quit()
