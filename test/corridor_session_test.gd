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
	print("PASS corridor session")
	quit(0)
