class_name CombatSim
extends RefCounted

## 노드에 의존하지 않는 순수 전투 시뮬레이터.
## 단일 라인 + 코스트 출격. 플레이어가 준비 페이즈에 정한 출격 큐 순서대로,
## 코스트가 차는 대로 유닛이 자동 출격한다. 전투 중 조작은 없다.
##
## 헤드리스 테스트는 run_to_end()를 쓰고, 시각화 씬은 _process에서 step()을 호출한다.

class SimUnit extends RefCounted:
	var uid: int
	var def_id: String
	var display_name: String
	var team: int
	var order: int                ## 출격 큐에서의 순번
	var star: int
	var role: int
	var deploy_cost: float

	## 자기 코어로부터의 전진 거리. 양 팀이 똑같이 0에서 증가하므로
	## 부동소수점 연산까지 대칭이 보장된다. 화면 x는 snapshot()에서 환산한다.
	var pos: float
	var hp: float
	var max_hp: float
	var atk: float
	var armor: float
	var atk_speed: float
	var atk_range: float
	var move_speed: float
	var ability: Dictionary

	var cd: float = 0.0
	var target_uid: int = -1
	var deployed: bool = false
	var alive: bool = true        ## 출격 전에도 true. 살아있는 필드 유닛은 is_active().
	var deployed_at := 0.0
	var shield := 0.0
	var attack_count := 0
	var hit_count := 0
	var kill_stacks := 0

	func is_active() -> bool:
		return deployed and alive

	## 화면 좌표. 팀0은 왼쪽에서 오른쪽으로, 팀1은 그 반대로 전진한다.
	func screen_x() -> float:
		return pos if team == 0 else Defs.FIELD_LEN - pos

	func snapshot() -> Dictionary:
		return {
			"uid": uid, "def_id": def_id, "name": display_name, "team": team,
			"order": order, "pos": pos, "x": screen_x(), "hp": hp, "max_hp": max_hp,
			"shield": shield, "deployed": deployed, "alive": alive, "star": star,
			"role": role, "ability_name": ability.get("name", ""), "target_uid": target_uid,
		}


var units: Array[SimUnit] = []
var core_hp := [Defs.CORE_HP, Defs.CORE_HP]
var cost := [Defs.START_COST, Defs.START_COST]
var time := 0.0
var finished := false
var winner := -1               ## 0/1, 무승부는 -1
var traits_by_team: Array = [null, null]

var _by_uid := {}
var _queue: Array = [[], []]   ## 팀별 미출격 유닛(출격 순서대로)
var _next_uid := 0
var _trait_regen := [0.0, 0.0]
var _regen := [Defs.COST_REGEN, Defs.COST_REGEN]
## 틱 내 피해는 모았다가 끝에 한 번에 적용한다. 그래야 배열 순서가 승패를 가르지 않고
## 상호 확살이 동시 사망으로 처리된다.
var _pending: Dictionary = {}
var _events: Array = []        ## 시각화용. consume_events()로 비우며 가져간다.


## placements: [{def_id, star, order}]
## level은 코스트 충전 속도를 결정한다. 정원(=레벨)이 커지면 충전도 빨라져야
## 큐 뒤쪽 유닛이 전투 시간 안에 나올 수 있다.
static func create(team0: Array, team1: Array,
		level0: int = Defs.LEVEL_BASE, level1: int = Defs.LEVEL_BASE) -> CombatSim:
	var sim := CombatSim.new()
	sim._regen = [Defs.cost_regen_for(level0), Defs.cost_regen_for(level1)]
	sim._build_team(0, team0)
	sim._build_team(1, team1)
	return sim


func _build_team(team: int, placements: Array) -> void:
	var sorted := placements.duplicate()
	sorted.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))

	var tr := Traits.evaluate(sorted)
	traits_by_team[team] = tr
	_trait_regen[team] = tr.team_regen
	for i in sorted.size():
		var u := _make_unit(team, sorted[i], i, tr)
		units.append(u)
		_by_uid[u.uid] = u
		_queue[team].append(u)


func cast_command_strike(damage: float = 48.0) -> bool:
	## 전투 중 한 번 개입할 수 있는 등불함 지휘기.
	if finished:
		return false
	var hit := false
	for unit in units:
		if not unit.is_active() or unit.team != 1:
			continue
		unit.hp = maxf(0.0, unit.hp - damage)
		_events.append({"t":"command_hit", "to":unit.uid, "dmg":damage})
		hit = true
		if unit.hp <= 0.0:
			unit.alive = false
			_events.append({"t":"death", "uid":unit.uid})
	_check_end()
	return hit


func _make_unit(team: int, p: Dictionary, order: int, tr: Traits) -> SimUnit:
	var def_id: String = p["def_id"]
	var d := UnitDB.get_def(def_id)
	var star: int = int(p.get("star", 1))
	var sm := UnitDB.star_mult(star)
	var mods := tr.mods_for(def_id)

	var u := SimUnit.new()
	u.uid = _next_uid
	_next_uid += 1
	u.def_id = def_id
	u.display_name = d["name"]
	u.team = team
	u.order = order
	u.star = star
	u.role = d["role"]
	u.deploy_cost = float(UnitDB.deploy_cost(def_id))

	u.max_hp = float(d["hp"]) * sm * float(mods["hp_mult"])
	u.hp = u.max_hp
	u.atk = float(d["atk"]) * sm * float(mods["atk_mult"])
	u.armor = float(d["armor"]) + float(mods["armor_add"])
	u.atk_speed = float(d["atk_speed"]) * float(mods["as_mult"])
	u.atk_range = float(d["atk_range"])
	u.move_speed = float(d["move_speed"])
	u.ability = d["ability"].duplicate(true)
	u.pos = Defs.SPAWN_OFFSET
	return u


# --- 시뮬레이션 -----------------------------------------------------------

func run_to_end() -> Dictionary:
	while not finished:
		step(Defs.TICK)
	return result()


func step(dt: float) -> void:
	if finished:
		return
	time += dt
	_tick_cost(dt)
	_tick_deploy()
	_apply_regen(dt)
	# 모든 유닛이 "같은 시점의 전장"을 보고 판단해야 한다. 타겟을 먼저 다 정하고,
	# 그다음에 이동과 피해를 일괄 적용한다. 이 분리가 없으면 먼저 처리되는 팀이
	# 갱신 전 위치를 보게 되어 양 팀이 다른 적을 조준한다.
	for u in units:
		if u.is_active():
			_retarget(u)
	var moves := {}
	for u in units:
		if u.is_active():
			_act(u, dt, moves)
	for uid in moves:
		(_by_uid[uid] as SimUnit).pos = moves[uid]
	_resolve_damage()
	_check_end()


func _tick_cost(dt: float) -> void:
	for team in 2:
		cost[team] = minf(Defs.MAX_COST, cost[team] + float(_regen[team]) * dt)


## 큐 맨 앞 유닛의 코스트가 차면 출격. 앞이 비싸면 그 자리에서 막힌다 —
## 그 막힘을 감수하고 순서를 짜는 것이 이 게임의 핵심 판단이다.
func _tick_deploy() -> void:
	for team in 2:
		var q: Array = _queue[team]
		while not q.is_empty():
			var u: SimUnit = q[0]
			if cost[team] < u.deploy_cost:
				break
			cost[team] -= u.deploy_cost
			q.pop_front()
			u.deployed = true
			u.deployed_at = time
			u.pos = Defs.SPAWN_OFFSET
			# 첫 공격이 동시에 터지지 않도록 위상을 분산시킨다.
			# uid가 아니라 출격 순번으로 계산해야 양 팀이 대칭을 유지한다.
			u.cd = float(u.order % 7) * 0.03
			var shield_ratio := float(u.ability.get("deploy_shield_ratio", 0.0))
			if shield_ratio > 0.0:
				u.shield = u.max_hp * shield_ratio
				_emit_ability(u)
			var refund := float(u.ability.get("deploy_cost_refund", 0.0))
			if refund > 0.0:
				cost[team] = minf(Defs.MAX_COST, cost[team] + refund)
				_emit_ability(u)
			if u.ability.has("deploy_haste"):
				_emit_ability(u)
			_events.append({"t": "deploy", "uid": u.uid, "team": team, "time": time})


func _apply_regen(dt: float) -> void:
	for team in 2:
		var ability_rate := 0.0
		for provider in units:
			if provider.is_active() and provider.team == team:
				ability_rate = maxf(ability_rate,
					float(provider.ability.get("active_team_regen", 0.0)))
		# 원소 시너지와 고유 능력은 서로 다른 편성 보상이므로 합산하되,
		# 같은 고유 능력을 여러 장 넣은 값은 위에서 가장 높은 하나만 쓴다.
		var rate: float = _trait_regen[team] + ability_rate
		if rate <= 0.0:
			continue
		for u in units:
			if u.is_active() and u.team == team and u.hp < u.max_hp:
				u.hp = minf(u.max_hp, u.hp + u.max_hp * rate * dt)


func _emit_ability(u: SimUnit) -> void:
	_events.append({
		"t": "ability", "uid": u.uid, "team": u.team,
		"name": u.ability.get("name", ""), "time": time,
	})


func _retarget(u: SimUnit) -> void:
	var t: SimUnit = _by_uid.get(u.target_uid) as SimUnit
	if t == null or not t.is_active():
		t = _find_target(u)
		u.target_uid = t.uid if t != null else -1


func _act(u: SimUnit, dt: float, moves: Dictionary) -> void:
	var haste := _haste_mult(u)
	u.cd = maxf(0.0, u.cd - dt * haste)

	var target: SimUnit = _by_uid.get(u.target_uid) as SimUnit
	if target != null:
		if _gap(u, target) <= u.atk_range:
			_try_attack(u, target)
		else:
			moves[u.uid] = _advanced_pos(u, dt)
		return

	# 앞이 비었다. 적 코어로 전진해 때린다.
	if Defs.FIELD_LEN - u.pos <= u.atk_range:
		_try_hit_core(u)
	else:
		moves[u.uid] = _advanced_pos(u, dt)


## 마주 보고 전진하는 두 유닛 사이의 남은 거리.
func _gap(a: SimUnit, b: SimUnit) -> float:
	return Defs.FIELD_LEN - a.pos - b.pos


func _advanced_pos(u: SimUnit, dt: float) -> float:
	return minf(u.pos + u.move_speed * _haste_mult(u) * dt, Defs.FIELD_LEN)


func _haste_mult(u: SimUnit) -> float:
	var duration := float(u.ability.get("duration", 0.0))
	if duration > 0.0 and time - u.deployed_at <= duration:
		return float(u.ability.get("deploy_haste", 1.0))
	return 1.0


## 교착을 반드시 푼다. 일정 시간이 지나면 모든 피해가 점점 증폭된다.
func damage_rampup() -> float:
	return 1.0 + maxf(0.0, time - Defs.RAMPUP_START) * Defs.RAMPUP_PER_SEC


func _try_attack(u: SimUnit, target: SimUnit) -> void:
	if u.cd > 0.0:
		return
	u.cd = 1.0 / maxf(u.atk_speed, 0.05)
	u.attack_count += 1

	var effective_armor := target.armor * (1.0 - float(u.ability.get("armor_pierce", 0.0)))
	var dmg: float = u.atk * (1.0 + float(u.kill_stacks) \
		* float(u.ability.get("kill_atk_mult", 0.0)))
	dmg *= Defs.counter_mult(u.role, target.role) * Defs.armor_mult(effective_armor)
	dmg *= damage_rampup()

	var every_n := int(u.ability.get("every_n_attack", 0))
	if every_n > 0 and u.attack_count % every_n == 0:
		dmg *= 1.0 + float(u.ability.get("bonus_damage", 0.0))
		_emit_ability(u)
	var healthier_bonus := float(u.ability.get("healthier_target_bonus", 0.0))
	if healthier_bonus > 0.0 and target.hp / target.max_hp > u.hp / u.max_hp:
		dmg *= 1.0 + healthier_bonus
	var threshold := float(u.ability.get("execute_threshold", 0.0))
	if threshold > 0.0 and target.hp / target.max_hp <= threshold:
		dmg *= 1.0 + float(u.ability.get("execute_bonus", 0.0))

	if not _pending.has(target.uid):
		_pending[target.uid] = []
	_pending[target.uid].append({"from": u.uid, "dmg": dmg})
	_events.append({"t": "hit", "from": u.uid, "to": target.uid, "dmg": dmg, "time": time})


func _resolve_damage() -> void:
	var killed_by := {}
	for uid in _pending:
		var t: SimUnit = _by_uid[uid]
		if not t.alive:
			continue
		var contributors := {}
		for e in _pending[uid]:
			var from_uid: int = int(e["from"])
			contributors[from_uid] = true
			var dmg := _defend_hit(t, float(e["dmg"]))
			if dmg <= 0.0:
				continue
			t.hp -= dmg
			if t.hp <= 0.0:
				t.hp = 0.0
				t.alive = false
				killed_by[uid] = contributors.keys()
				_events.append({"t": "death", "uid": uid, "time": time})
				break

	# 처치 보정은 틱의 모든 생존 판정이 끝난 뒤 적용한다. 이번 틱에 동시 공격한
	# 유닛은 같은 시점의 스탯을 사용하고, 다음 틱부터 강화된다.
	for victim_uid in killed_by:
		for from_uid in killed_by[victim_uid]:
			var attacker: SimUnit = _by_uid[int(from_uid)]
			var max_stacks := int(attacker.ability.get("max_stacks", 0))
			if max_stacks > 0 and attacker.kill_stacks < max_stacks:
				attacker.kill_stacks += 1
				_emit_ability(attacker)
	_pending.clear()


func _defend_hit(target: SimUnit, raw_damage: float) -> float:
	target.hit_count += 1
	var dodge_n := int(target.ability.get("dodge_every_n_hit", 0))
	if dodge_n > 0 and target.hit_count % dodge_n == 0:
		_emit_ability(target)
		return 0.0

	var dmg := raw_damage
	var cap_ratio := float(target.ability.get("damage_cap_ratio", 0.0))
	if cap_ratio > 0.0:
		dmg = minf(dmg, target.max_hp * cap_ratio)
	if target.shield > 0.0:
		var absorbed := minf(target.shield, dmg)
		target.shield -= absorbed
		dmg -= absorbed
	return dmg


func _try_hit_core(u: SimUnit) -> void:
	if u.cd > 0.0:
		return
	u.cd = 1.0 / maxf(u.atk_speed, 0.05)
	var enemy := 1 - u.team
	var dmg: float = u.atk * (1.0 + float(u.kill_stacks) \
		* float(u.ability.get("kill_atk_mult", 0.0))) * damage_rampup()
	dmg *= 1.0 - _active_core_reduction(enemy)
	core_hp[enemy] = maxf(0.0, core_hp[enemy] - dmg)
	_events.append({"t": "core", "from": u.uid, "team": enemy, "dmg": dmg, "time": time})


func _active_core_reduction(team: int) -> float:
	var reduction := 0.0
	for u in units:
		if u.is_active() and u.team == team:
			reduction = maxf(reduction, float(u.ability.get("active_core_reduction", 0.0)))
	return clampf(reduction, 0.0, 0.9)


## 단일 라인이므로 가장 가까운 적을 친다 — 즉 가장 많이 전진해 온 적.
## 앞에 선 유닛이 자연히 몸으로 막는다.
func _find_target(u: SimUnit) -> SimUnit:
	var best: SimUnit = null
	var best_pos := -INF
	for o in units:
		if not o.is_active() or o.team == u.team:
			continue
		if o.pos > best_pos:
			best_pos = o.pos
			best = o
	return best


func _check_end() -> void:
	var active := [0, 0]
	var pending := [_queue[0].size(), _queue[1].size()]
	for u in units:
		if u.is_active():
			active[u.team] += 1

	if core_hp[0] <= 0.0 or core_hp[1] <= 0.0:
		finished = true
		if core_hp[0] <= 0.0 and core_hp[1] <= 0.0:
			winner = -1
		else:
			winner = 1 if core_hp[0] <= 0.0 else 0
		return

	# 필드도 비고 출격 대기도 없으면 그 팀은 소진됐다. 하지만 즉시 패배는 아니다 —
	# 남은 쪽이 무방비가 된 코어까지 걸어가 부숴야 이긴다. 그래야 코어와 돌파가 의미를 갖는다.
	var spent := [active[0] == 0 and pending[0] == 0, active[1] == 0 and pending[1] == 0]
	if spent[0] and spent[1]:
		finished = true
		winner = _judge_by_core()
		return

	if time >= Defs.MAX_BATTLE_TIME:
		finished = true
		winner = _judge_by_core()


## 결판이 안 났을 때는 코어를 더 많이 지킨 쪽이 이긴다.
func _judge_by_core() -> int:
	if is_equal_approx(core_hp[0], core_hp[1]):
		return -1
	return 0 if core_hp[0] > core_hp[1] else 1


## 코어를 얼마나 지켰는가. 라운드 피해 계산에 쓴다.
func core_ratio(team: int) -> float:
	return core_hp[team] / Defs.CORE_HP


func result() -> Dictionary:
	var active := [0, 0]
	for u in units:
		if u.is_active():
			active[u.team] += 1
	return {
		"winner": winner,
		"time": time,
		"core_hp": core_hp.duplicate(),
		"survivors": active,
		"undeployed": [_queue[0].size(), _queue[1].size()],
		"core_ratio": [core_ratio(0), core_ratio(1)],
		"timeout": time >= Defs.MAX_BATTLE_TIME,
	}


func snapshot() -> Array:
	var out: Array = []
	for u in units:
		var state := u.snapshot()
		state["engaged"] = _engaged_for_presentation(u)
		out.append(state)
	return out


func _engaged_for_presentation(u: SimUnit) -> bool:
	if not u.is_active():
		return false
	var target := _by_uid.get(u.target_uid) as SimUnit
	if target != null and target.is_active():
		return _gap(u, target) <= u.atk_range
	return Defs.FIELD_LEN - u.pos <= u.atk_range


func consume_events() -> Array:
	var e := _events
	_events = []
	return e
