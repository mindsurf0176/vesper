class_name LineBattle
extends RefCounted

## 베스퍼 회랑의 정식 실시간 라인 전투 코어.
## 렌더러와 입력 UI는 이 상태를 소비하고, 이 파일은 에셋이나 씬을 참조하지 않는다.

const ALLY := 0
const ENEMY := 1
const STRIKER := 0
const RANGER := 1
const DEFENDER := 2
const SUPPORT := 3
const SNIPER := 4

const FIELD_LENGTH := 100.0
const START_COST := 3.0
const MAX_COST := 10.0
const COST_REGEN := 0.7
const MAX_ALLIES := 7
const MAX_TIME := 45.0

var time := 0.0
var cost := START_COST
var ally_core_hp := 350.0
var ally_core_max := 350.0
var enemy_core_hp := 520.0
var ended := false
var winner := -1
var soshin_used := 0
var next_uid := 1
var units: Array[Dictionary] = []
var events: Array[Dictionary] = []

func _init(enemy_hp: float = 520.0, ally_hp: float = 350.0) -> void:
	enemy_core_hp = enemy_hp
	ally_core_max = ally_hp
	ally_core_hp = ally_hp

func reset(enemy_hp: float = 520.0, ally_hp: float = -1.0) -> void:
	time = 0.0
	cost = START_COST
	if ally_hp > 0.0:
		ally_core_max = ally_hp
		ally_core_hp = ally_hp
	else:
		ally_core_hp = ally_core_max
	enemy_core_hp = enemy_hp
	ended = false
	winner = -1
	soshin_used = 0
	next_uid = 1
	units.clear()
	events.clear()

func deploy(definition: Dictionary, x: float = -1.0) -> int:
	if ended or ally_count() >= MAX_ALLIES:
		return -1
	var required := float(definition.get("cost", 99.0))
	if cost < required:
		return -1
	cost -= required
	var unit := {
		"uid": next_uid,
		"team": ALLY,
		"name": str(definition.get("name", "사도")),
		"role": int(definition.get("role", STRIKER)),
		"hp": float(definition.get("hp", 50.0)),
		"max_hp": float(definition.get("hp", 50.0)),
		"atk": float(definition.get("atk", definition.get("dmg", 10.0))),
		"armor": float(definition.get("armor", 0.0)),
		"range": float(definition.get("range", 1.0)),
		"speed": float(definition.get("speed", definition.get("move", 1.5))),
		"attack_cd": 0.0,
		"attack_interval": 1.0 / maxf(float(definition.get("aspd", 1.0)), 0.05),
		"x": 15.0 if x < 0.0 else clampf(x, 1.0, 45.0),
		"alive": true,
	}
	units.append(unit)
	next_uid += 1
	events.append({"type": "deploy", "uid": unit["uid"], "name": unit["name"]})
	return int(unit["uid"])

func spawn_enemy(definition: Dictionary, x: float = -1.0) -> int:
	if ended:
		return -1
	var unit := {
		"uid": next_uid,
		"team": ENEMY,
		"name": str(definition.get("name", "항체")),
		"role": int(definition.get("role", STRIKER)),
		"hp": float(definition.get("hp", 50.0)),
		"max_hp": float(definition.get("hp", 50.0)),
		"atk": float(definition.get("atk", definition.get("dmg", 8.0))),
		"armor": float(definition.get("armor", 0.0)),
		"range": float(definition.get("range", 1.0)),
		"speed": float(definition.get("speed", definition.get("move", 1.2))),
		"attack_cd": 0.0,
		"attack_interval": 1.0 / maxf(float(definition.get("aspd", 1.0)), 0.05),
		"x": 85.0 if x < 0.0 else clampf(x, 55.0, 99.0),
		"alive": true,
	}
	units.append(unit)
	next_uid += 1
	events.append({"type": "spawn", "uid": unit["uid"], "name": unit["name"]})
	return int(unit["uid"])

func step(delta: float) -> void:
	if ended:
		return
	var dt := maxf(delta, 0.0)
	time += dt
	cost = minf(MAX_COST, cost + COST_REGEN * dt)
	for unit in units:
		if not bool(unit["alive"]):
			continue
		unit["attack_cd"] = maxf(0.0, float(unit["attack_cd"]) - dt)
		var target = _nearest_target(unit)
		if target == null:
			var direction := 1.0 if unit["team"] == ALLY else -1.0
			unit["x"] = clampf(float(unit["x"]) + float(unit["speed"]) * direction * dt, 0.0, FIELD_LENGTH)
			if (unit["team"] == ALLY and float(unit["x"]) >= FIELD_LENGTH - 1.0):
				_damage_core(ENEMY, float(unit["atk"]) * dt)
			elif (unit["team"] == ENEMY and float(unit["x"]) <= 1.0):
				_damage_core(ALLY, float(unit["atk"]) * dt)
		elif absf(float(target["x"]) - float(unit["x"])) <= float(unit["range"]):
			if float(unit["attack_cd"]) <= 0.0:
				_attack(unit, target)
				unit["attack_cd"] = float(unit["attack_interval"])
		else:
			unit["x"] = move_toward(float(unit["x"]), float(target["x"]) - (0.5 if unit["team"] == ALLY else -0.5), float(unit["speed"]) * dt)
	_check_end()

func use_soshin() -> bool:
	if ended or soshin_used >= 2 or ally_core_hp <= ally_core_max * 0.20:
		return false
	var burn := ally_core_max * 0.07
	ally_core_hp -= burn
	cost = minf(MAX_COST, cost + 3.0)
	soshin_used += 1
	events.append({"type": "soshin", "cost": cost, "core_hp": ally_core_hp})
	return true

func cast_orb(role: int, count: int) -> bool:
	if ended or not [1, 2, 4].has(count):
		return false
	var caster = _front_alive(ALLY, role)
	if caster == null:
		return false
	var target = _front_alive(ENEMY, -1)
	var amount := float(count) * 12.0
	if target != null and role != SUPPORT:
		target["hp"] = maxf(0.0, float(target["hp"]) - amount)
		events.append({"type": "ability", "uid": caster["uid"], "target": target["uid"], "role": role, "count": count, "amount": amount})
		if float(target["hp"]) <= 0.0:
			target["alive"] = false
			events.append({"type": "death", "uid": target["uid"]})
	elif role == SUPPORT:
		caster["hp"] = minf(float(caster["max_hp"]), float(caster["hp"]) + amount)
		events.append({"type": "ability", "uid": caster["uid"], "role": role, "count": count, "amount": amount})
	else:
		_damage_core(ENEMY, amount * 0.5)
	_check_end()
	return true

func cast_command(damage: float = 48.0, push: float = 0.0) -> bool:
	if ended:
		return false
	var hit := false
	for unit in units:
		if not bool(unit["alive"]) or unit["team"] != ENEMY:
			continue
		unit["hp"] = maxf(0.0, float(unit["hp"]) - damage)
		unit["x"] = minf(FIELD_LENGTH - 1.0, float(unit["x"]) + push)
		events.append({"type": "command", "uid": unit["uid"], "amount": damage})
		hit = true
		if float(unit["hp"]) <= 0.0:
			unit["alive"] = false
			events.append({"type": "death", "uid": unit["uid"]})
	_check_end()
	return hit

func cast_last_stand(push: float = 4.2, damage: float = 28.0) -> bool:
	if ended or ally_core_hp > ally_core_max * 0.25:
		return false
	ally_core_hp = maxf(ally_core_hp, ally_core_max * 0.20)
	for unit in units:
		if bool(unit["alive"]) and unit["team"] == ENEMY:
			unit["x"] = minf(FIELD_LENGTH - 1.0, float(unit["x"]) + push)
			unit["hp"] = maxf(0.0, float(unit["hp"]) - damage)
			events.append({"type": "last_stand", "uid": unit["uid"], "amount": damage})
	events.append({"type": "barrier", "duration": 4.0})
	return true

func ally_count() -> int:
	var count := 0
	for unit in units:
		if bool(unit["alive"]) and unit["team"] == ALLY:
			count += 1
	return count

func consume_events() -> Array[Dictionary]:
	var result := events.duplicate(true)
	events.clear()
	return result

func snapshot() -> Dictionary:
	return {
		"time": time,
		"cost": cost,
		"ally_core_hp": ally_core_hp,
		"enemy_core_hp": enemy_core_hp,
		"ended": ended,
		"winner": winner,
		"units": units.duplicate(true),
	}

func _nearest_target(unit: Dictionary):
	var best = null
	var distance := INF
	for candidate in units:
		if not bool(candidate["alive"]) or candidate["team"] == unit["team"]:
			continue
		var gap := absf(float(candidate["x"]) - float(unit["x"]))
		if gap < distance:
			distance = gap
			best = candidate
	return best

func _front_alive(team: int, role: int):
	var best = null
	var best_x := -INF if team == ALLY else INF
	for unit in units:
		if not bool(unit["alive"]) or unit["team"] != team:
			continue
		if role >= 0 and unit["role"] != role:
			continue
		if (team == ALLY and float(unit["x"]) > best_x) or (team == ENEMY and float(unit["x"]) < best_x):
			best_x = float(unit["x"])
			best = unit
	return best

func _attack(attacker: Dictionary, target: Dictionary) -> void:
	var multiplier := 1.0
	if attacker["role"] != SUPPORT and target["role"] != SUPPORT:
		if (attacker["role"] == STRIKER and target["role"] == RANGER) or (attacker["role"] == RANGER and target["role"] == DEFENDER) or (attacker["role"] == DEFENDER and target["role"] == STRIKER):
			multiplier = 1.3
		elif (target["role"] == STRIKER and attacker["role"] == RANGER) or (target["role"] == RANGER and attacker["role"] == DEFENDER) or (target["role"] == DEFENDER and attacker["role"] == STRIKER):
			multiplier = 0.8
	var amount := maxf(1.0, float(attacker["atk"]) * multiplier * (100.0 / (100.0 + float(target["armor"]))))
	target["hp"] = maxf(0.0, float(target["hp"]) - amount)
	events.append({"type": "hit", "attacker": attacker["uid"], "target": target["uid"], "amount": amount})
	if float(target["hp"]) <= 0.0:
		target["alive"] = false
		events.append({"type": "death", "uid": target["uid"]})

func _damage_core(team: int, amount: float) -> void:
	if team == ALLY:
		ally_core_hp = maxf(0.0, ally_core_hp - amount)
	else:
		enemy_core_hp = maxf(0.0, enemy_core_hp - amount)
	events.append({"type": "core_hit", "team": team, "amount": amount})

func _check_end() -> void:
	if enemy_core_hp <= 0.0:
		ended = true
		winner = ALLY
	elif ally_core_hp <= 0.0:
		ended = true
		winner = ENEMY
	elif time >= MAX_TIME:
		ended = true
		winner = ALLY if enemy_core_hp < ally_core_hp else ENEMY
