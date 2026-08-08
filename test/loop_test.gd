extends SceneTree

## 8인 매치 루프 측정. 전투가 아니라 "게임"이 성립하는지 본다.
## 특히 경제 운영(저축 vs 소비)이 진짜 선택지인지가 핵심 관심사다.
##   godot --headless --script res://test/loop_test.gd

const RUNS := 25
const MAX_ROUNDS := 40

var passed := 0
var failed := 0


func _initialize() -> void:
	print("=== OVERLINE 8인 매치 측정 (%d판) ===\n" % RUNS)
	var stats := _run_many()
	_report(stats)
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	quit(1 if failed > 0 else 0)


func ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [OK] %s" % label)
	else:
		failed += 1
		print("  [FAIL] %s %s" % [label, detail])


func _run_many() -> Dictionary:
	var match_lengths: Array = []
	var place_by_style := {AutoPlay.Style.SAVER: [], AutoPlay.Style.SPENDER: []}
	var per_round := {}
	var pool_drained: Array = []       ## 매치 끝에 바닥난 유닛 종류 수

	for run in RUNS:
		var m := Match.create(2000 + run, false)

		while not m.is_over() and m.round_no <= MAX_ROUNDS:
			var r := m.round_no
			m.run_ai_prep()

			if not per_round.has(r):
				per_round[r] = {"n": 0, "gold": 0.0, "hp": 0.0, "lv": 0.0,
					"last_at": 0.0, "alive": 0.0, "games": 0}
			var slot: Dictionary = per_round[r]
			slot["games"] += 1
			slot["alive"] += float(m.living_seats().size())
			for s in m.living_seats():
				slot["n"] += 1
				slot["gold"] += float(s.player.gold)
				slot["hp"] += float(s.player.hp)
				slot["lv"] += float(s.player.level)
				var sched := Econ.deploy_schedule(s.player.queued_units(), s.player.level)
				if not sched.is_empty():
					slot["last_at"] += float(sched[sched.size() - 1]["at"])

			m.resolve_round(m.pair_up())

		match_lengths.append(m.round_no - 1)
		for s in m.seats:
			var place: int = s.placement if s.placement > 0 else 1
			place_by_style[s.style].append(place)

		var drained := 0
		for id in m.econ.pool.remaining:
			if int(m.econ.pool.remaining[id]) <= 2:
				drained += 1
		pool_drained.append(drained)

	return {
		"lengths": match_lengths, "places": place_by_style,
		"per_round": per_round, "drained": pool_drained,
	}


func _report(stats: Dictionary) -> void:
	var per_round: Dictionary = stats["per_round"]
	print("[라운드별 곡선 — 생존자 평균]")
	print("    %-6s %-8s %-8s %-8s %-8s %-10s" % [
		"라운드", "생존자", "평균체력", "평균골드", "평균레벨", "마지막출격"])
	for r in range(1, MAX_ROUNDS + 1):
		if not per_round.has(r):
			continue
		var s: Dictionary = per_round[r]
		var n := float(s["n"])
		if n < 1.0:
			continue
		print("    %-6d %-8.2f %-8.1f %-8.1f %-8.2f %-10s" % [
			r, float(s["alive"]) / float(s["games"]),
			float(s["hp"]) / n, float(s["gold"]) / n, float(s["lv"]) / n,
			"%.1fs" % (float(s["last_at"]) / n),
		])

	var lengths: Array = stats["lengths"]
	print("\n[매치 길이]  평균 %.1f라운드   최소 %d   최대 %d" % [
		_avg(lengths), _min(lengths), _max(lengths)])

	var saver: Array = stats["places"][AutoPlay.Style.SAVER]
	var spender: Array = stats["places"][AutoPlay.Style.SPENDER]
	print("\n[성향별 평균 등수] (낮을수록 좋음, 1~8등)")
	print("    저축형 %.2f등  (%d명)" % [_avg(saver), saver.size()])
	print("    소비형 %.2f등  (%d명)" % [_avg(spender), spender.size()])

	var drained: Array = stats["drained"]
	print("\n[유닛 풀]  매치 종료 시 바닥난 유닛 종류 평균 %.1f / %d종" % [
		_avg(drained), UnitDB.table().size()])

	print("\n[판정]")
	ok(_avg(lengths) >= 12.0 and _avg(lengths) <= 38.0,
		"매치가 12~38라운드에서 끝난다", "%.1f" % _avg(lengths))
	ok(absf(_avg(saver) - _avg(spender)) <= 1.5,
		"저축형과 소비형의 평균 등수 차이가 1.5등 이내 (경제 운영이 진짜 선택지다)",
		"저축 %.2f 소비 %.2f" % [_avg(saver), _avg(spender)])

	# 기준은 이자 구간에 연동한다. 구간을 조정하면 판정도 따라와야 한다.
	var mid_gold := _round_avg(per_round, 8, 14, "gold")
	print("    중반 평균 보유 골드 %.1f -> 평균 이자 %.1f/라운드" % [
		mid_gold, minf(floorf(mid_gold / float(Econ.INTEREST_STEP)), float(Econ.MAX_INTEREST))])
	ok(mid_gold >= float(Econ.INTEREST_STEP),
		"중반 평균 보유 골드가 이자 구간 이상 (이자를 실제로 받는다)",
		"%.1f < %d" % [mid_gold, Econ.INTEREST_STEP])

	var last_at := _round_avg(per_round, 15, MAX_ROUNDS, "last_at")
	ok(last_at <= Defs.MAX_BATTLE_TIME * 0.95,
		"후반에도 큐 전원이 전투 시간 안에 출격한다", "%.1fs" % last_at)

	ok(_avg(drained) >= 1.0,
		"매치가 끝날 때 일부 유닛이 바닥난다 (풀 경쟁이 작동한다)", "%.1f" % _avg(drained))


func _round_avg(per_round: Dictionary, from_r: int, to_r: int, key: String) -> float:
	var v := 0.0
	var n := 0.0
	for r in range(from_r, to_r + 1):
		if not per_round.has(r):
			continue
		v += float(per_round[r][key])
		n += float(per_round[r]["n"])
	return 0.0 if n < 1.0 else v / n


func _avg(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var t := 0.0
	for x in arr:
		t += float(x)
	return t / float(arr.size())


func _min(arr: Array) -> int:
	var m: int = int(arr[0])
	for x in arr:
		m = mini(m, int(x))
	return m


func _max(arr: Array) -> int:
	var m: int = int(arr[0])
	for x in arr:
		m = maxi(m, int(x))
	return m
