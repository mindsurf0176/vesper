class_name CombatSim
extends RefCounted

## 노드에 의존하지 않는 순수 전투 시뮬레이터.
## 단일 라인 + 코스트 출격. 적은 큐 순서대로 자동 출격하고,
## 플레이어는 전투 중 카드로 직접 출격 타이밍을 선택한다.
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
	var relic_opening_attacks := 0
	var relic_opening_atk_mult := 0.0
	var relic_armor_pierce_add := 0.0
	var relic_low_hp_atk_mult := 0.0
	var relic_early_atk_mult := 0.0
	var relic_damage_taken_mult := 1.0
	var relic_core_damage_mult := 1.0
	var relic_shielded := false
	var relic_early_announced := false
	var relic_low_hp_announced := false

	var cd: float = 0.0
	var target_uid: int = -1
	var deployed: bool = false
	var alive: bool = true        ## 출격 전에도 true. 살아있는 필드 유닛은 is_active().
	var deployed_at := 0.0
	var recovery_left := 0.0
	var retreat_count := 0
	var shield := 0.0
	var attack_count := 0
	var hit_count := 0
	var kill_stacks := 0
	var combo_atk_mult := 1.0
	var combo_attacks_left := 0

	func is_active() -> bool:
		return deployed and alive

	func is_recovering() -> bool:
		return alive and not deployed and recovery_left > 0.0

	## 화면 좌표. 팀0은 왼쪽에서 오른쪽으로, 팀1은 그 반대로 전진한다.
	func screen_x() -> float:
		return pos if team == 0 else Defs.FIELD_LEN - pos

	func snapshot() -> Dictionary:
		return {
			"uid": uid, "def_id": def_id, "name": display_name, "team": team,
			"order": order, "pos": pos, "x": screen_x(), "hp": hp, "max_hp": max_hp,
			"shield": shield, "deployed": deployed, "alive": alive, "star": star,
			"recovering": is_recovering(), "recovery_left": recovery_left,
			"retreat_count": retreat_count,
			"role": role, "ability_name": ability.get("name", ""), "target_uid": target_uid,
		}


var units: Array[SimUnit] = []
var core_hp := [Defs.CORE_HP, Defs.CORE_HP]
var cost := [Defs.START_COST, Defs.START_COST]
var tactical_charges := [2, 0] ## 플레이어가 전투 중 쓸 수 있는 전술 명령 횟수.
var time := 0.0
var finished := false
var winner := -1               ## 0/1, 무승부는 -1
var traits_by_team: Array = [null, null]
var manual_control: Array[bool] = [false, false]

var _by_uid := {}
var _queue: Array = [[], []]   ## 팀별 미출격 유닛(출격 순서대로)
var _next_uid := 0
var _trait_regen := [0.0, 0.0]
var _relic_regen := [0.0, 0.0]
var _regen := [Defs.COST_REGEN, Defs.COST_REGEN]
var _last_deployed_def_id := ["", ""]
var _last_deployed_time := [-999.0, -999.0]
var _encounter_pattern := ""
var _boss_phase_two := false
var _pattern_pulse := 0
## 틱 내 피해는 모았다가 끝에 한 번에 적용한다. 그래야 배열 순서가 승패를 가르지 않고
## 상호 확살이 동시 사망으로 처리된다.
var _pending: Dictionary = {}
var _events: Array = []        ## 시각화용. consume_events()로 비우며 가져간다.

const DEPLOY_COMBO_WINDOW := 4.0
const DEPLOY_COMBOS := {
	"capricorn>sagittarius": {"name":"엄호 사격", "atk_mult":1.30, "attacks":2},
	"aries>pisces": {"name":"돌파 신호", "atk_mult":1.45, "attacks":1},
	"sagittarius>aries": {"name":"표적 고정", "atk_mult":1.25, "attacks":2},
	"pisces>capricorn": {"name":"후퇴 엄호", "shield_ratio":0.22},
}


## placements: [{def_id, star, order}]
## level은 코스트 충전 속도를 결정한다. 정원(=레벨)이 커지면 충전도 빨라져야
## 큐 뒤쪽 유닛이 전투 시간 안에 나올 수 있다.
static func create(team0: Array, team1: Array,
		level0: int = Defs.LEVEL_BASE, level1: int = Defs.LEVEL_BASE,
		manual_team0: bool = false, cost_regen_mult0: float = 1.0) -> CombatSim:
	var sim := CombatSim.new()
	sim.manual_control[0] = manual_team0
	sim._regen = [Defs.cost_regen_for(level0) * cost_regen_mult0, Defs.cost_regen_for(level1)]
	sim._build_team(0, team0)
	sim._build_team(1, team1)
	return sim


func _build_team(team: int, placements: Array) -> void:
	var sorted := placements.duplicate()
	sorted.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))

	var tr := Traits.evaluate(sorted)
	traits_by_team[team] = tr
	_trait_regen[team] = tr.team_regen
	_relic_regen[team] = 0.0
	for i in sorted.size():
		if team == 1 and str(sorted[i].get("encounter_pattern", "")) != "":
			_encounter_pattern = str(sorted[i].get("encounter_pattern", ""))
		var u := _make_unit(team, sorted[i], i, tr)
		_relic_regen[team] = maxf(_relic_regen[team], float(sorted[i].get("relic_team_regen", 0.0)))
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
			var was_frontline := _front_unit(unit.team) == unit
			unit.alive = false
			if was_frontline:
				_emit_frontline_break(unit)
			_events.append({"t":"death", "uid":unit.uid})
	_check_end()
	return hit


func apply_tactical_order(order: String, power: int = 1) -> bool:
	if finished or tactical_charges[0] <= 0 or not ["전진", "방어", "집중"].has(order):
		return false
	var has_ally := false
	for unit in units:
		if unit.team == 0 and unit.is_active():
			has_ally = true
			break
	if not has_ally:
		return false
	var strength := maxi(power, 1)
	if order == "전진":
		var bonus := _enemy_leads_line()
		for unit in units:
			if unit.team == 0 and unit.is_active():
				unit.pos = minf(Defs.FIELD_LEN - 18.0, unit.pos + 12.0 * strength * (1.5 if bonus else 1.0))
		tactical_charges[0] -= 1
		_events.append({"t":"tactical", "name":order, "team":0, "charges":tactical_charges[0], "bonus":"압박 돌파" if bonus else "", "time":time})
		return true
	if order == "방어":
		var bonus := _enemy_leads_line()
		for unit in units:
			if unit.team == 0 and unit.is_active():
				unit.shield = maxf(unit.shield, unit.max_hp * (0.27 if bonus else 0.18) * strength)
		tactical_charges[0] -= 1
		_events.append({"t":"tactical", "name":order, "team":0, "charges":tactical_charges[0], "bonus":"긴급 방벽" if bonus else "", "time":time})
		return true
	if order == "집중":
		var target: SimUnit = null
		for unit in units:
			if unit.team == 1 and unit.is_active() and (target == null or unit.hp < target.hp):
				target = unit
		if target == null:
			return false
		var damage := 36.0 * strength
		var finishing := target.hp / maxf(target.max_hp, 1.0) <= 0.40
		if finishing:
			damage *= 1.35
		tactical_charges[0] -= 1
		target.hp = maxf(0.0, target.hp - damage)
		_events.append({"t": "command_hit", "to": target.uid, "dmg": damage})
		_events.append({"t":"tactical", "name":order, "team":0, "charges":tactical_charges[0], "time":time})
		if target.hp <= 0.0:
			var was_frontline := _front_unit(target.team) == target
			target.alive = false
			if was_frontline:
				_emit_frontline_break(target)
			_events.append({"t": "death", "uid": target.uid})
		_check_end()
		return true
	return false


func manual_deploy(team: int, uid: int) -> bool:
	## 수동 조작 팀의 카드 출격. 대기 큐 안의 카드는 순서와 무관하게 선택할 수 있다.
	if finished or team < 0 or team > 1 or cost[team] < 0.0:
		return false
	var unit := _by_uid.get(uid) as SimUnit
	if unit == null or unit.team != team or unit.deployed or not unit.alive or unit.is_recovering():
		return false
	if cost[team] < unit.deploy_cost:
		return false
	cost[team] -= unit.deploy_cost
	_queue[team].erase(unit)
	_deploy_unit(team, unit)
	if team == 0:
		_apply_deployment_combo(unit)
	return true


func manual_retreat(team: int, uid: int) -> bool:
	## 전선의 아군을 본진으로 회수한다. 회복이 끝날 때까지 재출격할 수 없다.
	if finished or team < 0 or team > 1:
		return false
	var unit := _by_uid.get(uid) as SimUnit
	if unit == null or unit.team != team or not unit.is_active():
		return false
	unit.deployed = false
	unit.target_uid = -1
	unit.pos = 0.0
	unit.cd = 0.0
	unit.shield = 0.0
	unit.recovery_left = Defs.RETREAT_RECOVERY_TIME
	unit.retreat_count += 1
	if team == 0:
		_last_deployed_def_id[team] = ""
		_last_deployed_time[team] = -999.0
	_events.append({"t": "retreat", "uid": unit.uid, "team": team, "time": time})
	return true


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

	u.max_hp = float(d["hp"]) * sm * float(mods["hp_mult"]) * float(p.get("relic_hp_mult", 1.0)) * float(p.get("tactic_hp_mult", 1.0)) * float(p.get("mutator_hp_mult", 1.0))
	u.hp = u.max_hp
	u.atk = float(d["atk"]) * sm * float(mods["atk_mult"]) * float(p.get("relic_atk_mult", 1.0)) * float(p.get("tactic_atk_mult", 1.0)) * float(p.get("mutator_atk_mult", 1.0))
	u.armor = float(d["armor"]) + float(mods["armor_add"]) + float(p.get("relic_armor_add", 0.0))
	u.atk_speed = float(d["atk_speed"]) * float(mods["as_mult"]) * float(p.get("relic_as_mult", 1.0)) * float(p.get("tactic_as_mult", 1.0))
	u.atk_range = float(d["atk_range"]) + float(p.get("relic_range_add", 0.0))
	u.move_speed = float(d["move_speed"]) * float(p.get("relic_move_mult", 1.0)) * float(p.get("tactic_move_mult", 1.0)) * float(p.get("mutator_move_mult", 1.0))
	u.ability = d["ability"].duplicate(true)
	u.relic_opening_atk_mult = float(p.get("relic_opening_atk_mult", 0.0))
	u.relic_opening_attacks = 1 if u.relic_opening_atk_mult > 0.0 else 0
	u.relic_armor_pierce_add = float(p.get("relic_armor_pierce_add", 0.0))
	u.relic_low_hp_atk_mult = float(p.get("relic_low_hp_atk_mult", 0.0))
	u.relic_early_atk_mult = float(p.get("relic_early_atk_mult", 0.0))
	u.relic_damage_taken_mult = float(p.get("relic_damage_taken_mult", 1.0))
	u.relic_core_damage_mult = float(p.get("relic_core_damage_mult", 1.0))
	var relic_shield_ratio := float(p.get("relic_shield_ratio", 0.0))
	if relic_shield_ratio > 0.0:
		u.shield = u.max_hp * relic_shield_ratio
		u.relic_shielded = true
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
	_apply_encounter_pattern()
	_tick_cost(dt)
	_tick_deploy()
	_apply_retreat_recovery(dt)
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


func _apply_encounter_pattern() -> void:
	if _encounter_pattern == "보스" and not _boss_phase_two and core_hp[1] <= Defs.CORE_HP * 0.5:
		_boss_phase_two = true
		for unit in units:
			if unit.team == 1 and unit.is_active():
				unit.atk_speed *= 1.15
				unit.move_speed *= 1.15
		_events.append({"t":"pattern", "name":"매듭 붕괴", "phase":2, "time":time})
	var interval := 6.0 if _encounter_pattern == "엘리트" else 4.0 if _boss_phase_two else 5.0 if _encounter_pattern == "보스" else 0.0
	if interval <= 0.0:
		return
	var pulse := int(floor(time / interval))
	if pulse <= _pattern_pulse:
		return
	_pattern_pulse = pulse
	if _encounter_pattern == "엘리트":
		var target: SimUnit = null
		for unit in units:
			if unit.team == 0 and unit.is_active() and (target == null or unit.hp < target.hp):
				target = unit
		if target == null:
			return
		target.hp = maxf(0.0, target.hp - 18.0)
		_events.append({"t": "pattern", "name": "검은 파동", "to": target.uid, "dmg": 18.0})
		if target.hp <= 0.0:
			target.alive = false
			_events.append({"t": "death", "uid": target.uid})
	else:
		var healed := false
		for unit in units:
			if unit.team == 1 and unit.is_active():
				unit.hp = minf(unit.max_hp, unit.hp + (8.0 if _boss_phase_two else 12.0))
				healed = true
		core_hp[1] = minf(Defs.CORE_HP, core_hp[1] + (5.0 if _boss_phase_two else 8.0))
		if healed:
			_events.append({"t": "pattern", "name": "매듭 재생", "heal": 8.0 if _boss_phase_two else 12.0})


func _tick_cost(dt: float) -> void:
	for team in 2:
		cost[team] = minf(Defs.MAX_COST, cost[team] + float(_regen[team]) * dt)


## 큐 맨 앞 유닛의 코스트가 차면 출격. 앞이 비싸면 그 자리에서 막힌다 —
## 그 막힘을 감수하고 순서를 짜는 것이 이 게임의 핵심 판단이다.
func _tick_deploy() -> void:
	for team in 2:
		if manual_control[team]:
			continue
		var q: Array = _queue[team]
		while not q.is_empty():
			var u: SimUnit = q[0]
			if cost[team] < u.deploy_cost:
				break
			cost[team] -= u.deploy_cost
			q.pop_front()
			_deploy_unit(team, u)


func _deploy_unit(team: int, u: SimUnit) -> void:
	u.deployed = true
	u.deployed_at = time
	u.pos = Defs.SPAWN_OFFSET
	# 첫 공격이 동시에 터지지 않도록 위상을 분산시킨다.
	u.cd = float(u.order % 7) * 0.03
	var shield_ratio := float(u.ability.get("deploy_shield_ratio", 0.0))
	if shield_ratio > 0.0:
		u.shield = u.max_hp * shield_ratio
		_emit_ability(u)
	if u.relic_shielded:
		_events.append({"t": "relic", "uid": u.uid, "name": "닻의 파편", "time": time})
	var refund := float(u.ability.get("deploy_cost_refund", 0.0))
	if refund > 0.0:
		cost[team] = minf(Defs.MAX_COST, cost[team] + refund)
		_emit_ability(u)
	if u.ability.has("deploy_haste"):
		_emit_ability(u)
	_events.append({"t": "deploy", "uid": u.uid, "team": team, "time": time})


func _apply_deployment_combo(unit: SimUnit) -> void:
	var previous := str(_last_deployed_def_id[0])
	var elapsed := time - float(_last_deployed_time[0])
	if not previous.is_empty() and elapsed <= DEPLOY_COMBO_WINDOW:
		var combo_key := "%s>%s" % [previous, unit.def_id]
		if DEPLOY_COMBOS.has(combo_key):
			var combo: Dictionary = DEPLOY_COMBOS[combo_key]
			unit.combo_atk_mult = float(combo.get("atk_mult", 1.0))
			unit.combo_attacks_left = int(combo.get("attacks", 0))
			var shield_ratio := float(combo.get("shield_ratio", 0.0))
			if shield_ratio > 0.0:
				unit.shield = maxf(unit.shield, unit.max_hp * shield_ratio)
			_events.append({"t":"combo", "from_def":previous, "uid":unit.uid,
				"name":combo.get("name", "출격 연계"), "time":time})
	_last_deployed_def_id[0] = unit.def_id
	_last_deployed_time[0] = time


func _emit_frontline_break(victim: SimUnit) -> void:
	if not manual_control[0]:
		return
	cost[0] = minf(Defs.MAX_COST, cost[0] + 2.0)
	_events.append({"t":"break", "team":0, "uid":victim.uid, "name":"전선 돌파", "cost":2.0, "time":time})


func _apply_regen(dt: float) -> void:
	for team in 2:
		var ability_rate := 0.0
		for provider in units:
			if provider.is_active() and provider.team == team:
				ability_rate = maxf(ability_rate,
					float(provider.ability.get("active_team_regen", 0.0)))
		# 원소 시너지와 고유 능력은 서로 다른 편성 보상이므로 합산하되,
		# 같은 고유 능력을 여러 장 넣은 값은 위에서 가장 높은 하나만 쓴다.
		var rate: float = _trait_regen[team] + _relic_regen[team] + ability_rate
		if rate <= 0.0:
			continue
		for u in units:
			if u.is_active() and u.team == team and u.hp < u.max_hp:
				u.hp = minf(u.max_hp, u.hp + u.max_hp * rate * dt)


func _apply_retreat_recovery(dt: float) -> void:
	for u in units:
		if not u.is_recovering():
			continue
		var recovering_for := minf(dt, u.recovery_left)
		u.hp = minf(u.max_hp, u.hp + u.max_hp * recovering_for / Defs.RETREAT_RECOVERY_TIME)
		u.recovery_left = maxf(0.0, u.recovery_left - dt)
		if is_zero_approx(u.recovery_left):
			u.hp = u.max_hp
			_events.append({"t": "recovery_ready", "uid": u.uid, "team": u.team, "time": time})


func _emit_ability(u: SimUnit) -> void:
	_events.append({
		"t": "ability", "uid": u.uid, "team": u.team,
		"name": u.ability.get("name", ""), "time": time,
	})


func _retarget(u: SimUnit) -> void:
	var t: SimUnit = _by_uid.get(u.target_uid) as SimUnit
	if t == null or not t.is_active() or t != _front_unit(1 - u.team):
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

	var armor_pierce := clampf(float(u.ability.get("armor_pierce", 0.0)) + u.relic_armor_pierce_add, 0.0, 0.95)
	var effective_armor := target.armor * (1.0 - armor_pierce)
	var dmg: float = u.atk * _consume_combo_attack(u) * (1.0 + float(u.kill_stacks) \
		* float(u.ability.get("kill_atk_mult", 0.0)))
	if u.relic_opening_attacks > 0:
		dmg *= 1.0 + u.relic_opening_atk_mult
		u.relic_opening_attacks -= 1
		_events.append({"t": "relic", "uid": u.uid, "name": "중계 비콘", "time": time})
	if u.relic_early_atk_mult > 0.0 and time - u.deployed_at <= 10.0:
		dmg *= 1.0 + u.relic_early_atk_mult
		if not u.relic_early_announced:
			u.relic_early_announced = true
			_events.append({"t": "relic", "uid": u.uid, "name": "과부하 심지", "time": time})
	if u.relic_low_hp_atk_mult > 0.0 and u.hp / maxf(u.max_hp, 1.0) <= 0.35:
		dmg *= 1.0 + u.relic_low_hp_atk_mult
		if not u.relic_low_hp_announced:
			u.relic_low_hp_announced = true
			_events.append({"t": "relic", "uid": u.uid, "name": "마지막 등불", "time": time})
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
				var was_frontline := _front_unit(t.team) == t
				t.alive = false
				killed_by[uid] = contributors.keys()
				if was_frontline:
					_emit_frontline_break(t)
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
	dmg *= target.relic_damage_taken_mult
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
	var dmg: float = u.atk * _consume_combo_attack(u) * (1.0 + float(u.kill_stacks) \
		* float(u.ability.get("kill_atk_mult", 0.0))) * damage_rampup()
	dmg *= u.relic_core_damage_mult
	dmg *= 1.0 - _active_core_reduction(enemy)
	core_hp[enemy] = maxf(0.0, core_hp[enemy] - dmg)
	_events.append({"t": "core", "from": u.uid, "team": enemy, "dmg": dmg, "time": time})


func _active_core_reduction(team: int) -> float:
	var reduction := 0.0
	for u in units:
		if u.is_active() and u.team == team:
			reduction = maxf(reduction, float(u.ability.get("active_core_reduction", 0.0)))
	return clampf(reduction, 0.0, 0.9)


## 단일 라인의 교전 규칙. 일반 공격은 반드시 상대 최전방 한 명에게만 향한다.
## 뒤 유닛을 직접 고를 수 없으므로 최전방 방어자가 살아 있는 동안 후열은 보호된다.
func _find_target(u: SimUnit) -> SimUnit:
	return _front_unit(1 - u.team)


## pos는 각자 자기 코어에서 전진한 거리이므로 팀과 무관하게 최댓값이 선두다.
func _front_unit(team: int) -> SimUnit:
	var best: SimUnit = null
	var best_pos := -INF
	for o in units:
		if not o.is_active() or o.team != team:
			continue
		if o.pos > best_pos:
			best_pos = o.pos
			best = o
	return best


func _enemy_leads_line() -> bool:
	var ally := _front_unit(0)
	var enemy := _front_unit(1)
	return ally != null and enemy != null and enemy.pos > ally.pos


func _consume_combo_attack(unit: SimUnit) -> float:
	if unit.combo_attacks_left <= 0:
		return 1.0
	unit.combo_attacks_left -= 1
	var multiplier := unit.combo_atk_mult
	if unit.combo_attacks_left == 0:
		unit.combo_atk_mult = 1.0
	return multiplier


func _is_frontline(u: SimUnit) -> bool:
	return u.is_active() and _front_unit(u.team) == u


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
		state["frontline"] = _is_frontline(u)
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
