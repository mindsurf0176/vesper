extends SceneTree

const Session = preload("res://core/corridor_session.gd")
const Relics = preload("res://core/relics.gd")

func _init() -> void:
	var all := Relics.all()
	assert(all.size() == 15, "유물 풀이 15종이 아님")
	var ids: Array[String] = []
	var unique_ids := {}
	for relic in all:
		ids.append(str(relic["id"]))
		unique_ids[str(relic["id"])] = true
	assert(ids.size() == unique_ids.size(), "유물 id가 중복됨")

	var session: CorridorSession = Session.create(9090)
	var player: Econ.Player = session.human_seat().player
	player.roster = [{"def_id":"aries", "star":1, "order":0}]
	player.relics = ids
	session.seats[1].player.roster = [{"def_id":"aries", "star":1, "order":0}]
	var sim = session.build_sim(0, 1)
	var unit = sim.units[0]
	var base := UnitDB.get_def("aries")
	assert(unit.max_hp > float(base["hp"]), "생존 유물이 HP에 반영되지 않음")
	assert(unit.atk > float(base["atk"]), "공격 유물이 공격력에 반영되지 않음")
	assert(unit.armor > float(base["armor"]), "방어 유물이 방어력에 반영되지 않음")
	assert(unit.atk_range > float(base["atk_range"]) and unit.move_speed > float(base["move_speed"]), "사거리·기동 유물이 반영되지 않음")

	sim.cost[0] = 14.0
	assert(sim.manual_deploy(0, unit.uid), "유물 보유 전투원이 출격하지 않음")
	var saw_relic_event := false
	for event in sim.consume_events():
		if event.get("t", "") == "relic":
			saw_relic_event = true
	assert(saw_relic_event, "유물 발동 이벤트가 presentation으로 전달되지 않음")
	print("PASS relic effects and event contract")
	quit(0)
