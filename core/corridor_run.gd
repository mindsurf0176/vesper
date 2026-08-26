class_name CorridorRun
extends RefCounted

## 라인배틀러를 보존하는 회랑 탐험 런.
## 이 파일은 맵/조우/보상만 소유하고, 실제 전투는 CombatSim이 소유한다.

const ENCOUNTERS := [
	{"id":"ash_gate", "name":"재의 관문", "kind":"전투", "threat":1.0},
	{"id":"signal_fork", "name":"끊긴 신호 분기점", "kind":"이벤트", "threat":1.0},
	{"id":"hollow_depot", "name":"빈 보급고", "kind":"보급", "threat":1.1},
	{"id":"quiet_anchor", "name":"고요한 정박지", "kind":"휴식", "threat":0.8},
	{"id":"black_procession", "name":"검은 행렬", "kind":"엘리트", "threat":1.5},
	{"id":"vesper_core", "name":"베스퍼 매듭", "kind":"보스", "threat":2.0},
]

var seed: int
var rng := RandomNumberGenerator.new()
var route: Array[Dictionary] = []
var branch_options: Array[Dictionary] = []
var map_layers: Array[Array] = []
var branch_chosen := false
var route_index := 0
var cleared := false
var failed := false
var distance := 0
var best_distance := 0
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
	rewards.append(_reward_for(node))
	distance += 1
	best_distance = maxi(best_distance, distance)
	route_index += 1
	branch_chosen = false
	branch_options.clear()
	_ensure_current_node()

func available_options() -> Array[Dictionary]:
	if route_index > 0 and not branch_chosen:
		if branch_options.is_empty():
			branch_options = _generate_options(distance + 1)
		return branch_options.duplicate(true)
	return []

func choose_option(option_index: int) -> bool:
	if route_index <= 0 or branch_chosen:
		return false
	if branch_options.is_empty():
		branch_options = _generate_options(distance + 1)
	_ensure_current_node()
	if option_index < 0 or option_index >= branch_options.size():
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
	map_layers.clear()
	branch_chosen = false
	distance = 0
	best_distance = 0
	var first := _make_node("전투", 1)
	route.append(first)
	# 한 번에 한 노드만 생성한다. 런은 보스에서 끝나지 않고, 플레이어가
	# 전멸할 때까지 다음 회랑을 계속 만든다.
	_ensure_current_node()


func _ensure_current_node() -> void:
	while route_index >= route.size():
		route.append(_make_node(_next_kind(distance + 1), distance + 1))


func _generate_options(floor_index: int) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var safe_kind := "휴식" if rng.randi_range(0, 1) == 0 else "보급"
	var kinds: Array[String] = [safe_kind, "전투", "엘리트"]
	if floor_index % 7 == 0:
		kinds = [safe_kind, "전투", "보스"]
	for kind in kinds:
		options.append(_make_node(kind, floor_index))
	return options


func _next_kind(floor_index: int) -> String:
	if floor_index % 7 == 0:
		return "보스"
	var roll := rng.randi_range(0, 99)
	if roll < 52:
		return "전투"
	if roll < 70:
		return "엘리트"
	if roll < 82:
		return "보급"
	if roll < 92:
		return "이벤트"
	return "휴식"


func _make_node(kind: String, floor_index: int) -> Dictionary:
	var template := ENCOUNTERS[0]
	for encounter in ENCOUNTERS:
		if str(encounter.get("kind", "")) == kind:
			template = encounter
			break
	var threat := 1.0 + float(maxi(floor_index - 1, 0)) * 0.08
	if kind == "엘리트":
		threat += 0.35
	elif kind == "보스":
		threat += 0.75
	return {
		"id": "%d-%d-%d" % [floor_index, route_index, rng.randi()],
		"name": template.get("name", "회랑"),
		"kind": kind,
		"floor": floor_index,
		"threat": threat,
		"enemy_seed": rng.randi(),
	}

func _reward_for(node: Dictionary) -> Dictionary:
	var kind := str(node.get("kind", "전투"))
	var relic_choices: Array[String] = ["ember_cache", "signal_lens", "hollow_crown"]
	if kind == "보급":
		relic_choices = ["ember_cache", "anchor_shard", "tide_core"]
		return {"type":"supply", "name":"보급 상자", "gold":8, "hp":12, "relic_choices":relic_choices}
	if kind == "이벤트":
		relic_choices = ["signal_lens", "longwatch", "relay_beacon", "core_lens"]
		return {"type":"event", "name":"신호 해석", "gold":4, "hp":0, "relic_choices":relic_choices}
	if kind == "엘리트" or kind == "보스":
		relic_choices = ["hollow_crown", "iron_echo", "last_lantern", "breach_round", "glass_edge"]
		return {"type":"relic", "name":"희귀 각인", "gold":14, "hp":0, "relic_choices":relic_choices}
	return {"type":"battle", "name":"전투 보상", "gold":5, "hp":0,
		"relic_choices":["quickstep", "ward_sigil", "overdrive"]}
