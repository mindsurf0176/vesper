class_name AutoPlay
extends RefCounted

## 휴리스틱 자동 플레이어. 준비 페이즈를 사람 대신 운영한다.
## 용도 둘: (1) 게임 루프·난이도 곡선 측정 (2) 나중에 PvP 상대 봇.
##
## 사람만큼 잘 하지는 못한다. "평범한 플레이어" 기준선을 잡는 것이 목적이므로
## 여기서 나온 생존 라운드가 곧 난이도 상한이 아니라 중간값에 가깝다.

## 플레이 성향. 경제 시스템이 실제로 의미가 있는지 재려면 두 성향을 붙여봐야 한다.
##   SPENDER = 골드가 생기면 즉시 전력으로 바꾼다 (이자를 포기)
##   SAVER   = 이자 구간을 지키며 굴린다 (즉시 전력을 포기)
enum Style { SPENDER, SAVER }

## 레벨을 올리기보다 유닛을 모을 라운드. 이 이후로는 레벨을 밀어올린다.
const LEVEL_PUSH_ROUND := 4
## 이 골드 이상 남았을 때만 리롤한다.
const REROLL_FLOOR := 22

## SAVER가 지키려는 잔고. 초반엔 유닛이 급하고, 후반엔 아껴봐야 의미가 없다.
static func bank_target(style: int, round_no: int) -> int:
	if style != Style.SAVER:
		return 0
	if round_no <= 2:
		return 0
	if round_no <= 10:
		return 20      # 이자 2를 지키며 굴린다
	if round_no <= 16:
		return 10
	return 0           # 후반은 전력 투사


static func play_prep(econ: Econ, p: Econ.Player, round_no: int,
		rng: RandomNumberGenerator, style: int = Style.SPENDER) -> void:
	var bank := bank_target(style, round_no)

	# 1) 레벨: 초반 몇 라운드는 유닛에 쓰고, 그 뒤로는 큐 정원을 밀어올린다.
	if round_no >= LEVEL_PUSH_ROUND:
		while p.gold - Econ.XP_COST >= bank and p.level < UnitDB.MAX_LEVEL:
			if not econ.buy_xp(p):
				break

	# 2) 구매: 합성 가능한 것 우선, 그다음 비싼 것. 몇 번 리롤도 시도한다.
	for attempt in 4:
		_buy_pass(econ, p, bank)
		if p.gold - Econ.REROLL_COST < maxi(bank, REROLL_FLOOR) or p.level >= UnitDB.MAX_LEVEL:
			break
		if not econ.reroll(p):
			break

	# 3) 벤치가 넘치면 약한 것을 판다.
	_trim_bench(econ, p)

	# 4) 큐 편성: 강한 유닛으로 정원을 채우고 탱커를 앞에 세운다.
	_rebuild_queue(econ, p)


static func _buy_pass(econ: Econ, p: Econ.Player, bank: int = 0) -> void:
	# 같은 유닛을 이미 들고 있으면 합성 기대값이 있으니 먼저 산다.
	var owned := {}
	for u in p.roster:
		if int(u["star"]) == 1:
			owned[u["def_id"]] = int(owned.get(u["def_id"], 0)) + 1

	# 큐에 빈자리가 있으면 잔고를 깨고서라도 채운다. 빈 자리는 그대로 손실이다 —
	# 저축한다고 정원을 비워두는 것은 저축 전략이 아니라 그냥 방치다.
	var bodies := p.roster.size()
	var need_bodies := bodies < p.level

	var slots: Array = []
	for i in p.shop.size():
		var id: String = p.shop[i]
		if id == "":
			continue
		var d := UnitDB.get_def(id)
		var score := float(d["tier"]) * 10.0
		if int(owned.get(id, 0)) >= 2:
			score += 200.0     # 즉시 ★2
		elif int(owned.get(id, 0)) == 1:
			score += 60.0
		slots.append({"slot": i, "score": score, "cost": int(d["tier"])})
	slots.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))

	for s in slots:
		# 즉시 ★2가 되는 기회와 정원 채우기는 잔고 목표보다 우선한다.
		var urgent := float(s["score"]) >= 200.0 or need_bodies
		var floor_gold: int = 0 if urgent else bank
		if p.gold - int(s["cost"]) < floor_gold:
			continue
		if econ.buy(p, int(s["slot"])):
			bodies += 1
			need_bodies = bodies < p.level


static func _trim_bench(econ: Econ, p: Econ.Player) -> void:
	while p.bench_units().size() > Econ.BENCH_SIZE - 2:
		var bench := p.bench_units()
		var worst: Dictionary = bench[0]
		for u in bench:
			if _power(u) < _power(worst):
				worst = u
		var idx := p.roster.find(worst)
		if idx < 0 or not econ.sell(p, idx):
			break


static func _rebuild_queue(econ: Econ, p: Econ.Player) -> void:
	# 전부 벤치로 내렸다가 다시 짠다. 판이 바뀌었으니 순서도 다시 본다.
	for i in p.roster.size():
		if int(p.roster[i]["order"]) >= 0:
			p.roster[i]["order"] = -1

	var all := p.roster.duplicate()
	all.sort_custom(func(a, b): return _power(a) > _power(b))
	var chosen := all.slice(0, mini(p.level, all.size()))

	# 탱커 먼저, 같은 역할끼리는 싼 것 먼저. 스윕에서 가장 무난했던 순서.
	chosen.sort_custom(func(a, b):
		var da := UnitDB.get_def(a["def_id"])
		var db := UnitDB.get_def(b["def_id"])
		var ka: int = 0 if da["role"] == Defs.Role.DEFENDER else 1
		var kb: int = 0 if db["role"] == Defs.Role.DEFENDER else 1
		if ka != kb:
			return ka < kb
		return UnitDB.deploy_cost(a["def_id"]) < UnitDB.deploy_cost(b["def_id"]))

	# 기운 반환 능력은 첫 방어 별 직후에 불러야 후속 강림을 앞당기면서도
	# 전열이 비지 않는다. 내부 ID가 아니라 효과 키로 판단한다.
	var refund_unit: Dictionary = {}
	for u in chosen:
		if float(UnitDB.ability(u["def_id"]).get("deploy_cost_refund", 0.0)) > 0.0:
			refund_unit = u
			break
	if not refund_unit.is_empty():
		chosen.erase(refund_unit)
		var insert_at := 0
		for i in chosen.size():
			if UnitDB.get_def(chosen[i]["def_id"])["role"] == Defs.Role.DEFENDER:
				insert_at = i + 1
				break
		chosen.insert(insert_at, refund_unit)

	for u in chosen:
		u["order"] = -1
	for i in chosen.size():
		var idx := p.roster.find(chosen[i])
		econ.enqueue(p, idx, i)


## 대략적인 유닛 가치. 상점 코스트와 ★를 함께 본다.
static func _power(u: Dictionary) -> float:
	var d := UnitDB.get_def(u["def_id"])
	var score := float(d["tier"]) * UnitDB.star_mult(int(u["star"])) * 10.0
	var a: Dictionary = d["ability"]
	# 지원 능력은 기본 공격력에 드러나지 않으므로 편성 평가에서만 보정한다.
	if a.has("active_team_regen"):
		score += float(a["active_team_regen"]) * 350.0
	if a.has("deploy_cost_refund"):
		score += float(a["deploy_cost_refund"])
	if a.has("active_core_reduction"):
		score += float(a["active_core_reduction"]) * 15.0
	return score
