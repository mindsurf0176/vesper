extends SceneTree

const Sim = preload("res://core/sim.gd")

func _initialize() -> void:
	var sim := Sim.create(
		[{"def_id": "aries", "order": 0, "star": 1}],
		[{"def_id": "capricorn", "order": 0, "star": 1}], 3, 3, true)
	var unit: Sim.SimUnit = sim.units[0]
	sim.cost[0] = unit.deploy_cost
	assert(sim.manual_deploy(0, unit.uid), "초기 출격 실패")
	unit.hp = unit.max_hp * 0.25
	unit.pos = 100.0
	assert(sim.manual_retreat(0, unit.uid), "후퇴 요청 실패")
	assert(not unit.deployed and unit.is_recovering() and is_equal_approx(unit.pos, 0.0), "후퇴가 본진 회복 상태로 전환되지 않음")
	assert(not sim.manual_deploy(0, unit.uid), "회복 중 재출격을 허용함")
	var hurt_hp := unit.hp
	for _i in 5:
		sim.step(1.0)
	assert(not unit.is_recovering() and is_equal_approx(unit.hp, unit.max_hp) and unit.hp > hurt_hp,
		"본진 회복이 최대 체력까지 완료되지 않음")
	sim.cost[0] = unit.deploy_cost
	assert(sim.manual_deploy(0, unit.uid), "회복 완료 후 재출격 실패")
	assert(unit.deployed and is_equal_approx(unit.hp, unit.max_hp), "재출격 상태 또는 회복 체력이 잘못됨")
	print("PASS retreat and redeploy")
	quit(0)
