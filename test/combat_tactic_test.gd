extends SceneTree

func _initialize() -> void:
	var pressure := Match.create(202, true)
	var fortress := Match.create(202, true)
	for game in [pressure, fortress]:
		game.seats[0].player.roster = [{"def_id":"aries", "star":1, "order":0}]
		game.seats[1].player.roster = [{"def_id":"aries", "star":1, "order":0}]
	pressure.seats[0].player.tactic = "압박"
	fortress.seats[0].player.tactic = "요새"
	var pressure_sim := pressure.build_sim(0, 1)
	var fortress_sim := fortress.build_sim(0, 1)
	assert(pressure_sim.units[0].atk > fortress_sim.units[0].atk, "압박 전술 공격력 보너스가 반영되지 않음")
	assert(fortress_sim.units[0].max_hp > pressure_sim.units[0].max_hp, "요새 전술 HP 보너스가 반영되지 않음")
	print("PASS combat tactic modifiers")
	quit(0)
