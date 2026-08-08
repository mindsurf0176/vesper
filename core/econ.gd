class_name Econ
extends RefCounted

## 상점, 골드, 합성, 레벨. 전투와 완전히 분리되어 있다.

const SHOP_SLOTS := 5
const REROLL_COST := 2
const XP_COST := 4
const XP_PER_BUY := 4
const BASE_INCOME := 5
## 이자 구간이 수입보다 크면 저축이 원리적으로 불가능하다. 수입 5에 10골드 구간이면
## 두 라운드를 통째로 굶어야 이자 1을 받는다 — 그러면 아무도 저축하지 않는다.
const INTEREST_STEP := 5
const MAX_INTEREST := 4
const START_GOLD := 3
const START_HP := 100
const BENCH_SIZE := 9

## 라운드 패배 피해 = (기본 + 잃은 코어 비율 + 살아남은 적 유닛 수) x 라운드 계수.
## 코어를 얼마나 지켰는지가 피해량을 좌우한다 — 접전 패배와 완패의 값이 달라야 한다.
const LOSS_BASE_DAMAGE := 2
const LOSS_CORE_SCALE := 8
const LOSS_PER_SURVIVOR := 1

## 초반 패배가 후반 패배와 같은 값이면 "초반을 버리고 경제를 굴린다"는 선택지가
## 아예 성립하지 않는다. 연패를 감당할 수 있어야 저축이 전략이 된다.
const DAMAGE_SCALE_MIN := 0.4
const DAMAGE_SCALE_MAX := 1.6
const DAMAGE_SCALE_PER_ROUND := 0.06

static func round_damage_scale(round_no: int) -> float:
	return clampf(DAMAGE_SCALE_MIN + float(round_no) * DAMAGE_SCALE_PER_ROUND,
		DAMAGE_SCALE_MIN, DAMAGE_SCALE_MAX)


## 모든 플레이어가 공유하는 유닛 풀. 인기 유닛은 마른다.
class Pool extends RefCounted:
	var remaining := {}

	func _init() -> void:
		for cost in UnitDB.POOL_SIZE:
			for id in UnitDB.ids_by_tier(cost):
				remaining[id] = UnitDB.POOL_SIZE[cost]

	func take(def_id: String) -> bool:
		if int(remaining.get(def_id, 0)) <= 0:
			return false
		remaining[def_id] -= 1
		return true

	func give_back(def_id: String, count: int) -> void:
		remaining[def_id] = int(remaining.get(def_id, 0)) + count

	## 플레이어 레벨의 확률 표에 따라 코스트를 뽑고, 그 코스트에서 남은 유닛을 뽑는다.
	func roll_one(level: int, rng: RandomNumberGenerator) -> String:
		var odds: Array = UnitDB.SHOP_ODDS[clampi(level, UnitDB.MIN_LEVEL, UnitDB.MAX_LEVEL)]
		var order := _cost_order(odds, rng)
		for cost in order:
			var candidates: Array[String] = []
			var weights: Array[int] = []
			for id in UnitDB.ids_by_tier(cost):
				var n := int(remaining.get(id, 0))
				if n > 0:
					candidates.append(id)
					weights.append(n)
			if candidates.is_empty():
				continue
			return _weighted_pick(candidates, weights, rng)
		return ""

	## 확률대로 코스트 하나를 고르되, 그 코스트가 말랐을 때를 위해 나머지 순서도 돌려준다.
	func _cost_order(odds: Array, rng: RandomNumberGenerator) -> Array[int]:
		var pool: Array[int] = []
		var w: Array[int] = []
		for i in odds.size():
			if int(odds[i]) > 0:
				pool.append(i + 1)
				w.append(int(odds[i]))
		var order: Array[int] = []
		while not pool.is_empty():
			var total := 0
			for x in w:
				total += x
			var r := rng.randi_range(1, total)
			var acc := 0
			var idx := 0
			for i in w.size():
				acc += w[i]
				if r <= acc:
					idx = i
					break
			order.append(pool[idx])
			pool.remove_at(idx)
			w.remove_at(idx)
		# 확률 0인 코스트도 최후의 보루로 뒤에 붙인다.
		for cost in [1, 2, 3, 4]:
			if not order.has(cost):
				order.append(cost)
		return order

	func _weighted_pick(items: Array[String], weights: Array[int], rng: RandomNumberGenerator) -> String:
		var total := 0
		for x in weights:
			total += x
		var r := rng.randi_range(1, total)
		var acc := 0
		for i in items.size():
			acc += weights[i]
			if r <= acc:
				return items[i]
		return items[items.size() - 1]


## 한 플레이어의 보드 상태.
class Player extends RefCounted:
	var gold := START_GOLD
	var hp := START_HP
	var level := UnitDB.MIN_LEVEL
	var xp := 0
	var streak := 0                ## 양수=연승, 음수=연패
	var shop: Array[String] = []
	var shop_locked := false
	## roster 항목: {def_id, star, order} — order<0 이면 벤치(출격 큐 밖).
	var roster: Array = []

	## 출격 큐에 올라간 유닛을 순서대로.
	func queued_units() -> Array:
		var q := roster.filter(func(u): return int(u["order"]) >= 0)
		q.sort_custom(func(a, b): return int(a["order"]) < int(b["order"]))
		return q

	func bench_units() -> Array:
		return roster.filter(func(u): return int(u["order"]) < 0)

	func queue_count() -> int:
		return queued_units().size()

	## 출격 큐를 다 소화하는 데 필요한 총 코스트. 순서 설계의 기본 지표.
	func total_deploy_cost() -> int:
		var sum := 0
		for u in queued_units():
			sum += UnitDB.deploy_cost(u["def_id"])
		return sum

	func is_alive() -> bool:
		return hp > 0


var pool: Pool
var rng := RandomNumberGenerator.new()

## 다인전에서는 모든 참가자가 같은 풀을 공유해야 한다 — 인기 유닛이 서로 마르는 것이
## 오토체스 경제의 핵심이다. shared_pool을 넘기면 그 풀을 함께 쓴다.
func _init(seed_value: int = 0, shared_pool: Pool = null) -> void:
	rng.seed = seed_value
	pool = shared_pool if shared_pool != null else Pool.new()


# --- 상점 ----------------------------------------------------------------

func refresh_shop(p: Player, force: bool = false) -> void:
	if p.shop_locked and not force:
		return
	for id in p.shop:
		if id != "":
			pool.give_back(id, 1)
	p.shop = []
	for i in SHOP_SLOTS:
		var id := pool.roll_one(p.level, rng)
		p.shop.append(id)
		if id != "":
			pool.take(id)


func set_shop_locked(p: Player, locked: bool) -> void:
	p.shop_locked = locked


func reroll(p: Player) -> bool:
	if p.gold < REROLL_COST:
		return false
	p.gold -= REROLL_COST
	refresh_shop(p, true)
	return true


func buy(p: Player, slot: int) -> bool:
	if slot < 0 or slot >= p.shop.size():
		return false
	var def_id: String = p.shop[slot]
	if def_id == "":
		return false
	var cost: int = UnitDB.get_def(def_id)["tier"]
	if p.gold < cost:
		return false
	# 벤치가 꽉 찼는데 즉시 합성도 안 되면 못 산다.
	if p.bench_units().size() >= BENCH_SIZE and not _would_combine(p, def_id):
		return false
	p.gold -= cost
	p.shop[slot] = ""
	p.roster.append({"def_id": def_id, "star": 1, "order": -1})
	_resolve_combines(p)
	return true


func sell(p: Player, roster_index: int) -> bool:
	if roster_index < 0 or roster_index >= p.roster.size():
		return false
	var u: Dictionary = p.roster[roster_index]
	var def_id: String = u["def_id"]
	var star: int = int(u["star"])
	var cost: int = UnitDB.get_def(def_id)["tier"]
	var copies: int = int(pow(3, star - 1))
	p.gold += cost * copies
	pool.give_back(def_id, copies)
	p.roster.remove_at(roster_index)
	return true


func buy_xp(p: Player) -> bool:
	if p.gold < XP_COST or p.level >= UnitDB.MAX_LEVEL:
		return false
	p.gold -= XP_COST
	add_xp(p, XP_PER_BUY)
	return true


func add_xp(p: Player, amount: int) -> void:
	p.xp += amount
	while p.level < UnitDB.MAX_LEVEL and p.xp >= int(UnitDB.XP_TO_NEXT[p.level]):
		p.xp -= int(UnitDB.XP_TO_NEXT[p.level])
		p.level += 1


# --- 합성 ----------------------------------------------------------------

func _would_combine(p: Player, def_id: String) -> bool:
	var n := 0
	for u in p.roster:
		if u["def_id"] == def_id and int(u["star"]) == 1:
			n += 1
	return n >= 2


## 같은 유닛 3개를 상위 ★로 합친다. ★3까지 연쇄한다.
func _resolve_combines(p: Player) -> void:
	var changed := true
	while changed:
		changed = false
		for star in range(1, UnitDB.MAX_STAR):
			var groups := {}
			for i in p.roster.size():
				var u: Dictionary = p.roster[i]
				if int(u["star"]) != star:
					continue
				var key: String = u["def_id"]
				if not groups.has(key):
					groups[key] = []
				groups[key].append(i)
			for def_id in groups:
				var idxs: Array = groups[def_id]
				if idxs.size() < 3:
					continue
				# 큐에 있던 개체가 있으면 그 순번을 승급 유닛이 물려받는다.
				var keep: int = idxs[0]
				for i in idxs:
					if int(p.roster[i]["order"]) >= 0:
						keep = i
						break
				var order: int = int(p.roster[keep]["order"])
				var to_remove: Array = []
				for i in idxs.slice(0, 3):
					to_remove.append(i)
				to_remove.sort()
				to_remove.reverse()
				for i in to_remove:
					p.roster.remove_at(i)
				p.roster.append({"def_id": def_id, "star": star + 1, "order": order})
				_normalize_queue(p)
				changed = true
				break
			if changed:
				break


# --- 출격 큐 --------------------------------------------------------------
## 오토체스의 "배치"에 해당한다. 어디에 놓느냐가 아니라 몇 번째로 내보내느냐.

## 큐의 at_order 자리에 끼워 넣는다. at_order<0 이면 맨 뒤.
func enqueue(p: Player, roster_index: int, at_order: int = -1) -> bool:
	if roster_index < 0 or roster_index >= p.roster.size():
		return false
	var u: Dictionary = p.roster[roster_index]
	if int(u["order"]) >= 0:
		return move(p, roster_index, at_order)
	if p.queue_count() >= p.level:
		return false
	var n := p.queue_count()
	var target: int = n if at_order < 0 else clampi(at_order, 0, n)
	for other in p.roster:
		if other == u:
			continue
		if int(other["order"]) >= target:
			other["order"] = int(other["order"]) + 1
	u["order"] = target
	_normalize_queue(p)
	return true


## 큐 안에서 순서만 바꾼다.
func move(p: Player, roster_index: int, to_order: int) -> bool:
	if roster_index < 0 or roster_index >= p.roster.size():
		return false
	var u: Dictionary = p.roster[roster_index]
	if int(u["order"]) < 0:
		return enqueue(p, roster_index, to_order)
	var q := p.queued_units()
	var target := clampi(to_order, 0, q.size() - 1)
	q.erase(u)
	q.insert(target, u)
	for i in q.size():
		q[i]["order"] = i
	return true


func to_bench(p: Player, roster_index: int) -> bool:
	if roster_index < 0 or roster_index >= p.roster.size():
		return false
	var u: Dictionary = p.roster[roster_index]
	if int(u["order"]) < 0:
		return true
	if p.bench_units().size() >= BENCH_SIZE:
		return false
	u["order"] = -1
	_normalize_queue(p)
	return true


## 이 순서대로면 각 유닛이 몇 초에 나오는지. 준비 페이즈에서 순서를 설계할 때
## 가장 중요한 정보다 — 어디서 코스트가 막혀 공백이 생기는지가 여기서 드러난다.
## 반환: [{def_id, star, at, wait}] — wait는 코스트가 모자라 기다린 시간.
static func deploy_schedule(queued: Array, level: int = Defs.LEVEL_BASE) -> Array:
	var regen := Defs.cost_regen_for(level)
	var t := 0.0
	var c := Defs.START_COST
	var out: Array = []
	for u in queued:
		var need := float(UnitDB.deploy_cost(u["def_id"]))
		var wait := 0.0
		if c < need:
			wait = (need - c) / regen
			t += wait
			c = need
		c -= need
		out.append({
			"def_id": u["def_id"], "star": int(u.get("star", 1)),
			"at": t, "wait": wait,
		})
	return out


## 큐 순번을 0..n-1 로 다시 매긴다.
func _normalize_queue(p: Player) -> void:
	var q := p.queued_units()
	for i in q.size():
		q[i]["order"] = i


# --- 라운드 정산 ----------------------------------------------------------

func interest(gold: int) -> int:
	return mini(gold / INTEREST_STEP, MAX_INTEREST)


func streak_bonus(streak: int) -> int:
	var s := absi(streak)
	if s >= 4:
		return 3
	if s == 3:
		return 2
	if s == 2:
		return 1
	return 0


## 전투 결과를 반영해 골드와 체력을 정산한다.
##   won: 1=승, 0=패, -1=무
##   my_core_ratio: 내 코어가 남은 비율(0.0~1.0)
##   round_no: 라운드가 오를수록 패배 피해가 커진다
func settle(p: Player, won: int, my_core_ratio: float, enemy_survivors: int,
		round_no: int = 10) -> Dictionary:
	if won == 1:
		p.streak = maxi(1, p.streak + 1)
	elif won == 0:
		p.streak = mini(-1, p.streak - 1)

	var damage := 0
	if won == 0:
		var lost := clampf(1.0 - my_core_ratio, 0.0, 1.0)
		var raw := float(LOSS_BASE_DAMAGE) \
			+ lost * float(LOSS_CORE_SCALE) \
			+ float(enemy_survivors * LOSS_PER_SURVIVOR)
		damage = maxi(1, int(round(raw * round_damage_scale(round_no))))
		p.hp = maxi(0, p.hp - damage)

	var tr := Traits.evaluate(p.queued_units())
	var inc := BASE_INCOME
	var itr := interest(p.gold)
	var stk := streak_bonus(p.streak)
	var syn := tr.gold_bonus
	p.gold += inc + itr + stk + syn
	add_xp(p, 2)

	return {
		"damage": damage, "income": inc, "interest": itr,
		"streak_bonus": stk, "synergy_gold": syn, "streak": p.streak,
	}
