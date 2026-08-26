extends SceneTree

const LB = preload("res://core/line_battle.gd")

func _init() -> void:
	var battle = LB.new(520.0, 1000.0)
	var striker := {"name":"라온", "role":LB.STRIKER, "cost":2, "hp":80, "atk":20, "range":2.0, "speed":6.0, "aspd":1.0}
	var defender := {"name":"관지기", "role":LB.DEFENDER, "cost":3, "hp":100, "atk":8, "range":2.0, "speed":2.0, "aspd":1.0}

	var uid := battle.deploy(striker)
	assert(uid > 0, "유닛 소환 실패")
	assert(is_equal_approx(battle.cost, 1.0), "소환 코스트 차감 실패")
	assert(battle.deploy(defender) == -1, "코스트 부족 소환이 허용됨")

	battle.reset(520.0, 1000.0)
	battle.cost = LB.MAX_COST
	battle.deploy(striker, 10.0)
	battle.spawn_enemy({"name":"확산체", "role":LB.RANGER, "hp":10, "atk":1, "range":1.0, "speed":0.0, "aspd":1.0}, 90.0)
	battle.step(1.0 / 30.0)
	var moving_snapshot: Dictionary = battle.snapshot()
	assert(bool(moving_snapshot["units"][0]["moving"]), "라인 코어가 이동 상태를 기록하지 않음")
	for _i in 119:
		battle.step(1.0 / 30.0)
	assert(battle.enemy_core_hp < 520.0 or not battle.consume_events().is_empty(), "전투 진행 이벤트 없음")

	battle.reset()
	assert(battle.use_soshin(), "소신 발동 실패")
	assert(is_equal_approx(battle.cost, 6.0), "소신 코스트 보상 실패")
	assert(is_equal_approx(battle.ally_core_hp, 930.0), "소신 코어 피해 실패")
	print("PASS line battle core")
	quit(0)
