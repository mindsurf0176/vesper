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
	_test_retreat_and_redeploy_presentation()
	await process_frame
	_test_actor_state_machine()
	await process_frame
	_test_death_lifecycle()
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


func _test_retreat_and_redeploy_presentation() -> void:
	print("[retreat presentation]")
	var sim := CombatSim.create(_lineup(["aries"]), _lineup(["capricorn"]))
	sim.cost[0] = 20.0
	sim.cost[1] = 20.0
	sim.step(Defs.TICK)
	presenter.bind_sim(sim)
	presenter._process(Defs.TICK)
	var ally := _find_sim_unit(sim, "aries", 0)
	ok(presenter.actor_for_test(ally.uid) != null, "후퇴 전 actor가 전장에 존재한다")
	assert(sim.manual_retreat(0, ally.uid), "프레젠테이션 검증용 후퇴 실패")
	presenter._process(Defs.TICK)
	ok(presenter.actor_for_test(ally.uid) == null, "후퇴 event가 전장 actor를 제거한다")
	for _i in 5:
		sim.step(1.0)
	sim.cost[0] = ally.deploy_cost
	assert(sim.manual_deploy(0, ally.uid), "프레젠테이션 검증용 재출격 실패")
	presenter._process(Defs.TICK)
	ok(presenter.actor_for_test(ally.uid) != null, "재출격 snapshot이 actor를 다시 생성한다")


func _test_actor_state_machine() -> void:
	print("[actor state machine]")
	var state := {
		"uid": 9001, "def_id": "aries", "team": 0, "star": 1,
		"hp": 100.0, "max_hp": 100.0, "shield": 0.0, "engaged": false,
	}
	var actor := BattleActor3D.new()
	root.add_child(actor)
	actor.setup(state, Vector3.ZERO)
	actor.apply_snapshot(state, Vector3(1.0, 0.0, 0.0))
	actor._process(Defs.TICK)
	ok(actor.state_name_for_test() == "locomotion" and actor._sprite.animation == "walk",
		"목표점까지 보간 중에는 walk를 유지한다")
	actor.play_attack()
	actor.apply_snapshot(state, Vector3(2.0, 0.0, 0.0))
	actor._process(Defs.TICK)
	ok(actor.state_name_for_test() == "attack" and actor._sprite.animation == "attack",
		"action lock 동안 locomotion이 공격을 선점하지 않는다")
	actor._action_left = 0.01
	actor.position = actor.target_position
	state["engaged"] = true
	actor.apply_snapshot(state, actor.position, true)
	actor._process(0.12)
	ok(actor._sprite.animation == "aim", "도착해 교전 중이면 aim으로 전환한다")
	state["engaged"] = false
	actor.apply_snapshot(state, actor.position, true)
	actor._process(0.12)
	ok(actor._sprite.animation == "idle", "도착해 비전투 중이면 idle로 전환한다")
	actor.queue_free()


func _test_death_lifecycle() -> void:
	print("[death lifecycle]")
	var sim := CombatSim.create(_lineup(["aries"]), _lineup(["taurus"]))
	sim.cost[0] = 20.0
	sim.cost[1] = 20.0
	sim.step(Defs.TICK)
	presenter.bind_sim(sim)
	presenter._process(Defs.TICK)
	var victim := _find_sim_unit(sim, "taurus", 1)
	var actor := presenter.actor_for_test(victim.uid)
	actor._set_opacity(1.0)
	var death_looped := actor._sprite.sprite_frames.get_animation_loop("death")
	victim.alive = false
	victim.hp = 0.0
	sim._events.append({"t": "death", "uid": victim.uid})
	presenter._process(Defs.TICK)
	ok(not death_looped, "death clip은 반복하지 않는다")
	ok(presenter.active_actor_count_for_test() == 1 and presenter.retiring_actor_count_for_test() == 1,
		"death event가 actor를 active에서 retiring으로 원자적으로 옮긴다")
	sim._events.append({"t": "hit", "from": victim.uid, "to": victim.uid, "dmg": 1.0})
	sim._events.append({"t": "ability", "uid": victim.uid, "name": "후속 이벤트"})
	sim._events.append({"t": "death", "uid": victim.uid})
	presenter._process(Defs.TICK)
	ok(actor.state_name_for_test() == "death", "death 후 hit·ability·중복 death가 상태를 되돌리지 않는다")
	var opacity_before := actor.opacity_for_test()
	var faded := false
	for i in 180:
		actor._process(1.0 / 60.0)
		faded = faded or actor.opacity_for_test() < opacity_before
		presenter._cleanup_retiring()
	ok(faded, "death 종료 구간에서 opacity가 감소한다")
	ok(presenter.retiring_actor_count_for_test() == 0, "death actor는 hard limit 안에 제거된다")
	presenter.reset_presentation()
	ok(presenter.active_actor_count_for_test() == 0 and presenter.retiring_actor_count_for_test() == 0,
		"reset 후 active와 retiring registry가 모두 비워진다")


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
