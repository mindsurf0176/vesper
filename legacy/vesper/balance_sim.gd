extends Node
## 밸런스 시뮬레이터 — 봇이 유닛을 자동 배치하며 한 스테이지를 헤드리스로 완주.
## 사용: godot --headless res://balance_sim.tscn -- --stage N   (N=0..4)
## 결과 한 줄 출력: RESULT stage=N win=bool t=..s ally=..% enemy=..%

const CAP := 9
enum { ALLY, ENEMY }
enum { STRIKER, RANGER, DEFENDER, SNIPER, SUPPORT }

var battle
var reported := false
var t := 0.0
var run_stage := 0

func _ready() -> void:
	var stage := 0
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--stage" and i + 1 < args.size():
			stage = int(args[i + 1])
	seed(1000 + stage)
	# 실제 진행 상태 재현: 스테이지 N 진입 시 = 스테이지 0..N-1 클리어분만 해금
	# (--full 이면 전 캐릭터 = 최적 상한 측정)
	var full := "--full" in OS.get_cmdline_user_args()
	GameState.unlocked = GameState.START_UNLOCKED.duplicate()
	if full:
		GameState.unlocked = []
		for c in GameState.ALL_CHARS:
			GameState.unlocked.append(c["name"])
	else:
		for i in stage:  # 이전 스테이지들의 해금 보상 누적
			var reward: String = GameState.STAGES[i].get("unlock", "")
			if reward != "" and not GameState.unlocked.has(reward):
				GameState.unlocked.append(reward)
	# 편성: 해금분 중 SQUAD_MAX까지(카탈로그 순서)
	GameState.squad = []
	for c in GameState.ALL_CHARS:
		if GameState.unlocked.has(c["name"]) and GameState.squad.size() < GameState.SQUAD_MAX:
			GameState.squad.append(c["name"])
	GameState.current_stage = stage
	run_stage = stage
	# 속도: --fixed-fps 로 벽시계 분리, CPU 최대 속도 시뮬(헤드리스 무렌더)
	battle = load("res://battle3d.tscn").instantiate()
	battle.simulation_mode = true
	add_child(battle)
	battle.from_run = false   # 시뮬: 진행 저장·스테이지 전진 억제(공유 세이브 오염 방지)

func _process(delta: float) -> void:
	t += delta
	if battle == null:
		return
	if not reported and battle.ended:
		reported = true
		var win: bool = battle.enemy_hp <= 0.0
		var ap: float = 100.0 * battle.ally_hp / battle.ally_hp_max
		var ep: float = 100.0 * battle.enemy_hp / battle.enemy_hp_max
		print("RESULT stage=%d win=%s t=%.1f ally=%.0f enemy=%.0f soshin=%d" % [
			run_stage, str(win), battle.elapsed, ap, ep, battle.soshin_count])
		_finish()
		return
	if battle.ended or not battle.running:
		return
	_bot()
	# 안전장치: 게임내 120초까지 미결이면 교착으로 판정(웨이브 최대 57초 + 정리 여유)
	if battle.elapsed > 120.0:
		print("RESULT stage=%d win=stalemate t=%.1f ally=%.0f enemy=%.0f soshin=%d" % [
			run_stage, battle.elapsed,
			100.0 * battle.ally_hp / battle.ally_hp_max, 100.0 * battle.enemy_hp / battle.enemy_hp_max, battle.soshin_count])
		_finish()

func _finish() -> void:
	if battle != null and is_instance_valid(battle):
		battle.set_process(false)
		battle.queue_free()
	battle = null
	set_process(false)
	call_deferred("_quit_after_cleanup")

func _quit_after_cleanup() -> void:
	await get_tree().process_frame
	get_tree().quit()

func _bot() -> void:
	# 살아있는 디펜더 여부
	var has_def := false
	for u in battle.units:
		if not u.dead and u.team == ALLY and u.utype == DEFENDER:
			has_def = true
			break
	# 배치: 디펜더 우선(없으면), 그 외 저코스트 우선
	if battle.ally_count() < CAP:
		var best_slot := -1
		var best_pri := 9999.0
		for slot in battle.hand_indices.size():
			var deck_idx: int = int(battle.hand_indices[slot])
			var d: Dictionary = battle.DECK[deck_idx]
			if battle.card_cd[deck_idx] > 0.0:
				continue
			if battle.cost < battle._card_cost(d):
				continue
			var pri: float = _deploy_priority(d, has_def)
			if not has_def and d["type"] == DEFENDER:
				pri = -100.0
			if pri < best_pri:
				best_pri = pri
				best_slot = slot
		if best_slot >= 0:
			battle._deploy_card_slot(best_slot, battle.deployment_max_x())
	# 오브: 해금된 스테이지에서는 살아있는 아군 역할의 인접 4/2/1오브를 자동 발동한다.
	if battle.has_method("_tutorial_enabled") and battle._tutorial_enabled("orbs"):
		_cast_best_orb()
	# 소신: 코스트 고갈 + 아군 코어 여유 + 좌측에 적 압박이 있을 때(궁지 판단)
	var ally_pct: float = 100.0 * battle.ally_hp / battle.ally_hp_max
	# --aggro: 공격적 소신(코스트 고갈+안전마진이면 밀어붙임). 기본: 좌측 압박일 때만.
	var aggro := "--aggro" in OS.get_cmdline_user_args()
	if battle.soshin_cd <= 0.0 and ally_pct > 26.0:
		if aggro and battle.cost < 3.0:
			battle._on_soshin()
		elif battle.cost < 2.0:
			var pressing := 0
			for u in battle.units:
				if not u.dead and u.team == ENEMY and u.position.x < 0.0:
					pressing += 1
			if pressing >= 1:
				battle._on_soshin()
	# 궤도 폭격: 쿨 돌면 적이 우측에 있을 때
	if battle.skill_cd <= 0.0:
		var pushed := 0
		for u in battle.units:
			if not u.dead and u.team == ENEMY and u.position.x > 0.0:
				pushed += 1
		if pushed >= 2:
			battle._on_skill()

func _deploy_priority(d: Dictionary, has_def: bool) -> float:
	var c: float = battle._card_cost(d)
	var role: int = int(d["type"])
	if not has_def and role == DEFENDER:
		return -100.0
	if role == SUPPORT:
		return -20.0 if _has_wounded_front() else 12.0
	var dmg: float = float(d.get("dmg", 0.0))
	var score: float = dmg / max(1.0, c)
	if role == SNIPER:
		score += 2.0
	elif role == RANGER:
		score += 1.0
	elif role == STRIKER:
		score += 0.5
	return -score

func _has_wounded_front() -> bool:
	for u in battle.units:
		if not u.dead and u.team == ALLY and u.utype != SUPPORT and u.hp < u.max_hp * 0.65:
			return true
	return false

func _cast_best_orb() -> bool:
	if battle.selected_orbs.size() > 0:
		battle.selected_orbs.clear()
	var alive_roles := {}
	for u in battle.units:
		if not u.dead and u.team == ALLY:
			alive_roles[u.utype] = true
	var patterns := _orb_patterns()
	var best_pattern: Array = []
	var best_score := -9999.0
	for pattern in patterns:
		if pattern.is_empty():
			continue
		var role: int = battle._orb_role(int(pattern[0]))
		if not alive_roles.has(role):
			continue
		var score := float(pattern.size()) * 10.0
		for idx in pattern:
			var state: int = battle._orb_state(int(idx))
			if state == battle.ORB_ENHANCED:
				score += 4.0
			elif state == battle.ORB_CORRUPTED:
				score -= 6.0
		if score > best_score:
			best_score = score
			best_pattern = pattern
	if best_pattern.is_empty():
		return false
	battle.selected_orbs = best_pattern.duplicate()
	return battle._resolve_orb_selection()

func _orb_patterns() -> Array:
	var out := []
	for target_len in [4, 2, 1]:
		for i in battle.command_orbs.size():
			var role: int = battle._orb_role(i)
			var path := _orb_path_from(i, role, target_len)
			if path.size() == target_len:
				out.append(path)
	return out

func _orb_path_from(start: int, role: int, target_len: int) -> Array:
	var path: Array = [start]
	var used := { start: true }
	while path.size() < target_len:
		var next := _best_orb_neighbor(path, used, role)
		if next < 0:
			break
		path.append(next)
		used[next] = true
	return path

func _best_orb_neighbor(path: Array, used: Dictionary, role: int) -> int:
	var best := -1
	var best_score := -9999.0
	for existing in path:
		var idx: int = int(existing)
		var row: int = idx / battle.ORB_COLS
		var col: int = idx % battle.ORB_COLS
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nr: int = row + dir.y
			var nc: int = col + dir.x
			if nr < 0 or nr >= battle.ORB_ROWS or nc < 0 or nc >= battle.ORB_COLS:
				continue
			var ni: int = nr * battle.ORB_COLS + nc
			if used.has(ni) or battle._orb_role(ni) != role:
				continue
			var score := 1.0
			var state: int = battle._orb_state(ni)
			if state == battle.ORB_ENHANCED:
				score += 4.0
			elif state == battle.ORB_CORRUPTED:
				score -= 6.0
			if score > best_score:
				best_score = score
				best = ni
	return best
