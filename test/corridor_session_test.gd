extends SceneTree

const Session = preload("res://core/corridor_session.gd")

func _init() -> void:
	var session: CorridorSession = Session.create(4242)
	assert(session.seats.size() == 2, "회랑 세션이 다인 매치 좌석을 생성함")
	assert(session.pair_up() == [[0, 1]], "회랑 세션이 단일 조우를 만들지 못함")
	session.seats[0].player.roster = [
		{"def_id":"aries", "star":1, "order":0},
		{"def_id":"taurus", "star":1, "order":1},
		{"def_id":"sagittarius", "star":1, "order":2}]
	session.seats[1].player.roster = [{"def_id":"aries", "star":1, "order":0}]
	var sim: CombatSim = session.build_sim(0, 1)
	assert(sim != null and sim.units.size() == 4, "원정대와 조우 편성이 전투 시뮬레이터에 연결되지 않음")
	var baseline_atk := sim.units[0].atk
	var baseline_hp := sim.units[3].max_hp
	var baseline_enemy_atk := sim.units[3].atk
	var baseline_enemy_move := sim.units[3].move_speed

	session.set_corridor_mutator({"id":"overclock", "player_cost_regen_mult":1.12, "enemy_atk_mult":1.08})
	var overclock: CombatSim = session.build_sim(0, 1)
	assert(overclock._regen[0] > sim._regen[0], "과충전이 아군 코스트 충전을 올리지 않음")
	assert(overclock.units[3].atk > baseline_enemy_atk, "과충전이 적 공격력을 올리지 않음")

	session.set_corridor_mutator({"id":"thin_lantern", "player_atk_mult":1.08, "enemy_hp_mult":1.12})
	var thin_lantern: CombatSim = session.build_sim(0, 1)
	assert(thin_lantern.units[0].atk > baseline_atk, "희박한 등불이 아군 공격력을 올리지 않음")
	assert(thin_lantern.units[3].max_hp > baseline_hp, "희박한 등불이 적 체력을 올리지 않음")

	session.set_corridor_mutator({"id":"red_tide", "enemy_move_mult":1.15, "enemy_atk_mult":0.92})
	var red_tide: CombatSim = session.build_sim(0, 1)
	assert(red_tide.units[3].move_speed > baseline_enemy_move, "붉은 조류가 적 이동 속도를 올리지 않음")
	assert(red_tide.units[3].atk < baseline_enemy_atk, "붉은 조류의 적 공격력 페널티가 적용되지 않음")
	print("PASS corridor session")
	quit(0)
