extends Node

const Unit3D = preload("res://legacy/vesper/unit3d.gd")


func _ready() -> void:
	var unit = Unit3D.new()
	var frames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var folder := "res://assets/sprites/gwanjigi_pl"
	var contracts := {
		"idle": { "frames": 1, "fps": 4.0, "loop": true },
		"walk": { "frames": 8, "fps": 10.0, "loop": true },
		"aim": { "frames": 4, "fps": 6.0, "loop": true },
		"attack": { "frames": 6, "fps": 12.0, "loop": false },
		"hit": { "frames": 4, "fps": 10.0, "loop": false },
		"death": { "frames": 6, "fps": 8.0, "loop": false },
	}
	for animation: String in contracts:
		var contract: Dictionary = contracts[animation]
		unit._add_anim(frames, animation, folder, contract["fps"], contract["loop"])
		assert(frames.has_animation(animation), "%s animation missing" % animation)
		assert(frames.get_frame_count(animation) == contract["frames"], "%s frame count mismatch" % animation)
		assert(is_equal_approx(frames.get_animation_speed(animation), contract["fps"]), "%s fps mismatch" % animation)
		assert(frames.get_animation_loop(animation) == contract["loop"], "%s loop mismatch" % animation)

	var animated := AnimatedSprite3D.new()
	animated.sprite_frames = frames
	add_child(animated)
	animated.play("walk")
	unit.asp = animated
	unit.sprite_base_y = 2.0
	unit.vh = 1.0
	unit.moving = true
	unit._anim_motion(0.16)
	assert(is_zero_approx(animated.position.x), "multi-frame walk received procedural sway")
	assert(is_equal_approx(animated.position.y, 2.0), "multi-frame walk received procedural bob")

	# 피격은 진행 중인 공격을 즉시 취소하고 4프레임을 처음부터 끝까지 보여 준다.
	unit.use_sprite = true
	unit.has_attack = true
	unit.in_combat = true
	unit.moving = false
	unit.atk_anim = 0.55
	animated.play("attack")
	animated.frame = 3
	unit._begin_hit_animation()
	var hit_duration := float(frames.get_frame_count("hit")) / frames.get_animation_speed("hit")
	assert(is_zero_approx(unit.atk_anim), "hit did not cancel the active attack")
	assert(animated.animation == "hit", "hit did not preempt attack immediately")
	assert(animated.frame == 0, "hit did not restart from its first frame")
	assert(unit.hit_anim >= hit_duration, "hit timer is shorter than its four-frame clip")

	# 실제 AnimatedSprite3D 재생기로 마지막(4번째) 프레임 도달을 검증한다.
	await get_tree().create_timer(0.36).timeout
	assert(animated.animation == "hit", "hit animation changed before its final frame")
	assert(animated.frame == 3, "hit did not reach its fourth frame")
	var remained_locked: bool = unit._update_sprite_animation(hit_duration - 0.01)
	assert(remained_locked, "hit lock ended before the clip duration")
	assert(animated.animation == "hit", "hit animation left before completion grace")
	await get_tree().create_timer(0.08).timeout
	var final_hit_step: bool = unit._update_sprite_animation(0.04)
	assert(final_hit_step, "final hit step was not action-locked")
	assert(is_zero_approx(unit.hit_anim), "hit timer did not finish")
	assert(is_zero_approx(unit.atk_anim), "cancelled attack resumed after hit")
	assert(animated.animation == "aim", "unit did not return to its current combat state after hit")

	unit.asp = null
	animated.queue_free()
	unit.free()
	frames = null
	await get_tree().process_frame
	print("PASS unit3d animation contract")
	get_tree().quit()
