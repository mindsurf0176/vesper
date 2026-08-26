class_name RogueliteRun
extends RefCounted

## Vesper Endless Corridor의 결정론적 런 상태.
## 이미지나 씬이 아니라 seed와 데이터가 런을 정의한다.

const NODE_TYPES := ["전투", "엘리트", "보급", "이벤트", "회복"]
const MUTATORS := [
	{"id":"collapse", "name":"붕괴하는 회랑", "desc":"5턴마다 모든 전투원에게 피해"},
	{"id":"overheat", "name":"과열", "desc":"필살 피해 증가, 사용 후 HP 감소"},
	{"id":"silence", "name":"무음", "desc":"회복량 감소, 방어 성공 시 게이지 증가"},
]
const RELICS := [
	{"id":"ember", "name":"잔불 인장", "tag":"필살", "desc":"필살기 피해 +20%"},
	{"id":"anchor", "name":"닻의 파편", "tag":"방어", "desc":"첫 피해를 한 번 무효화"},
	{"id":"relay", "name":"중계 파장", "tag":"교대", "desc":"교대 후 다음 공격 강화"},
	{"id":"thread", "name":"봉합 실", "tag":"지원", "desc":"전투 종료 후 전원 회복"},
	{"id":"lens", "name":"궤적 렌즈", "tag":"사격", "desc":"원거리 공격이 방어 일부 무시"},
	{"id":"bell", "name":"무명의 종", "tag":"연속", "desc":"연속 행동 시 게이지 추가 획득"},
]

var seed: int
var rng := RandomNumberGenerator.new()
var nodes: Array[Dictionary] = []
var node_index := 0
var team: Array[Dictionary] = []
var relics: Array[Dictionary] = []
var mutators: Array[Dictionary] = []
var run_over := false
var won := false

func _init(run_seed: int = 0) -> void:
	seed = run_seed if run_seed != 0 else Time.get_unix_time_from_system()
	rng.seed = seed
	_generate_nodes()
	_roll_mutators()

func start_with_team(selected: Array[Dictionary]) -> void:
	team.clear()
	for fighter in selected.slice(0, 3):
		var entry: Dictionary = fighter.duplicate(true)
		entry["run_hp"] = 100.0
		entry["fallen"] = false
		team.append(entry)

func current_node() -> Dictionary:
	if node_index < 0 or node_index >= nodes.size():
		return {}
	return nodes[node_index].duplicate(true)

func choose_next(path_index: int) -> Dictionary:
	if run_over or path_index < 0 or path_index >= nodes.size():
		return {}
	node_index = path_index
	return current_node()

func complete_current_node() -> void:
	if run_over:
		return
	if current_node().get("type", "") == "보스":
		run_over = true
		won = true
	else:
		node_index += 1
		if node_index >= nodes.size():
			run_over = true
			won = true

func add_relic() -> Dictionary:
	var available := RELICS.filter(func(item: Dictionary) -> bool:
		return not _has_relic(str(item["id"]))
	)
	if available.is_empty():
		return {}
	var picked: Dictionary = available[rng.randi_range(0, available.size() - 1)].duplicate(true)
	relics.append(picked)
	return picked

func apply_rest(amount := 24.0) -> void:
	for fighter in team:
		if not bool(fighter.get("fallen", false)):
			fighter["run_hp"] = minf(100.0, float(fighter.get("run_hp", 100.0)) + amount)

func _generate_nodes() -> void:
	nodes.clear()
	# 짧은 런: 전투 3회 + 중간 선택 1회 + 보스. 선택지는 같은 층에서 갈린다.
	nodes.append(_node("전투", 0))
	var branch_a := _node(NODE_TYPES[rng.randi_range(1, 4)], 1)
	var branch_b := _node(NODE_TYPES[rng.randi_range(1, 4)], 1)
	branch_a["branch"] = 0; branch_b["branch"] = 1
	nodes.append(branch_a); nodes.append(branch_b)
	nodes.append(_node("전투", 2))
	nodes.append(_node("보스", 3))

func _node(node_type: String, floor_index: int) -> Dictionary:
	return {
		"id": "%d-%d" % [floor_index, nodes.size()],
		"type": node_type,
		"floor": floor_index,
		"threat": 1.0 + floor_index * 0.25,
		"enemy_seed": rng.randi(),
	}

func _roll_mutators() -> void:
	mutators.clear()
	var pool := MUTATORS.duplicate(true)
	for _i in 2:
		var index := rng.randi_range(0, pool.size() - 1)
		mutators.append(pool[index])
		pool.remove_at(index)

func _has_relic(relic_id: String) -> bool:
	for relic in relics:
		if str(relic.get("id", "")) == relic_id:
			return true
	return false
