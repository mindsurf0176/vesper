extends SceneTree

const Sim = preload("res://core/sim.gd")

func _init() -> void:
	var combo := Sim.create([
		{"def_id":"capricorn", "order":0, "star":1},
		{"def_id":"sagittarius", "order":1, "star":1}],
		[{"def_id":"taurus", "order":0, "star":1}], 3, 3, true)
	combo.cost[0] = 20.0
	assert(combo.manual_deploy(0, combo.units[0].uid), "워든 출격이 실패함")
	assert(combo.manual_deploy(0, combo.units[1].uid), "비질 출격이 실패함")
	assert(combo.units[1].combo_attacks_left == 2 and is_equal_approx(combo.units[1].combo_atk_mult, 1.30),
		"워든-비질 출격 연계가 발동하지 않음")
	var combo_event := false
	for event in combo.consume_events():
		if String(event.get("t", "")) == "combo" and String(event.get("name", "")) == "엄호 사격":
			combo_event = true
	assert(combo_event, "출격 연계 이벤트가 생성되지 않음")
	assert(is_equal_approx(combo._consume_combo_attack(combo.units[1]), 1.30), "연계 첫 공격 보정이 잘못됨")
	assert(is_equal_approx(combo._consume_combo_attack(combo.units[1]), 1.30), "연계 두 번째 공격 보정이 잘못됨")
	assert(combo.units[1].combo_attacks_left == 0, "연계 공격 횟수가 소진되지 않음")

	var break_sim := Sim.create([
		{"def_id":"aries", "order":0, "star":1}],
		[{"def_id":"taurus", "order":0, "star":1}], 3, 3, true)
	break_sim.cost[0] = 20.0
	assert(break_sim.manual_deploy(0, break_sim.units[0].uid), "돌파 테스트 아군 출격이 실패함")
	break_sim.cost[0] = 0.0
	break_sim.cost[1] = 20.0
	break_sim.step(0.1)
	var before_break: float = break_sim.cost[0]
	assert(break_sim.cast_command_strike(9999.0), "돌파 테스트 지휘기 타격이 실패함")
	assert(is_equal_approx(break_sim.cost[0], minf(Defs.MAX_COST, before_break + 2.0)), "전선 돌파 코스트 보너스가 적용되지 않음")
	var break_event := false
	for event in break_sim.consume_events():
		if String(event.get("t", "")) == "break":
			break_event = true
	assert(break_event, "전선 돌파 이벤트가 생성되지 않음")

	var tactical := Sim.create([
		{"def_id":"aries", "order":0, "star":1}],
		[{"def_id":"taurus", "order":0, "star":1}], 3, 3)
	tactical.units[0].deployed = true
	tactical.units[1].deployed = true
	tactical.units[0].pos = 10.0
	tactical.units[1].pos = 50.0
	var before_pos := tactical.units[0].pos
	assert(tactical.apply_tactical_order("전진"), "압박 상황 전진이 실패함")
	assert(is_equal_approx(tactical.units[0].pos - before_pos, 18.0), "압박 상황 전진 보정이 적용되지 않음")
	var target := tactical.units[1]
	target.hp = target.max_hp * 0.4
	assert(tactical.apply_tactical_order("집중"), "저체력 집중이 실패함")
	assert(is_equal_approx(target.hp, target.max_hp * 0.4 - 48.6), "저체력 집중 보정이 적용되지 않음")
	print("PASS combat fun layer")
	quit(0)
