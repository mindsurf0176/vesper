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
	var tactical := Sim.create([ally], [enemy], 3, 3)
	for _i in 3:
		tactical.step(1.0)
	var ally_unit = tactical.units[0]
	var before_pos: float = ally_unit.pos
	assert(tactical.apply_tactical_order("전진"), "전진 명령을 적용하지 못함")
	assert(ally_unit.pos > before_pos, "전진 명령이 전선에 반영되지 않음")
	assert(tactical.apply_tactical_order("방어"), "방어 명령을 적용하지 못함")
	assert(ally_unit.shield > 0.0, "방어 명령이 보호막에 반영되지 않음")
	var heavy := Sim.create([ally], [enemy], 3, 3)
	for _i in 3:
		heavy.step(1.0)
	var target = heavy.units[1]
	var before_hp: float = target.hp
	assert(heavy.apply_tactical_order("집중", 2), "강화 집중 명령을 적용하지 못함")
	assert(is_equal_approx(before_hp - target.hp, 72.0), "강화 집중 카드 피해량이 잘못됨")
	print("PASS combat command")
	quit(0)
