extends SceneTree

## 회랑 보상이 기존 라인 전투 스탯에 실제로 연결되는지 검증한다.

func _initialize() -> void:
	var plain := Match.create(101, true)
	var relic_run := Match.create(101, true)
	for game in [plain, relic_run]:
		game.seats[0].player.roster = [{"def_id":"aries", "star":1, "order":0}]
		game.seats[1].player.roster = [{"def_id":"aries", "star":1, "order":0}]
	relic_run.seats[0].player.relics = ["hollow_crown"]
	var base_sim := plain.build_sim(0, 1)
	var relic_sim := relic_run.build_sim(0, 1)
	assert(relic_sim.units[0].atk > base_sim.units[0].atk, "공허 왕관 공격력 보너스가 전투에 반영되지 않음")
	assert(is_equal_approx(relic_sim.units[0].atk / base_sim.units[0].atk, 1.15), "유물 공격력 배율이 잘못됨")
	print("PASS corridor relic combat modifier")
	quit(0)
