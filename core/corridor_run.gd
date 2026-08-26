class_name CorridorRun
extends RefCounted

## 라인배틀러를 보존하는 회랑 탐험 런.
## 이 파일은 맵/조우/보상만 소유하고, 실제 전투는 CombatSim이 소유한다.

const ENCOUNTERS := [
	{"id":"ash_gate", "name":"재의 관문", "kind":"전투", "threat":1.0},
	{"id":"signal_fork", "name":"끊긴 신호 분기점", "kind":"이벤트", "threat":1.0},
	{"id":"hollow_depot", "name":"빈 보급고", "kind":"보급", "threat":1.1},
	{"id":"black_procession", "name":"검은 행렬", "kind":"엘리트", "threat":1.5},
	{"id":"vesper_core", "name":"베스퍼 매듭", "kind":"보스", "threat":2.0},
]

var seed: int
var rng := RandomNumberGenerator.new()
var route: Array[Dictionary] = []
var branch_options: Array[Dictionary] = []
var branch_chosen := false
var route_index := 0
var cleared := false
var failed := false
var rewards: Array[Dictionary] = []

func _init(run_seed: int) -> void:
	seed = run_seed
	rng.seed = seed
	_build_route()

func current() -> Dictionary:
	if route_index < 0 or route_index >= route.size():
		return {}
	return route[route_index].duplicate(true)

func complete_current() -> void:
	if cleared or failed:
		return
	var node := current()
	if node.get("kind", "") == "보스":
		cleared = true
		return
	rewards.append(_reward_for(node))
	route_index += 1

func available_options() -> Array[Dictionary]:
	if route_index == 1 and not branch_chosen:
		return branch_options.duplicate(true)
	return []

func choose_option(option_index: int) -> bool:
	if route_index != 1 or branch_chosen or option_index < 0 or option_index >= branch_options.size():
		return false
	route[route_index] = branch_options[option_index].duplicate(true)
	branch_chosen = true
	return true

func fail() -> void:
	failed = true

func is_finished() -> bool:
	return cleared or failed

func _build_route() -> void:
	route.clear()
	branch_options.clear()
	branch_chosen = false
	var first := ENCOUNTERS[0].duplicate(true)
	first["floor"] = 1
	first["enemy_seed"] = rng.randi()
	route.append(first)
	var middle := [ENCOUNTERS[1], ENCOUNTERS[2], ENCOUNTERS[3]]
	for encounter in middle:
		var option: Dictionary = encounter.duplicate(true)
		option["floor"] = 2
		option["enemy_seed"] = rng.randi()
		branch_options.append(option)
	route.append(branch_options[0].duplicate(true))
	var second := ENCOUNTERS[0].duplicate(true)
	second["floor"] = 3
	second["enemy_seed"] = rng.randi()
	route.append(second)
	var boss := ENCOUNTERS[4].duplicate(true)
	boss["floor"] = 4
	boss["enemy_seed"] = rng.randi()
	route.append(boss)

func _reward_for(node: Dictionary) -> Dictionary:
	var kind := str(node.get("kind", "전투"))
	if kind == "보급":
		return {"type":"supply", "name":"보급 상자", "gold":8, "hp":12, "relic":"ember_cache", "relic_name":"잔불 보관함"}
	if kind == "이벤트":
		return {"type":"event", "name":"신호 해석", "gold":4, "hp":0, "relic":"signal_lens", "relic_name":"신호 렌즈"}
	if kind == "엘리트":
		return {"type":"relic", "name":"희귀 각인", "gold":14, "hp":0, "relic":"hollow_crown", "relic_name":"공허 왕관"}
	return {"type":"battle", "name":"전투 보상", "gold":5, "hp":0}
