extends SceneTree

const Sim = preload("res://core/sim.gd")

func _init() -> void:
	var ally := {"def_id":"aries", "order":0, "star":1}
	var enemy := {"def_id":"sagittarius", "order":0, "star":1}
	var sim = Sim.create([ally], [enemy], 3, 3)
	for _i in 3:
		sim.step(1.0)
	assert(sim.cast_command_strike(48.0), "지휘기가 적 유닛을 타격하지 못함")
	var events := sim.consume_events()
	var found := false
	for event in events:
		if String(event.get("t", "")) == "command_hit":
			found = true
	assert(found, "지휘기 이벤트가 프레젠터로 전달되지 않음")
	print("PASS combat command")
	quit(0)
