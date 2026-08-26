class_name CorridorSession
extends RefCounted

const RELIC_DB = preload("res://core/relics.gd")

## 회랑 런 전용 세션.
## 다인 매치의 대전표/상점/순위 시스템과 분리된 단일 원정대 세션이다.

class Seat extends RefCounted:
	var index: int
	var name: String
	var player: Econ.Player

var econ: Econ
var seats: Array[Seat] = []
var round_no := 1
var current_pairs: Array = []
var last_results: Array = []

static func create(seed_value: int):
	var session = new()
	session.econ = Econ.new(seed_value)
	for i in 2:
		var seat := Seat.new()
		seat.index = i
		seat.name = "원정대" if i == 0 else "회랑의 적"
		seat.player = Econ.Player.new()
		session.seats.append(seat)
	return session

func human_seat() -> Seat:
	return seats[0]

func pair_up() -> Array:
	current_pairs = [[0, 1]]
	return current_pairs.duplicate(true)

func build_sim(a: int, b: int) -> CombatSim:
	var pa := seats[a].player
	var pb := seats[b].player
	var allies: Array = []
	for unit in pa.queued_units():
		var placement: Dictionary = unit.duplicate(true)
		_apply_relic_modifiers(placement, pa.relics)
		_apply_tactic_modifiers(placement, pa.tactic)
		allies.append(placement)
	var enemies: Array = []
	for unit in pb.queued_units():
		enemies.append(unit.duplicate(true))
	return CombatSim.create(allies, enemies, pa.level, pb.level, true)

func resolve_round(pairs: Array, precomputed: Dictionary = {}) -> void:
	last_results.clear()
	if pairs.is_empty():
		return
	var pair: Array = pairs[0]
	var a: int = pair[0]
	var b: int = pair[1]
	var result: Dictionary
	if precomputed.has(a):
		result = precomputed[a]
	else:
		result = build_sim(a, b).run_to_end()
	var winner_seat := -1
	if int(result.get("winner", -1)) == 0:
		winner_seat = a
	elif int(result.get("winner", -1)) == 1:
		winner_seat = b
	var settle := econ.settle(seats[a].player, 1 if winner_seat == a else 0 if winner_seat == b else -1,
		float(result.get("core_ratio", [1.0, 1.0])[0]), int(result.get("survivors", [0, 0])[1]), round_no)
	last_results.append({
		"a": a, "b": b, "winner_seat": winner_seat,
		"core_ratio": result.get("core_ratio", [1.0, 1.0]),
		"survivors": result.get("survivors", [0, 0]),
		"damage_a": int(settle.get("damage", 0)), "settle_a": settle,
	})
	round_no += 1

func is_over() -> bool:
	return not human_seat().player.is_alive()

func human_placement() -> int:
	return 2 if is_over() else 1

func _apply_relic_modifiers(placement: Dictionary, relics: Array[String]) -> void:
	RELIC_DB.apply_to_placement(placement, relics)

func _apply_tactic_modifiers(placement: Dictionary, tactic: String) -> void:
	if tactic == "압박":
		placement["tactic_atk_mult"] = 1.12
	elif tactic == "요새":
		placement["tactic_hp_mult"] = 1.15
		placement["tactic_as_mult"] = 0.92
	elif tactic == "순환":
		placement["tactic_hp_mult"] = 0.92
		placement["tactic_as_mult"] = 1.14
