class_name Match
extends RefCounted

## 8인 매치. 오토체스의 경제·저축 전략은 다인전을 전제한다 —
## 나처럼 약한 상대를 만날 수 있어야 "이번 라운드를 버리고 굴린다"가 성립한다.
## 봇 1대1 구조에서는 상대가 라운드에만 비례해 강해지므로 그 선택지가 원리적으로 없다.
##
## 0번이 사람이고 나머지는 AutoPlay가 운영한다. 유닛 풀은 전원이 공유한다.

const SEATS := 8

class Seat extends RefCounted:
	var index: int
	var name: String
	var player: Econ.Player
	var is_human: bool = false
	var style: int = AutoPlay.Style.SPENDER
	var placement: int = 0        ## 최종 등수. 0이면 아직 생존.

	func alive() -> bool:
		return player.is_alive()


var econ: Econ                   ## 풀과 rng를 전원이 공유한다
var seats: Array[Seat] = []
var round_no := 1
var rng := RandomNumberGenerator.new()
## 이번 라운드 대전 결과: [{a, b, winner, core_ratio, survivors, damage}]
var last_results: Array = []
## 현재 밤 대전표. 준비 화면에서 다음 상대를 미리 보여 준다.
var current_pairs: Array = []

var _seat_names := ["당신", "미르", "하람", "노을", "가온", "여울", "다온", "시온"]


static func create(seed_value: int, human: bool = true) -> Match:
	var m := Match.new()
	m.rng.seed = seed_value
	m.econ = Econ.new(seed_value, Econ.Pool.new())
	for i in SEATS:
		var s := Seat.new()
		s.index = i
		s.name = m._seat_names[i % m._seat_names.size()]
		s.player = Econ.Player.new()
		s.is_human = human and i == 0
		# 성향을 절반씩 섞는다. 이래야 두 전략의 성적을 같은 매치 안에서 비교할 수 있다.
		s.style = AutoPlay.Style.SAVER if i % 2 == 0 else AutoPlay.Style.SPENDER
		m.econ.refresh_shop(s.player, true)
		m.seats.append(s)
	return m


func living_seats() -> Array[Seat]:
	var out: Array[Seat] = []
	for s in seats:
		if s.alive():
			out.append(s)
	return out


func human_seat() -> Seat:
	for s in seats:
		if s.is_human:
			return s
	return seats[0]


## 사람을 제외한 전원이 준비 페이즈를 수행한다.
func run_ai_prep() -> void:
	for s in living_seats():
		if s.is_human:
			continue
		AutoPlay.play_prep(econ, s.player, round_no, rng, s.style)


## 생존자를 무작위로 짝짓는다. 홀수면 한 명은 이미 탈락한 상대의 편성과 붙는다
## (오토체스의 유령 상대와 같은 처리).
func pair_up() -> Array:
	var living := living_seats()
	var idx: Array = []
	for s in living:
		idx.append(s.index)
	# 결정론적 셔플
	for i in range(idx.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp

	var pairs: Array = []
	while idx.size() >= 2:
		pairs.append([idx.pop_back(), idx.pop_back()])
	if idx.size() == 1:
		var lone: int = idx.pop_back()
		pairs.append([lone, _ghost_for(lone)])
	current_pairs = pairs.duplicate(true)
	return pairs


## 유령 상대: 이미 탈락한 좌석 중 하나. 아무도 없으면 자기 자신(무승부 처리).
func _ghost_for(exclude: int) -> int:
	var dead: Array = []
	for s in seats:
		if not s.alive() and s.index != exclude:
			dead.append(s.index)
	if dead.is_empty():
		return exclude
	return dead[rng.randi_range(0, dead.size() - 1)]


## 한 쌍의 전투를 시뮬레이션한다. 사람 경기는 main이 직접 재생하므로 여기서는
## 시뮬만 만들어 돌려주는 용도로도 쓸 수 있다.
func build_sim(a: int, b: int) -> CombatSim:
	var pa := seats[a].player
	var pb := seats[b].player
	var ua: Array = []
	for u in pa.queued_units():
		var placement: Dictionary = u.duplicate()
		_apply_relic_modifiers(placement, pa.relics)
		_apply_tactic_modifiers(placement, pa.tactic)
		ua.append(placement)
	var ub: Array = []
	for u in pb.queued_units():
		ub.append(u.duplicate())
	return CombatSim.create(ua, ub, pa.level, pb.level)


func _apply_relic_modifiers(placement: Dictionary, relics: Array[String]) -> void:
	if relics.has("ember_cache"):
		placement["relic_hp_mult"] = 1.10
	if relics.has("signal_lens"):
		placement["relic_as_mult"] = 1.12
	if relics.has("hollow_crown"):
		placement["relic_atk_mult"] = 1.15


func _apply_tactic_modifiers(placement: Dictionary, tactic: String) -> void:
	if tactic == "압박":
		placement["tactic_atk_mult"] = 1.12
	elif tactic == "요새":
		placement["tactic_hp_mult"] = 1.15
		placement["tactic_as_mult"] = 0.92
	elif tactic == "순환":
		placement["tactic_hp_mult"] = 0.92
		placement["tactic_as_mult"] = 1.14


## 모든 짝의 전투를 즉시 계산하고 정산한다. skip_pair에 들어간 짝은
## (사람 경기처럼) 밖에서 이미 처리했다는 뜻이므로 건너뛴다.
func resolve_round(pairs: Array, precomputed: Dictionary = {}) -> void:
	last_results = []
	for pair in pairs:
		var a: int = pair[0]
		var b: int = pair[1]
		var res: Dictionary
		if precomputed.has(a):
			res = precomputed[a]
		elif a == b:
			# 상대가 없다. 그냥 넘어간다.
			res = {"winner": -1, "core_ratio": [1.0, 1.0], "survivors": [0, 0]}
		else:
			res = build_sim(a, b).run_to_end()

		var wa := -1
		if res["winner"] == 0:
			wa = 1
		elif res["winner"] == 1:
			wa = 0

		var ia := econ.settle(seats[a].player, wa,
			float(res["core_ratio"][0]), int(res["survivors"][1]), round_no)
		# 유령 상대는 정산하지 않는다 (이미 탈락했거나 자기 자신).
		var ib := {}
		if a != b and seats[b].alive():
			var wb := -1
			if wa == 1:
				wb = 0
			elif wa == 0:
				wb = 1
			ib = econ.settle(seats[b].player, wb,
				float(res["core_ratio"][1]), int(res["survivors"][0]), round_no)

		last_results.append({
			"a": a, "b": b, "winner_seat": (a if wa == 1 else (b if wa == 0 else -1)),
			"core_ratio": res["core_ratio"], "survivors": res["survivors"],
			"damage_a": int(ia.get("damage", 0)), "damage_b": int(ib.get("damage", 0)),
			"settle_a": ia, "settle_b": ib,
		})

	_assign_placements()
	for s in living_seats():
		econ.refresh_shop(s.player)
	round_no += 1


## 이번 라운드에 탈락한 좌석에 등수를 매긴다. 늦게 죽을수록 높은 등수.
func _assign_placements() -> void:
	var still := 0
	for s in seats:
		if s.alive():
			still += 1
	for s in seats:
		if not s.alive() and s.placement == 0:
			s.placement = still + 1


func is_over() -> bool:
	return living_seats().size() <= 1


## 순위표. 생존자는 체력 순, 탈락자는 등수 순.
func standings() -> Array:
	var out := seats.duplicate()
	out.sort_custom(func(x, y):
		if x.alive() != y.alive():
			return x.alive()
		if x.alive():
			return x.player.hp > y.player.hp
		return x.placement < y.placement)
	return out


## 사람의 최종 등수. 아직 살아 있으면 현재 생존자 수를 등수로 본다.
func human_placement() -> int:
	var h := human_seat()
	if h.placement > 0:
		return h.placement
	return living_seats().size()
