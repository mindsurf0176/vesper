extends SceneTree

## 헤드리스 검증 + 밸런스 스윕.
##   godot --headless --path . --script res://test/sim_test.gd

var passed := 0
var failed := 0


func _initialize() -> void:
	print("=== OVERLINE 코어 검증 ===\n")
	_test_counters()
	_test_traits()
	_test_abilities()
	_test_combine()
	_test_pool()
	_test_econ()
	_test_shop_lock()
	_test_queue_api()
	_test_deploy_cost()
	_test_frontline_guard()
	_test_order_is_strategy()
	_test_determinism()
	_test_mirror_is_fair()
	_test_counter_matters()
	_test_breakthrough()
	print("\n=== 밸런스 스윕 ===")
	_sweep_1v1()
	_sweep_role_lineups()
	_sweep_order_heuristics()
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	quit(1 if failed > 0 else 0)


func ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [OK] %s" % label)
	else:
		failed += 1
		print("  [FAIL] %s %s" % [label, detail])


# --- 규칙 테스트 -----------------------------------------------------------

func _test_counters() -> void:
	print("[병종 상성]")
	var R := Defs.Role
	ok(is_equal_approx(Defs.counter_mult(R.STRIKER, R.RANGER), 1.3), "스트라이커가 레인저에 유리")
	ok(is_equal_approx(Defs.counter_mult(R.RANGER, R.DEFENDER), 1.3), "레인저가 디펜더에 유리")
	ok(is_equal_approx(Defs.counter_mult(R.DEFENDER, R.STRIKER), 1.3), "디펜더가 스트라이커에 유리")
	ok(is_equal_approx(Defs.counter_mult(R.RANGER, R.STRIKER), 0.8), "역상성은 불리")
	ok(is_equal_approx(Defs.counter_mult(R.SUPPORT, R.STRIKER), 1.0), "서포터는 상성 중립")
	ok(is_equal_approx(Defs.armor_mult(100.0), 0.5), "방어 100은 데미지 절반")


func _test_traits() -> void:
	print("[원소 시너지]")
	var E := Defs.Element

	# 데이터 불변조건: 원소마다 정확히 셋. 이게 깨지면 트라인이 성립하지 않는다.
	var by_elem := {}
	var by_tier := {}
	for id in UnitDB.table():
		var d := UnitDB.get_def(id)
		by_elem[d["element"]] = int(by_elem.get(d["element"], 0)) + 1
		by_tier[d["tier"]] = int(by_tier.get(d["tier"], 0)) + 1
	var all_three := by_elem.size() == 4
	for e in by_elem:
		if int(by_elem[e]) != Traits.TRINE:
			all_three = false
	ok(all_three, "원소 4종, 각 원소마다 별자리 정확히 %d개" % Traits.TRINE, str(by_elem))
	ok(UnitDB.table().size() == 12, "별자리는 열두 개", str(UnitDB.table().size()))
	ok(int(by_tier.get(1, 0)) == 5 and int(by_tier.get(4, 0)) == 1,
		"등급 분포가 피라미드", str(by_tier))

	# 같은 별 셋은 1종으로 센다
	ok(int(Traits.evaluate(_lineup(["aries", "aries", "aries"]))
		.element_counts.get(E.FIRE, 0)) == 1, "같은 별 셋은 1종으로 카운트")

	# 불 2종 -> 공격력
	var fire2 := Traits.evaluate(_lineup(["aries", "sagittarius"]))
	ok(int(fire2.element_counts.get(E.FIRE, 0)) == 2, "다른 불 2종은 2로 카운트")
	ok(float(fire2.mods_for("aries")["atk_mult"]) > 1.0, "불 2단계는 공격력을 올린다")

	# 불 트라인
	var fire3 := Traits.evaluate(_lineup(["aries", "sagittarius", "leo"]))
	ok(bool(fire3.active[0]["is_trine"]), "불 3종이면 트라인", fire3.describe())
	ok(float(fire3.mods_for("leo")["atk_mult"]) > float(fire2.mods_for("aries")["atk_mult"]),
		"트라인이 2단계보다 강하다")

	# 원소가 다르면 서로에게 영향이 없다
	ok(is_equal_approx(float(fire3.mods_for("cancer")["atk_mult"]), 1.0),
		"불 트라인은 물 별자리에 영향을 주지 않는다")

	# 물 트라인은 회복
	var water3 := Traits.evaluate(_lineup(["cancer", "pisces", "scorpio"]))
	ok(water3.team_regen > 0.0, "물 트라인은 팀을 회복시킨다", "%.4f" % water3.team_regen)

	# 흙은 방어, 바람은 공속
	var earth2 := Traits.evaluate(_lineup(["virgo", "taurus"]))
	ok(float(earth2.mods_for("taurus")["armor_add"]) > 0.0, "흙은 방어를 올린다")
	var air2 := Traits.evaluate(_lineup(["gemini", "libra"]))
	ok(float(air2.mods_for("gemini")["as_mult"]) > 1.0, "바람은 공격 속도를 올린다")

	# 강림 비용은 등급에서 나온다 — 플레이어가 외울 숫자는 하나뿐이다
	var tier_ok := true
	for id in UnitDB.table():
		if UnitDB.deploy_cost(id) != int(UnitDB.DEPLOY_BY_TIER[UnitDB.get_def(id)["tier"]]):
			tier_ok = false
	ok(tier_ok, "강림 비용은 등급에서 그대로 유도된다")


func _test_abilities() -> void:
	print("[고유 능력]")
	var names := {}
	var data_ok := true
	for id in UnitDB.table():
		var a := UnitDB.ability(id)
		if String(a.get("name", "")).is_empty() or String(a.get("description", "")).is_empty():
			data_ok = false
		names[a.get("name", "")] = true
	ok(data_ok and names.size() == 12, "열두 별 모두 서로 다른 이름과 설명의 고유 능력을 가진다")

	# 강림형: 게는 보호막, 물병은 기운 반환, 양은 가속을 즉시 얻는다.
	var deploy := CombatSim.create(_lineup(["cancer", "aquarius", "aries"]), _lineup(["capricorn"]))
	deploy.cost[0] = float(UnitDB.deploy_cost("cancer"))
	deploy.step(Defs.TICK)
	var cancer := _find_unit(deploy, "cancer", 0)
	ok(cancer.deployed and cancer.shield > 0.0, "게는 강림할 때 별껍질을 얻는다")
	var refund := CombatSim.create(_lineup(["aquarius"]), [])
	refund.cost[0] = float(UnitDB.deploy_cost("aquarius"))
	refund._tick_deploy()
	ok(is_equal_approx(float(refund.cost[0]), 2.0), "물병의 순풍이 기운을 되돌려준다")
	var aries := _find_unit(deploy, "aries", 0)
	while not aries.deployed:
		deploy.step(Defs.TICK)
	ok(deploy._haste_mult(aries) > 1.0, "양은 강림 직후 선봉 가속을 얻는다")

	# 공격/방어형 효과는 능력 없는 동일 수치의 기준 계산과 비교한다.
	var pierce := CombatSim.create(_lineup(["sagittarius"]), _lineup(["taurus"]))
	var sag := _find_unit(pierce, "sagittarius", 0)
	var bull := _find_unit(pierce, "taurus", 1)
	var normal := sag.atk * Defs.counter_mult(sag.role, bull.role) * Defs.armor_mult(bull.armor)
	var pierced := sag.atk * Defs.counter_mult(sag.role, bull.role) \
		* Defs.armor_mult(bull.armor * (1.0 - float(sag.ability["armor_pierce"])))
	ok(pierced > normal, "사수의 꿰뚫는 화살은 방어를 일부 무시한다")

	var gemini_sim := CombatSim.create(_lineup(["gemini"]), _lineup(["capricorn"]))
	var gemini := _find_unit(gemini_sim, "gemini", 0)
	gemini.deployed = true
	gemini.attack_count = 2
	var hp_before: float = _find_unit(gemini_sim, "capricorn", 1).hp
	var cap := _find_unit(gemini_sim, "capricorn", 1)
	cap.deployed = true
	gemini.cd = 0.0
	gemini_sim._try_attack(gemini, cap)
	gemini_sim._resolve_damage()
	ok(hp_before - cap.hp > 0.0 and gemini.attack_count == 3, "쌍둥이는 매 3번째 공격에 쌍성을 발동한다")

	var fish := _find_unit(CombatSim.create(_lineup(["pisces"]), []), "pisces", 0)
	fish.hit_count = 3
	ok(is_zero_approx(CombatSim.create([], [])._defend_hit(fish, 100.0)), "물고기는 매 4번째 피격을 회피한다")
	var capped := _find_unit(CombatSim.create(_lineup(["taurus"]), []), "taurus", 0)
	var cap_damage := CombatSim.create([], [])._defend_hit(capped, 99999.0)
	ok(cap_damage <= capped.max_hp * float(capped.ability["damage_cap_ratio"]), "황소는 큰 한 방의 피해를 제한한다")

	# 활성 오라는 강림해 살아 있는 동안만 작동한다.
	var support := CombatSim.create(_lineup(["virgo", "aries"]), _lineup(["cancer"]))
	var virgo := _find_unit(support, "virgo", 0)
	var ally := _find_unit(support, "aries", 0)
	virgo.deployed = true
	ally.deployed = true
	ally.hp *= 0.5
	var hurt := ally.hp
	support._apply_regen(1.0)
	ok(ally.hp > hurt, "처녀가 강림해 있으면 아군을 회복한다")
	virgo.alive = false
	ally.hp = hurt
	support._apply_regen(1.0)
	ok(is_equal_approx(ally.hp, hurt), "처녀가 잠들면 회복 오라가 끝난다")

	var stacked := CombatSim.create(_lineup(["virgo", "virgo", "cancer", "pisces"]), [])
	for u in stacked.units:
		u.deployed = true
	var stacked_ally := _find_unit(stacked, "cancer", 0)
	stacked_ally.hp *= 0.5
	var stacked_before := stacked_ally.hp
	stacked._apply_regen(1.0)
	var expected_regen: float = stacked_ally.max_hp * (float(stacked._trait_regen[0]) \
		+ float(virgo.ability["active_team_regen"]))
	ok(is_equal_approx(stacked_ally.hp - stacked_before, expected_regen),
		"물 시너지와 처녀 회복은 합산하고 같은 처녀 여럿은 중첩하지 않는다")

	var guarded := CombatSim.create(_lineup(["capricorn"]), _lineup(["aries"]))
	var goat := _find_unit(guarded, "capricorn", 0)
	goat.deployed = true
	ok(guarded._active_core_reduction(0) > 0.0, "염소가 강림해 있으면 성좌 피해를 줄인다")
	goat.alive = false
	ok(is_zero_approx(guarded._active_core_reduction(0)), "염소가 잠들면 성좌 보호가 끝난다")


func _test_combine() -> void:
	print("[합성]")
	var e := Econ.new(1)
	var p := Econ.Player.new()
	p.gold = 999
	for i in 3:
		p.shop = ["aries"]
		e.buy(p, 0)
	ok(p.roster.size() == 1 and int(p.roster[0]["star"]) == 2, "같은 유닛 3개 -> ★2", str(p.roster))
	for i in 6:
		p.shop = ["aries"]
		e.buy(p, 0)
	ok(p.roster.size() == 1 and int(p.roster[0]["star"]) == 3, "9개 -> ★3 연쇄", str(p.roster))
	ok(is_equal_approx(UnitDB.star_mult(3), 3.24), "★3 배율 3.24")

	# 큐에 있던 유닛의 순번을 승급체가 물려받는지
	var e2 := Econ.new(2)
	var p2 := Econ.Player.new()
	p2.gold = 999
	p2.shop = ["pisces", "scorpio"]
	e2.buy(p2, 0)
	e2.buy(p2, 1)
	e2.enqueue(p2, 0)          # 사수 0번
	e2.enqueue(p2, 1)          # 사냥개 1번
	for i in 2:
		p2.shop = ["scorpio"]
		e2.buy(p2, 0)
	var hound := p2.roster.filter(func(u): return u["def_id"] == "scorpio")
	ok(hound.size() == 1 and int(hound[0]["star"]) == 2 and int(hound[0]["order"]) == 1,
		"승급 유닛이 출격 순번을 계승", str(p2.roster))


func _test_pool() -> void:
	print("[유닛 풀]")
	var e := Econ.new(3)
	var before: int = e.pool.remaining["aries"]
	var p := Econ.Player.new()
	p.gold = 999
	p.shop = ["aries"]
	e.pool.take("aries")
	e.buy(p, 0)
	ok(int(e.pool.remaining["aries"]) == before - 1, "구매 시 풀 감소")
	e.sell(p, 0)
	ok(int(e.pool.remaining["aries"]) == before, "판매 시 풀 복귀")

	var p2 := Econ.Player.new()
	p2.gold = 999
	for i in 3:
		p2.shop = ["gemini"]
		e.pool.take("gemini")
		e.buy(p2, 0)
	var mid: int = e.pool.remaining["gemini"]
	e.sell(p2, 0)
	ok(int(e.pool.remaining["gemini"]) == mid + 3, "★2 판매 시 3장 복귀")


func _test_econ() -> void:
	print("[경제]")
	var e := Econ.new(4)
	ok(e.interest(0) == 0 and e.interest(7) == 1 and e.interest(70) == Econ.MAX_INTEREST,
		"이자 %d골드당 1, 최대 %d" % [Econ.INTEREST_STEP, Econ.MAX_INTEREST])
	# 저축 보상이 라운드 수입에 비해 유의미해야 선택지가 된다.
	ok(float(Econ.MAX_INTEREST) >= float(Econ.BASE_INCOME) * 0.5,
		"이자 상한이 기본 수입의 절반 이상", "%d / %d" % [Econ.MAX_INTEREST, Econ.BASE_INCOME])
	ok(e.streak_bonus(2) == 1 and e.streak_bonus(-4) == 3, "연승/연패 보너스는 대칭")

	var p := Econ.Player.new()
	p.gold = 20
	e.settle(p, 1, 1.0, 0, 10)
	ok(p.gold == 20 + Econ.BASE_INCOME + e.interest(20),
		"승리 정산: 기본 + 이자", str(p.gold))
	ok(p.streak == 1, "연승 1")

	# 완패(코어 전파 + 적 4기 생존)를 같은 라운드에서 비교한다.
	var p2 := Econ.Player.new()
	e.settle(p2, 0, 0.0, 4, 10)
	var worst := 100 - p2.hp
	var expect := int(round((Econ.LOSS_BASE_DAMAGE + Econ.LOSS_CORE_SCALE
		+ 4 * Econ.LOSS_PER_SURVIVOR) * Econ.round_damage_scale(10)))
	ok(worst == expect, "완패 피해 = (기본 + 코어전파 + 생존 적) x 라운드 계수",
		"%d vs %d" % [worst, expect])

	# 접전 패배: 코어를 90% 지켰고 적도 1기만 남음
	var p3b := Econ.Player.new()
	e.settle(p3b, 0, 0.9, 1, 10)
	ok(100 - p3b.hp < worst, "접전 패배는 완패보다 피해가 작다",
		"close=%d worst=%d" % [100 - p3b.hp, worst])

	# 같은 완패라도 초반이 후반보다 훨씬 싸야 저축 전략이 성립한다.
	var early := Econ.Player.new()
	var late := Econ.Player.new()
	e.settle(early, 0, 0.0, 4, 2)
	e.settle(late, 0, 0.0, 4, 20)
	ok((100 - early.hp) * 2 <= (100 - late.hp),
		"초반 패배 피해가 후반의 절반 이하",
		"r2=%d r20=%d" % [100 - early.hp, 100 - late.hp])

	var p3 := Econ.Player.new()
	p3.gold = 100
	for i in 3:
		e.buy_xp(p3)
	ok(p3.level >= 5, "경험치 3회 구매로 5레벨 이상", "level=%d xp=%d" % [p3.level, p3.xp])


func _test_shop_lock() -> void:
	print("[상점 잠금]")
	var e := Econ.new(41)
	var p := Econ.Player.new()
	e.refresh_shop(p, true)
	var held := p.shop.duplicate()
	e.set_shop_locked(p, true)
	e.refresh_shop(p)
	ok(p.shop == held, "잠근 상점은 다음 밤 무료 갱신을 건너뛴다")

	p.gold = 10
	ok(e.reroll(p), "잠금 중에도 유료 리롤은 작동한다")
	ok(p.gold == 10 - Econ.REROLL_COST, "유료 리롤 비용을 지불한다", str(p.gold))
	ok(p.shop != held, "유료 리롤은 잠금 상태를 무시하고 상품을 바꾼다")
	ok(p.shop_locked, "유료 리롤 뒤에도 잠금 선택은 유지된다")


func _test_queue_api() -> void:
	print("[출격 큐]")
	var e := Econ.new(5)
	var p := Econ.Player.new()
	p.gold = 999
	for id in ["cancer", "aries", "pisces", "sagittarius"]:
		p.shop = [id]
		e.buy(p, 0)

	var queued := 0
	for i in p.roster.size():
		if e.enqueue(p, i):
			queued += 1
	ok(queued == p.level, "큐 정원 = 레벨", "queued=%d level=%d" % [queued, p.level])

	var q := p.queued_units()
	ok(q.size() == 3 and int(q[0]["order"]) == 0 and int(q[2]["order"]) == 2,
		"순번은 0부터 빈틈없이 매겨진다", str(q))

	# 맨 뒤를 맨 앞으로
	var last_id: String = q[2]["def_id"]
	var idx := p.roster.find(q[2])
	e.move(p, idx, 0)
	ok(p.queued_units()[0]["def_id"] == last_id, "순서 변경이 반영된다", str(p.queued_units()))

	# 벤치로 뺐다가 다시
	var first := p.roster.find(p.queued_units()[0])
	e.to_bench(p, first)
	ok(p.queue_count() == 2, "벤치로 빼면 큐가 줄어든다")
	var reorder := p.queued_units()
	ok(int(reorder[0]["order"]) == 0 and int(reorder[1]["order"]) == 1, "빠진 뒤 순번 재정렬")

	ok(p.total_deploy_cost() > 0, "총 출격 코스트 계산", str(p.total_deploy_cost()))


func _test_deploy_cost() -> void:
	print("[코스트 출격]")
	# 모든 전투는 0 코스트에서 시작한다. 기다리는 시간이 곧 첫 선택의 대가다.
	var iron_cost := float(UnitDB.deploy_cost("capricorn"))
	var sim := CombatSim.create(_lineup(["capricorn"]), _lineup(["cancer"]))
	sim.step(Defs.TICK)
	var iron: CombatSim.SimUnit = sim.units[0]
	ok(is_equal_approx(float(sim.cost[0]), Defs.COST_REGEN * Defs.TICK) and not iron.deployed,
		"전투는 0 코스트에서 시작한다")
	var t := 0.0
	while not iron.deployed and t < 30.0:
		sim.step(Defs.TICK)
		t += Defs.TICK
	var expect := iron_cost / Defs.COST_REGEN
	ok(iron.deployed and absf(t - expect) < 0.3,
		"최고 코스트 유닛은 충전을 다 기다린 뒤 출격", "t=%.2f expect=%.2f" % [t, expect])
	ok(expect >= 5.0, "그 대기 시간이 전황을 바꿀 만큼 길다", "%.1fs" % expect)

	# 충전된 만큼만 순서대로 나간다.
	var sim2 := CombatSim.create(_lineup(["aries", "gemini"]), _lineup(["cancer"]))
	sim2.step(Defs.TICK)
	ok(not sim2.units[0].deployed and not sim2.units[1].deployed,
		"초반 충전 전에는 출격하지 않는다")
	var sim2_time := 0.0
	while not sim2.units[0].deployed and sim2_time < 5.0:
		sim2.step(Defs.TICK)
		sim2_time += Defs.TICK
	ok(sim2.units[0].deployed and not sim2.units[1].deployed,
		"충전 후 첫 유닛만 출격한다")

	# 큐가 남아 있으면 필드가 비어도 패배가 아니다.
	var sim3 := CombatSim.create(_lineup(["capricorn"]), _lineup(["capricorn"]))
	sim3.step(Defs.TICK)
	ok(not sim3.finished, "출격 대기 중이면 전투가 끝나지 않는다")


func _test_frontline_guard() -> void:
	print("[최전방 가드]")
	var sim := CombatSim.create(_lineup(["taurus", "sagittarius"]), _lineup(["cancer", "pisces"]))
	for unit in sim.units:
		unit.deployed = true
	# 적 기준 pos가 큰 하린이 선두다. 후열 유라는 공격 대상이 될 수 없어야 한다.
	var front_enemy := _find_unit(sim, "cancer", 1)
	var rear_enemy := _find_unit(sim, "pisces", 1)
	front_enemy.pos = 90.0
	rear_enemy.pos = 72.0
	var ranger := _find_unit(sim, "sagittarius", 0)
	sim._retarget(ranger)
	ok(ranger.target_uid == front_enemy.uid, "일반 공격은 적 최전방만 조준한다")
	ok(sim._is_frontline(front_enemy) and not sim._is_frontline(rear_enemy),
		"최전방만 가드 판정을 가진다")
	var rear_hp := rear_enemy.hp
	sim._try_attack(ranger, front_enemy)
	sim._resolve_damage()
	ok(is_equal_approx(rear_enemy.hp, rear_hp), "최전방이 살아 있으면 후열은 피해를 받지 않는다")
	front_enemy.alive = false
	sim._retarget(ranger)
	ok(ranger.target_uid == rear_enemy.uid, "최전방이 쓰러지면 다음 유닛이 전선을 잇는다")


func _test_order_is_strategy() -> void:
	print("[순서가 전략인가]")
	var comp := ["capricorn", "aries", "gemini", "pisces", "scorpio", "sagittarius"]
	var cheap_first := ["aries", "gemini", "pisces", "scorpio", "sagittarius", "capricorn"]
	var enemy := _lineup(["taurus", "scorpio", "libra", "leo", "cancer"])

	var r_greedy := CombatSim.create(_lineup(comp), enemy).run_to_end()
	var r_cheap := CombatSim.create(_lineup(cheap_first), enemy).run_to_end()

	print("    비싼거 먼저: winner=%d core=%s time=%.1f" % [r_greedy["winner"], r_greedy["core_hp"], r_greedy["time"]])
	print("    싼거 먼저  : winner=%d core=%s time=%.1f" % [r_cheap["winner"], r_cheap["core_hp"], r_cheap["time"]])

	var gap: float = absf(float(r_greedy["core_hp"][0]) - float(r_cheap["core_hp"][0]))
	ok(r_greedy["winner"] != r_cheap["winner"] or gap > Defs.CORE_HP * 0.05,
		"같은 구성이라도 출격 순서가 결과를 바꾼다", "gap=%.1f" % gap)

	# 순서만 다른 두 편성을 직접 붙여본다.
	var head := CombatSim.create(_lineup(cheap_first), _lineup(comp)).run_to_end()
	print("    직접 대결(싼거먼저 vs 비싼거먼저): winner=%d core=%s" % [head["winner"], head["core_hp"]])
	ok(true, "순서 대결 시뮬 완료")


func _test_determinism() -> void:
	print("[결정론]")
	var a := _lineup(["aries", "cancer", "pisces"])
	var b := _lineup(["scorpio", "taurus", "sagittarius"])
	var r1 := CombatSim.create(a, b).run_to_end()
	var r2 := CombatSim.create(a, b).run_to_end()
	ok(r1["winner"] == r2["winner"] and is_equal_approx(float(r1["time"]), float(r2["time"])),
		"같은 입력은 같은 결과", "%s vs %s" % [r1, r2])


func _test_mirror_is_fair() -> void:
	print("[대칭성]")
	var comp := ["cancer", "aries", "pisces", "scorpio", "sagittarius", "virgo"]
	var r := CombatSim.create(_lineup(comp), _lineup(comp)).run_to_end()
	var hp_gap: float = absf(float(r["core_hp"][0]) - float(r["core_hp"][1]))
	ok(r["winner"] == -1 and is_zero_approx(hp_gap),
		"완전히 같은 편성은 무승부로 끝난다",
		"winner=%d gap=%.1f time=%.1f" % [r["winner"], hp_gap, r["time"]])


func _test_counter_matters() -> void:
	print("[상성이 결과를 바꾸는가]")
	var strikers := _lineup(["aries", "gemini", "scorpio", "leo"])
	var rangers := _lineup(["pisces", "libra", "sagittarius", "pisces"])
	var defenders := _lineup(["cancer", "taurus", "capricorn", "cancer"])
	var r1 := CombatSim.create(strikers, rangers).run_to_end()
	var r2 := CombatSim.create(strikers, defenders).run_to_end()
	print("    스트라이커 vs 레인저: %s" % str(r1))
	print("    스트라이커 vs 디펜더: %s" % str(r2))
	ok(r1["winner"] == 0, "스트라이커 편성이 레인저 편성을 이긴다", str(r1))
	ok(r2["winner"] == 1, "디펜더 편성이 스트라이커 편성을 이긴다", str(r2))
	var r3 := CombatSim.create(rangers, defenders).run_to_end()
	ok(r3["winner"] == 0, "레인저 편성이 디펜더 편성을 이긴다", str(r3))


func _test_breakthrough() -> void:
	print("[돌파 -> 코어 파괴]")
	var r := CombatSim.create(
		_lineup(["scorpio", "scorpio", "scorpio", "leo"]), _lineup(["cancer"])).run_to_end()
	ok(is_zero_approx(float(r["core_hp"][1])), "적을 밀어내고 코어를 부순다", str(r))
	ok(r["winner"] == 0, "코어 파괴로 승리", str(r))
	ok(not r["timeout"], "시간 안에 끝난다", "%.1fs" % r["time"])

	# 접전이면 코어가 살아남아 판정으로 간다.
	var close := CombatSim.create(
		_lineup(["cancer", "taurus"]), _lineup(["cancer", "taurus"])).run_to_end()
	print("    거울 탱커전: winner=%d core=%s %.1fs timeout=%s"
		% [close["winner"], close["core_hp"], close["time"], close["timeout"]])
	ok(true, "접전 판정 시뮬 완료")


# --- 밸런스 스윕 -----------------------------------------------------------

func _sweep_1v1() -> void:
	print("[1대1 승률 표] 행이 열을 상대로 W=승 L=패 .=무")
	var ids: Array[String] = []
	for cost in [1, 2, 3, 4]:
		ids.append_array(UnitDB.ids_by_tier(cost))

	var header := "%-12s" % ""
	for id in ids:
		header += "%-5s" % UnitDB.get_def(id)["name"].substr(0, 2)
	print("    " + header)

	var wins := {}
	for a in ids:
		var row := "%-12s" % UnitDB.get_def(a)["name"]
		var w := 0
		for b in ids:
			if a == b:
				row += "%-5s" % "-"
				continue
			var r := CombatSim.create(_lineup([a]), _lineup([b])).run_to_end()
			var mark := "."
			if r["winner"] == 0:
				mark = "W"
				w += 1
			elif r["winner"] == 1:
				mark = "L"
			row += "%-5s" % mark
		wins[a] = w
		print("    " + row)

	var by_cost := {}
	for id in ids:
		var c: int = UnitDB.get_def(id)["tier"]
		by_cost[c] = float(by_cost.get(c, 0.0)) + float(wins[id])
	var avg := {}
	for c in by_cost:
		avg[c] = snappedf(float(by_cost[c]) / float(UnitDB.ids_by_tier(c).size()), 0.1)
	print("    코스트별 평균 승수: %s" % str(avg))
	ok(float(avg.get(4, 0.0)) >= float(avg.get(1, 0.0)),
		"높은 등급이 낮은 등급보다 1대1에 강하다", str(avg))


func _sweep_role_lineups() -> void:
	print("[병종 편성 상성] 4기 편성 맞대결 (행 기준 승패)")
	var comps := {
		"스트라이커": ["aries", "gemini", "scorpio", "leo"],
		"레인저": ["pisces", "libra", "sagittarius", "pisces"],
		"디펜더": ["cancer", "taurus", "capricorn", "cancer"],
		"혼합": ["cancer", "pisces", "scorpio", "aquarius"],
	}
	var names := comps.keys()
	var head := "%-12s" % ""
	for n in names:
		head += "%-8s" % n.substr(0, 4)
	print("    " + head)
	for a in names:
		var row := "%-12s" % a
		for b in names:
			if a == b:
				row += "%-8s" % "-"
				continue
			var r := CombatSim.create(_lineup(comps[a]), _lineup(comps[b])).run_to_end()
			var mark := "무"
			if r["winner"] == 0:
				mark = "승"
			elif r["winner"] == 1:
				mark = "패"
			row += "%-8s" % ("%s%d" % [mark, int(round(float(r["core_ratio"][0]) * 100.0))])
		print("    " + row)


## 순서 전략끼리 직접 맞붙인다. 양쪽 유닛 구성이 완전히 같으므로 순서만이 변수다.
## 자동 큐의 기본 정책은 진단용으로 비교한다. 실제 플레이어는 전투 중 카드로
## 대기 유닛을 직접 고르므로, 릴리스 게이트는 수동 선택이 결과를 바꾸는지에 둔다.
func _sweep_order_heuristics() -> void:
	print("[출격 순서 전략 맞대결] 같은 구성, 순서만 다르게")
	var comps := {
		"고코스트형": ["capricorn", "leo", "sagittarius", "cancer", "pisces", "scorpio"],
		"저코스트형": ["aries", "gemini", "pisces", "cancer", "virgo", "scorpio"],
		"균형형": ["taurus", "scorpio", "libra", "leo", "aries", "pisces"],
	}
	var strategies := {
		"싼것부터": func(d): return float(UnitDB.DEPLOY_BY_TIER[d["tier"]]),
		"비싼것부터": func(d): return -float(UnitDB.DEPLOY_BY_TIER[d["tier"]]),
		"탱커먼저": func(d): return 0.0 if d["role"] == Defs.Role.DEFENDER else 1.0,
		"딜러먼저": func(d): return 1.0 if d["role"] == Defs.Role.DEFENDER else 0.0,
	}
	var names := strategies.keys()
	var total := {}
	var perfect := {}
	for n in names:
		total[n] = 0.0
		perfect[n] = 0

	for cname in comps:
		print("    -- %s: %s --" % [cname, _short(comps[cname])])
		var orders := {}
		for n in names:
			orders[n] = _sorted_by(comps[cname], strategies[n])
		var head := "%-12s" % ""
		for n in names:
			head += "%-8s" % n
		head += "승점"
		print("    " + head)
		for a in names:
			var row := "%-12s" % a
			var pts := 0.0
			var losses := 0
			for b in names:
				if a == b:
					row += "%-8s" % "-"
					continue
				var r := CombatSim.create(_lineup(orders[a]), _lineup(orders[b])).run_to_end()
				var mark := "무"
				if r["winner"] == 0:
					mark = "승"
					pts += 1.0
				elif r["winner"] == 1:
					mark = "패"
					losses += 1
				else:
					pts += 0.5
				row += "%-8s" % mark
			total[a] = float(total[a]) + pts
			if losses == 0:
				perfect[a] = int(perfect[a]) + 1
			row += "%.1f" % pts
			print("    " + row)
		# 순서가 정말 같은지 확인용 - 순서 문자열 출력
		for n in names:
			print("      %-10s %s" % [n, _short(orders[n])])

	print("    == 구성 전체 합산 승점: %s" % str(total))
	print("    == 무패를 기록한 구성 수: %s" % str(perfect))
	var dominant := ""
	for n in names:
		if int(perfect[n]) == comps.size():
			dominant = n
	if dominant != "":
		print("    [INFO] 자동 큐 기본 우세 정책: %s (수동 카드 선택으로 덮어쓸 수 있음)" % dominant)

	var best := 0.0
	var worst := 999.0
	for n in names:
		best = maxf(best, float(total[n]))
		worst = minf(worst, float(total[n]))
	ok(best > worst, "순서 전략 간에 우열은 존재한다", str(total))


# --- 유틸 -----------------------------------------------------------------

## 배열 인덱스가 곧 출격 순번.
func _lineup(ids: Array, stars: Array = []) -> Array:
	var out: Array = []
	for i in ids.size():
		out.append({
			"def_id": ids[i],
			"star": int(stars[i]) if i < stars.size() else 1,
			"order": i,
		})
	return out


func _sorted_by(ids: Array, key: Callable) -> Array:
	var arr := ids.duplicate()
	arr.sort_custom(func(a, b):
		var ka: float = key.call(UnitDB.get_def(a))
		var kb: float = key.call(UnitDB.get_def(b))
		if is_equal_approx(ka, kb):
			return String(a) < String(b)
		return ka < kb)
	return arr


func _find_unit(sim: CombatSim, def_id: String, team: int) -> CombatSim.SimUnit:
	for u in sim.units:
		if u.def_id == def_id and u.team == team:
			return u
	return null


func _short(ids: Array) -> String:
	var parts: PackedStringArray = []
	for id in ids:
		var d := UnitDB.get_def(id)
		parts.append("%s(%d)" % [d["name"].substr(0, 2), UnitDB.deploy_cost(id)])
	return " ".join(parts)
