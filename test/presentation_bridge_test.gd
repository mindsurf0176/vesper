extends SceneTree

## snapshot/event 기반 passive BattleActor3D bridge 검증.
##   godot --headless --path . --script res://test/presentation_bridge_test.gd

var passed := 0
var failed := 0
var presenter: BattlePresenter


func _initialize() -> void:
	presenter = BattlePresenter.new()
	presenter.size = Vector2(1280, 660)
	root.add_child(presenter)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_test_spawn_and_snapshot()
	await process_frame
	_test_event_mapping()
	await process_frame
	_test_presentation_is_passive()
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	presenter.queue_free()
	quit(1 if failed > 0 else 0)


func ok(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("  [OK] %s" % label)
	else:
		failed += 1
		print("  [FAIL] %s %s" % [label, detail])


func _test_spawn_and_snapshot() -> void:
	print("[snapshot bridge]")
	var sim := CombatSim.create(_lineup(["aries"]), _lineup(["taurus"]))
	sim.cost[0] = 20.0
	sim.cost[1] = 20.0
	sim.step(Defs.TICK)
	presenter.bind_sim(sim)
	presenter._process(Defs.TICK)
	var ally := _find_sim_unit(sim, "aries", 0)
	var actor := presenter.actor_for_test(ally.uid)
	ok(actor != null and actor.def_id == "aries", "deployed snapshot이 Vesper actor를 spawn한다")
	var before := actor.target_position.x
	ally.pos += 8.0
	presenter._process(Defs.TICK)
	ok(actor.target_position.x > before, "snapshot x 이동이 world target에 반영된다")


func _test_event_mapping() -> void:
	print("[event bridge]")
	var sim := presenter.sim
	var ally := _find_sim_unit(sim, "aries", 0)
	var enemy := _find_sim_unit(sim, "taurus", 1)
	var ally_actor := presenter.actor_for_test(ally.uid)
	var enemy_actor := presenter.actor_for_test(enemy.uid)
	sim._events.append({"t": "hit", "from": ally.uid, "to": enemy.uid, "dmg": 10.0})
	presenter._process(Defs.TICK)
	ok(ally_actor._action_lock == "attack", "hit event의 공격자가 attack clip을 재생한다")
	ok(enemy_actor._action_lock == "hit", "hit event의 대상이 hit clip을 재생한다")
	sim._events.append({"t": "ability", "uid": ally.uid, "name": "선봉"})
	presenter._process(Defs.TICK)
	ok(ally_actor._action_lock == "attack", "ability event가 actor action을 재생한다")


func _test_presentation_is_passive() -> void:
	print("[passive contract]")
	var a := CombatSim.create(_lineup(["aries", "sagittarius"]), _lineup(["taurus", "pisces"]))
	var b := CombatSim.create(_lineup(["aries", "sagittarius"]), _lineup(["taurus", "pisces"]))
	presenter.bind_sim(a)
	while not a.finished:
		a.step(Defs.TICK)
		presenter._process(Defs.TICK)
	while not b.finished:
		b.step(Defs.TICK)
	ok(a.result() == b.result(), "presentation 재생 여부가 deterministic sim 결과를 바꾸지 않는다")


func _lineup(ids: Array) -> Array:
	var out := []
	for id in ids:
		out.append({"def_id": id, "star": 1, "order": out.size()})
	return out


func _find_sim_unit(sim: CombatSim, def_id: String, team: int) -> CombatSim.SimUnit:
	for unit in sim.units:
		if unit.def_id == def_id and unit.team == team:
			return unit
	return null
