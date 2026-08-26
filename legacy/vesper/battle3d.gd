extends Node2D
## 베스퍼 회랑 — 2D 픽셀 라인 전투. 규칙은 LineBattle, 렌더링은 CanvasItem이 담당한다.

const Unit2D = preload("res://legacy/vesper/unit2d.gd")
const LineBattle = preload("res://core/line_battle.gd")
const PixelFx2D = preload("res://legacy/vesper/pixel_fx_2d.gd")

const W := 1280.0
const H := 720.0
const ALLY_X := -8.5
const ENEMY_X := 8.5
const CAP := 9
const COST_MAX := 10.0
const COST_REGEN := 0.50   # 코스트 경제 조임 — 소신(HP↔코스트) 유혹 활성화
const HAND_SIZE := 4
const DEPLOY_MIN_X := ALLY_X + 0.9
const DEPLOY_START_MAX_X := ALLY_X + 2.4
const DEPLOY_FRONT_MARGIN := 1.35
const DEPLOY_WORLD_MAX_X := 3.8
const SPAWN_X_AUTO := 99999.0
const ORB_ROWS := 2
const ORB_COLS := 8
const ORB_COUNT := ORB_ROWS * ORB_COLS
const ORB_MAX_SELECT := 4
const ORB_NORMAL := 0
const ORB_ENHANCED := 1
const ORB_CORRUPTED := 2

enum { ALLY, ENEMY }
enum { STRIKER, RANGER, DEFENDER, SNIPER, SUPPORT }

const AMBER := Color(1.0, 0.74, 0.36)
const CYAN := Color(0.36, 0.86, 0.92)
const C_STRIKER := Color(0.92, 0.47, 0.42)
const C_RANGER := Color(0.42, 0.82, 0.86)
const C_DEFENDER := Color(0.55, 0.62, 0.92)
const C_SNIPER := Color(0.92, 0.68, 0.98)
const C_SUPPORT := Color(0.58, 0.86, 0.56)
const TYPE_COL := { STRIKER: C_STRIKER, RANGER: C_RANGER, DEFENDER: C_DEFENDER, SNIPER: C_SNIPER, SUPPORT: C_SUPPORT }
const TYPE_GLYPH := { STRIKER: "S", RANGER: "R", DEFENDER: "D", SNIPER: "N", SUPPORT: "+" }

# 덱/적/웨이브는 GameState(오토로드)에서 주입. 하네스·단독 실행 폴백은 _apply_config에서.
var DECK: Array = []
var EDEF: Dictionary = {}
var WAVES: Array = []
var ship_contract: Dictionary = {}
var command_skill: Dictionary = {}
var last_stand_contract: Dictionary = {}
var tutorial_contract: Dictionary = {}
var leader_cost_discount := 1.0
var from_run := false   # 편성→전투로 진입한 실제 런인가(결과 라우팅·진행저장 게이트)
var simulation_mode := false

var font: Font
var cam = null
var world_root: Node2D
var blob_tex: ImageTexture
var _tcache := {}
var units: Array = []
var running := true
var ended := false
var paused_by_player := false

var cost := 3.0
var ally_hp := 1000.0
var ally_hp_max := 1000.0
var enemy_hp := 520.0
var enemy_hp_max := 520.0
var elapsed := 0.0
var wave_idx := 0
var soshin_cd := 0.0
var skill_cd := 0.0
var card_cd: Array = []
var hand_indices: Array = []
var draw_cursor := 0
var core_dim := 0.0
var core_invuln := 0.0
var last_stand_ready := false
var last_stand_used := false
var last_stand_armed := false
var lamp_mat = null
var trauma := 0.0
var cam_base := Vector3.ZERO
var _hs_count := 0

var roster_names := ["하준", "서연", "도윤", "지우", "민재", "수아", "은우", "예린", "현성", "다은", "태경", "소율"]
var roster_struck := 0
var soshin_count := 0
var mangja_burned := 0
var max_unused_cost := 0.0
var used_defender := false
var ranged_deaths := 0
var retreat_cause := ""
var deploy_feedback := ""
var deploy_feedback_time := 0.0
var cap_blocked_attempts := 0
var battle_feedback: Dictionary = {}
var combat_audio_cooldowns: Dictionary = {}
var pending_card_slot := -1
var command_orbs: Array = []
var selected_orbs: Array = []
var line_core
var line_core_mode := true
var core_visuals: Dictionary = {}

var ui: CanvasLayer
var overlay: Node2D
var card_btns: Array = []
var orb_btns: Array = []
var orb_cast_btn: Button
var soshin_btn: Button
var skill_btn: Button
var retreat_btn: Button
var pause_btn: Button
var pause_panel: Control

func _ready() -> void:
	_apply_config()
	line_core = LineBattle.new(enemy_hp, ally_hp_max)
	font = load("res://assets/Galmuri11.ttf")
	blob_tex = _make_blob_tex()
	card_cd.resize(DECK.size())
	for i in card_cd.size(): card_cd[i] = 0.0
	_init_hand()
	_init_command_orbs()
	_build_world()
	_build_ui()
	_show_tutorial_hint()
	set_process(true)

# 스테이지·편성을 GameState에서 주입. 편성 미설정(단독/하네스)이면 전체 덱 + 스테이지0 폴백.
func _apply_config() -> void:
	EDEF = GameState.ENEMY_DEFS
	ship_contract = GameState.ship_contract()
	command_skill = ship_contract.get("command_skill", {}).duplicate(true)
	last_stand_contract = ship_contract.get("last_stand", {}).duplicate(true)
	leader_cost_discount = float(ship_contract.get("leader_cost_discount", 1.0))
	if GameState.squad.size() > 0:
		DECK = GameState.squad_defs()
		from_run = true
	else:
		DECK = GameState.all_chars_list()
		if DECK.size() > 0:
			DECK[0]["leader"] = true
		from_run = false
	var st := GameState.current_stage_def()
	tutorial_contract = st.get("tutorial", {}).duplicate(true) if from_run else {}
	WAVES = st["waves"]
	enemy_hp = float(st["enemy_hp"]); enemy_hp_max = enemy_hp
	ally_hp = float(ship_contract.get("hp", GameState.ALLY_CORE_HP)); ally_hp_max = ally_hp

# ---------- 규칙(이식) ----------
func type_mult(a: int, b: int) -> float:
	if (a == STRIKER and b == RANGER) or (a == RANGER and b == DEFENDER) or (a == DEFENDER and b == SNIPER) or (a == SNIPER and b == STRIKER):
		return 1.5
	if (b == STRIKER and a == RANGER) or (b == RANGER and a == DEFENDER) or (b == DEFENDER and a == SNIPER) or (b == SNIPER and a == STRIKER):
		return 0.66
	return 1.0

func ally_count() -> int:
	var n := 0
	for u in units:
		if not u.dead and u.team == ALLY: n += 1
	return n

func damage_core(by_team: int, amount: float) -> void:
	if by_team == ALLY:
		enemy_hp = max(0.0, enemy_hp - amount)
		if line_core != null:
			line_core.enemy_core_hp = enemy_hp
	else:
		if core_invuln > 0.0:
			return
		ally_hp = max(0.0, ally_hp - amount)
		if line_core != null:
			line_core.ally_core_hp = ally_hp
		var threshold: float = float(last_stand_contract.get("threshold", 0.25))
		if _tutorial_enabled("last_stand") and not last_stand_armed and not last_stand_used and ally_hp <= ally_hp_max * threshold:
			last_stand_armed = true
			last_stand_ready = true
			ally_hp = max(ally_hp, ally_hp_max * float(last_stand_contract.get("floor", 0.20)))
			core_invuln = float(last_stand_contract.get("auto_barrier", 2.5))
			core_dim = 1.0
			var label: String = str(last_stand_contract.get("label", "최후 신호"))
			_set_deploy_feedback("%s 해금  ·  오른쪽 버튼으로 전선을 밀어내세요" % label, 4.0)
			float_world("%s 준비" % label, Vector3(ALLY_X + 2.2, 2.8, 0), AMBER)
			_combat_audio("last_stand", { "phase": "ready" }, 1.0)
			shake(0.55)
		else:
			_combat_audio("core_hit", { "amount": amount }, 0.85)

func on_death(u) -> void:
	units.erase(u)
	if u.team == ALLY and (u.utype == RANGER or u.utype == SNIPER or u.utype == SUPPORT):
		ranged_deaths += 1

# ---------- 스폰 ----------
func _spawn(def: Dictionary, team: int, spawn_x := SPAWN_X_AUTO, register_core := true):
	var u := Unit2D.new()
	var unit_def := _with_unit_visual(def, team)
	u.setup(self, team, unit_def, _soldier_tex(int(unit_def["type"]), team, unit_def.get("visual", {})))
	var x: float = spawn_x if spawn_x != SPAWN_X_AUTO else (ALLY_X + 1.4 if team == ALLY else ENEMY_X - 1.4)
	u.position = Vector2(x, randf_range(-0.10, 0.10))
	u.manual_simulation = line_core_mode
	units.append(u)
	world_root.add_child(u)
	if line_core_mode and register_core:
		var core_uid: int = line_core.spawn_enemy(unit_def, _core_x_from_world(x)) if team == ENEMY else line_core.deploy(unit_def, _core_x_from_world(x))
		if core_uid > 0:
			core_visuals[core_uid] = u
	return u

func _spawn_ally(def: Dictionary, spawn_x := SPAWN_X_AUTO, register_core := true):
	var x: float = spawn_x if spawn_x != SPAWN_X_AUTO else ALLY_X + 1.4
	var visual = _spawn(def, ALLY, x, register_core)
	float_world(def["name"], Vector3(x, 1.9, 0), AMBER)
	return visual

func _with_unit_visual(def: Dictionary, team: int) -> Dictionary:
	var out := def.duplicate(true)
	if not out.has("visual"):
		out["visual"] = GameState.battle_visual_for(str(out.get("name", "")), int(out.get("type", STRIKER)), team == ENEMY)
	return out

func deployment_min_x() -> float:
	return DEPLOY_MIN_X

func deployment_max_x() -> float:
	var front := DEPLOY_START_MAX_X
	for u in units:
		if not u.dead and u.team == ALLY:
			front = max(front, u.position.x + DEPLOY_FRONT_MARGIN)
	var enemy_block := ENEMY_X - 1.2
	for u in units:
		if not u.dead and u.team == ENEMY:
			enemy_block = min(enemy_block, u.position.x - 0.9)
	return max(DEPLOY_MIN_X, min(min(front, enemy_block), DEPLOY_WORLD_MAX_X))

func clamp_deploy_x(world_x: float) -> float:
	return clamp(world_x, deployment_min_x(), deployment_max_x())

func _init_hand() -> void:
	hand_indices.clear()
	if DECK.is_empty():
		draw_cursor = 0
		return
	var visible: int = min(HAND_SIZE, DECK.size())
	for i in visible:
		hand_indices.append(i)
	draw_cursor = visible % DECK.size()

func _advance_hand(slot: int) -> void:
	if DECK.size() <= HAND_SIZE or slot < 0 or slot >= hand_indices.size():
		return
	hand_indices[slot] = draw_cursor
	draw_cursor = (draw_cursor + 1) % DECK.size()
	_refresh_card_button(slot)

func _init_command_orbs() -> void:
	command_orbs.clear()
	selected_orbs.clear()
	for i in ORB_COUNT:
		command_orbs.append(_make_orb(i))

func _next_orb_role(seed: int) -> int:
	return [STRIKER, RANGER, DEFENDER, SNIPER, SUPPORT][seed % 5]

func _next_orb_state(seed: int) -> int:
	if seed % 11 == 0:
		return ORB_CORRUPTED
	if seed % 5 == 0:
		return ORB_ENHANCED
	return ORB_NORMAL

func _make_orb(seed: int, forced_role := -1, forced_state := -1) -> Dictionary:
	var role: int = _next_orb_role(seed) if forced_role < 0 else forced_role
	var state: int = _next_orb_state(seed) if forced_state < 0 else forced_state
	return { "role": role, "state": state }

func _orb_role(idx: int) -> int:
	if idx < 0 or idx >= command_orbs.size():
		return STRIKER
	return int(command_orbs[idx].get("role", STRIKER))

func _orb_state(idx: int) -> int:
	if idx < 0 or idx >= command_orbs.size():
		return ORB_NORMAL
	return int(command_orbs[idx].get("state", ORB_NORMAL))

func _orb_color(role: int) -> Color:
	return TYPE_COL.get(role, Color(0.72, 0.74, 0.78))

func _orb_label(role: int, state := ORB_NORMAL) -> String:
	var glyph: String = TYPE_GLYPH.get(role, "?")
	if state == ORB_ENHANCED:
		return glyph + "*"
	if state == ORB_CORRUPTED:
		return glyph + "!"
	return glyph

func _card_block_reason(slot: int) -> String:
	if not running:
		return "전투 종료"
	if slot < 0 or slot >= hand_indices.size():
		return "없는 카드 슬롯"
	var deck_idx: int = int(hand_indices[slot])
	var def: Dictionary = DECK[deck_idx]
	if ally_count() >= CAP:
		cap_blocked_attempts += 1
		return "전선 포화  %d / %d  ·  병력이 쓰러지면 재배치" % [CAP, CAP]
	if card_cd[deck_idx] > 0.0:
		return "%s 재배치까지 %.1f초" % [def["name"], card_cd[deck_idx]]
	var need: float = _card_cost(def)
	if cost < need:
		return "코스트 부족  ·  C%d 필요" % int(need)
	return ""

func _card_cost(def: Dictionary) -> float:
	var base_cost: float = float(def["cost"])
	if bool(def.get("leader", false)):
		return max(1.0, base_cost - leader_cost_discount)
	return base_cost

func _tutorial_enabled(key: String) -> bool:
	return bool(tutorial_contract.get(key, true))

func _tutorial_title() -> String:
	return str(tutorial_contract.get("title", ""))

func _tutorial_hint() -> String:
	return str(tutorial_contract.get("hint", ""))

func _show_tutorial_hint() -> void:
	var hint := _tutorial_hint()
	if hint != "":
		_set_deploy_feedback("%s  ·  %s" % [_tutorial_title(), hint], 6.0)

func _on_card(slot: int) -> void:
	var reason := _card_block_reason(slot)
	if reason != "":
		_set_deploy_feedback(reason)
		return
	if not _tutorial_enabled("deploy_position"):
		_deploy_card_slot(slot, DEPLOY_START_MAX_X)
		return
	pending_card_slot = slot
	var deck_idx: int = int(hand_indices[slot])
	var def: Dictionary = DECK[deck_idx]
	_set_deploy_feedback("%s 배치 위치 지정  ·  전장 왼쪽 빛 영역을 클릭" % def["name"], 3.2)

func _deploy_card_slot(slot: int, world_x := SPAWN_X_AUTO) -> bool:
	var reason := _card_block_reason(slot)
	if reason != "":
		_set_deploy_feedback(reason)
		return false
	var deck_idx: int = int(hand_indices[slot])
	var def: Dictionary = DECK[deck_idx]
	var spawn_x := clamp_deploy_x(world_x if world_x != SPAWN_X_AUTO else deployment_max_x())
	var core_uid := -1
	if line_core_mode:
		# LineBattle은 순수 코어라 화면의 리더 계약을 알 수 없다.
		# 배치 직전에 유효 비용을 주입해 UI·코어·실제 차감을 일치시킨다.
		line_core.cost = cost
		var core_def := def.duplicate(true)
		core_def["cost"] = _card_cost(def)
		core_uid = line_core.deploy(core_def, _core_x_from_world(spawn_x))
		if core_uid < 0:
			_set_deploy_feedback("라인 코어가 소환을 거부했습니다")
			return false
		cost = line_core.cost
	else:
		cost -= _card_cost(def)
	card_cd[deck_idx] = float(def["cd"])
	if def["type"] == DEFENDER: used_defender = true
	var visual = _spawn_ally(def, spawn_x, not line_core_mode)
	if line_core_mode:
		core_visuals[core_uid] = visual
	_combat_audio("deploy", { "unit": str(def.get("name", "")) }, 0.12)
	if _tutorial_enabled("hand_cycle"):
		_advance_hand(slot)
	pending_card_slot = -1
	_set_deploy_feedback("%s 배치  ·  x %.1f  ·  전선 %d / %d" % [def["name"], spawn_x, ally_count(), CAP], 0.9)
	return true

func _core_x_from_world(world_x: float) -> float:
	return clampf((world_x - ALLY_X) / (ENEMY_X - ALLY_X) * LineBattle.FIELD_LENGTH, 1.0, 45.0)

func _alive_ally_of_role(role: int):
	var best = null
	var best_x := -999.0
	for u in units:
		if u.dead or u.team != ALLY or u.utype != role:
			continue
		if u.position.x > best_x:
			best_x = u.position.x
			best = u
	return best

func _front_enemy():
	var best = null
	var best_x := 999.0
	for u in units:
		if u.dead or u.team != ENEMY:
			continue
		if u.position.x < best_x:
			best_x = u.position.x
			best = u
	return best

func _weakest_enemy():
	var best = null
	var best_hp := 999999.0
	for u in units:
		if u.dead or u.team != ENEMY:
			continue
		if u.hp < best_hp:
			best_hp = u.hp
			best = u
	return best

func _wounded_ally():
	var best = null
	var best_ratio := 1.01
	for u in units:
		if u.dead or u.team != ALLY:
			continue
		var ratio: float = u.hp / u.max_hp
		if ratio < best_ratio:
			best_ratio = ratio
			best = u
	return best

func _on_orb_button(idx: int) -> void:
	if not _tutorial_enabled("orbs"):
		_set_deploy_feedback("오브는 ST3에서 해금됩니다")
		return
	if not running or idx < 0 or idx >= command_orbs.size():
		return
	if pending_card_slot >= 0:
		_set_deploy_feedback("배치 위치를 먼저 지정하세요")
		return
	var role: int = _orb_role(idx)
	if selected_orbs.has(idx):
		selected_orbs.erase(idx)
		_refresh_orb_buttons()
		return
	if not selected_orbs.is_empty() and _orb_role(int(selected_orbs[0])) != role:
		selected_orbs.clear()
	if not selected_orbs.is_empty() and not _is_adjacent_to_selection(idx):
		_set_deploy_feedback("오브는 같은 색 인접 칸으로만 이어서 선택")
		return
	if selected_orbs.size() >= ORB_MAX_SELECT:
		selected_orbs.clear()
	selected_orbs.append(idx)
	_refresh_orb_buttons()

func _is_adjacent_to_selection(idx: int) -> bool:
	var row: int = idx / ORB_COLS
	var col: int = idx % ORB_COLS
	for selected in selected_orbs:
		var sidx: int = int(selected)
		var srow: int = sidx / ORB_COLS
		var scol: int = sidx % ORB_COLS
		if abs(row - srow) + abs(col - scol) == 1:
			return true
	return false

func _on_orb_cast() -> void:
	if not _tutorial_enabled("orbs"):
		_set_deploy_feedback("오브는 ST3에서 해금됩니다")
		return
	if pending_card_slot >= 0:
		_set_deploy_feedback("배치 위치를 먼저 지정하세요")
		return
	if selected_orbs.size() == 1 or selected_orbs.size() == 2 or selected_orbs.size() == 4:
		_combat_audio("orb_cast", { "count": selected_orbs.size() }, 0.22)
	_resolve_orb_selection()

func _resolve_orb_selection() -> bool:
	if selected_orbs.is_empty():
		return false
	var count: int = selected_orbs.size()
	if count != 1 and count != 2 and count != 4:
		_set_deploy_feedback("오브는 1 / 2 / 4개 패턴으로만 발동")
		return false
	var role: int = _orb_role(int(selected_orbs[0]))
	var caster = _alive_ally_of_role(role)
	if caster == null:
		_set_deploy_feedback("%s 역할 유닛이 전장에 없어 발동 실패" % _orb_label(role))
		selected_orbs.clear()
		_refresh_orb_buttons()
		return false
	if line_core_mode:
		line_core.cost = cost
		line_core.ally_core_hp = ally_hp
		line_core.enemy_core_hp = enemy_hp
		var enhanced := _selected_enhanced_count()
		var corrupted := _selected_corrupted_count()
		if not line_core.cast_orb(role, count, 1.0 + enhanced * 0.35):
			_set_deploy_feedback("오브 명령을 실행할 전장 유닛이 없습니다")
			selected_orbs.clear()
			_refresh_orb_buttons()
			return false
		if corrupted > 0:
			# 오염 반동은 Vesper의 코어 위기/최후 신호 계약을 거쳐야 한다.
			damage_core(LineBattle.ENEMY, 18.0 * corrupted)
			line_core.ally_core_hp = ally_hp
		var orb_snapshot: Dictionary = line_core.snapshot()
		cost = float(orb_snapshot["cost"])
		ally_hp = float(orb_snapshot["ally_core_hp"])
		enemy_hp = float(orb_snapshot["enemy_core_hp"])
		_sync_core_visuals(orb_snapshot)
		_consume_line_core_events()
		_consume_selected_orbs()
		_set_deploy_feedback("%s %d오브 발동" % [_orb_label(role), count], 1.4)
		return true
	_cast_orb_skill(caster, role, count)
	_consume_selected_orbs()
	return true

func _consume_selected_orbs() -> void:
	selected_orbs.sort()
	for idx in selected_orbs:
		command_orbs[int(idx)] = _make_orb(int(idx) + int(elapsed * 10.0) + soshin_count + mangja_burned + 1)
	selected_orbs.clear()
	_refresh_orb_buttons()

func _cast_orb_skill(caster, role: int, count: int) -> void:
	var skill: Dictionary = _caster_orb_skill(caster, count)
	if not skill.is_empty():
		_cast_character_orb_skill(caster, role, count, skill)
		return
	var scale: float = [0.0, 1.0, 2.15, 0.0, 4.4][count] + _selected_enhanced_count() * 0.65
	var corrupted: int = _selected_corrupted_count()
	if corrupted > 0:
		damage_core(ENEMY, 18.0 * corrupted)
		core_dim = 1.0
	match role:
		STRIKER:
			var target = _front_enemy()
			var amount: float = 18.0 * scale
			if target != null:
				target.take_damage(amount, 1.0)
				spark(target.top_world(), TYPE_COL[role])
			else:
				damage_core(ALLY, amount * 0.45)
			float_world("%d오브 돌파" % count, caster.top_world(), TYPE_COL[role])
		RANGER:
			var target = _weakest_enemy()
			var amount: float = 16.0 * scale
			if target != null:
				target.take_damage(amount, 1.0)
				spark(target.top_world(), TYPE_COL[role])
			else:
				damage_core(ALLY, amount * 0.55)
			float_world("%d오브 조준" % count, caster.top_world(), TYPE_COL[role])
		SNIPER:
			var target = _weakest_enemy()
			var amount: float = 22.0 * scale
			if target != null:
				var hp_ratio: float = target.hp / target.max_hp
				var exec_mult: float = 1.65 if hp_ratio <= 0.40 else 1.0
				target.take_damage(amount * exec_mult, exec_mult)
				spark(target.top_world(), TYPE_COL[role])
			else:
				damage_core(ALLY, amount * 0.62)
			float_world("%d오브 처형" % count, caster.top_world(), TYPE_COL[role])
		DEFENDER:
			var guard: float = 0.45 + count * 0.45
			core_invuln = max(core_invuln, guard)
			for u in units.duplicate():
				if u.dead or u.team != ENEMY:
					continue
				u.position.x = min(ENEMY_X - 0.7, u.position.x + 0.35 * count)
			float_world("%d오브 봉쇄" % count, caster.top_world(), TYPE_COL[role])
		SUPPORT:
			var target = _wounded_ally()
			var amount: float = 12.0 * scale
			if target != null:
				target.recv_heal(amount)
				float_world("+%d" % int(amount), target.top_world(), TYPE_COL[role])
			cost = min(COST_MAX, cost + 0.25 * count)
			float_world("%d오브 집전" % count, caster.top_world(), TYPE_COL[role])
	shake(0.08 * count)
	var suffix: String = "  ·  오염 반동 %d" % corrupted if corrupted > 0 else ""
	_set_deploy_feedback("%s %d오브 발동%s" % [_orb_label(role), count, suffix], 1.4)

func _caster_orb_skill(caster, count: int) -> Dictionary:
	if caster == null:
		return {}
	var skills: Dictionary = caster.orb_skills
	return skills.get(str(count), {}).duplicate(true)

func _cast_character_orb_skill(caster, role: int, count: int, skill: Dictionary) -> void:
	var enhanced: int = _selected_enhanced_count()
	var corrupted: int = _selected_corrupted_count()
	var mult: float = 1.0 + enhanced * 0.35
	if corrupted > 0:
		damage_core(ENEMY, 18.0 * corrupted)
		core_dim = 1.0
	var kind: String = str(skill.get("kind", ""))
	var amount: float = float(skill.get("amount", 0.0)) * mult
	match kind:
		"damage_front":
			var target = _front_enemy()
			if target != null:
				target.take_damage(amount, 1.0)
				_push_enemy(target, float(skill.get("push", 0.0)))
				spark(target.top_world(), TYPE_COL[role])
			else:
				damage_core(ALLY, amount * 0.45)
		"damage_weakest":
			var target = _weakest_enemy()
			if target != null:
				target.take_damage(amount, 1.0)
				spark(target.top_world(), TYPE_COL[role])
			else:
				damage_core(ALLY, amount * 0.55)
		"execute_weakest":
			var target = _weakest_enemy()
			if target != null:
				var hp_ratio: float = target.hp / target.max_hp
				var exec_mult: float = 1.75 if hp_ratio <= float(skill.get("execute", 0.35)) else 1.0
				target.take_damage(amount * exec_mult, exec_mult)
				spark(target.top_world(), TYPE_COL[role])
			else:
				damage_core(ALLY, amount * 0.55)
		"guard_push":
			core_invuln = max(core_invuln, float(skill.get("guard", 0.0)) * mult)
			for u in units.duplicate():
				if u.dead or u.team != ENEMY:
					continue
				_push_enemy(u, float(skill.get("push", 0.0)) * mult)
				var splash: float = float(skill.get("damage", 0.0)) * mult
				if splash > 0.0:
					u.take_damage(splash, 1.0)
		"heal_weakest":
			var target = _wounded_ally()
			if target != null:
				target.recv_heal(amount)
				float_world("+%d" % int(amount), target.top_world(), TYPE_COL[role])
			core_invuln = max(core_invuln, float(skill.get("guard", 0.0)) * mult)
	cost = min(COST_MAX, cost + float(skill.get("cost", 0.0)) * mult)
	float_world("%d오브 · %s" % [count, str(skill.get("label", caster.uname))], caster.top_world(), TYPE_COL[role])
	shake(0.08 * count)
	var suffix: String = "  ·  오염 반동 %d" % corrupted if corrupted > 0 else ""
	_set_deploy_feedback("%s %d오브  ·  %s%s" % [_orb_label(role), count, str(skill.get("label", caster.uname)), suffix], 1.4)

func _push_enemy(target, amount: float) -> void:
	if target == null or amount <= 0.0:
		return
	target.position.x = min(ENEMY_X - 0.7, target.position.x + amount)

func _selected_enhanced_count() -> int:
	var n := 0
	for idx in selected_orbs:
		if _orb_state(int(idx)) == ORB_ENHANCED:
			n += 1
	return n

func _selected_corrupted_count() -> int:
	var n := 0
	for idx in selected_orbs:
		if _orb_state(int(idx)) == ORB_CORRUPTED:
			n += 1
	return n

func _world_x_from_screen(screen_pos: Vector2) -> float:
	return clampf((screen_pos.x - W * 0.5) / 50.0, DEPLOY_MIN_X, DEPLOY_WORLD_MAX_X)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if paused_by_player:
		return
	if pending_card_slot < 0 or ended or not _tutorial_enabled("deploy_position"):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_deploy_card_slot(pending_card_slot, _world_x_from_screen(event.position))
		get_viewport().set_input_as_handled()

func _set_deploy_feedback(message: String, duration := 2.8) -> void:
	deploy_feedback = message
	deploy_feedback_time = duration

func _on_soshin() -> void:
	if not _tutorial_enabled("soshin"):
		_set_deploy_feedback("소신은 ST5에서 해금됩니다")
		return
	if not running or soshin_cd > 0.0: return
	if line_core_mode:
		line_core.cost = cost
		line_core.ally_core_hp = ally_hp
		if not line_core.use_soshin():
			_set_deploy_feedback("등불이 더는 태울 수 없습니다")
			return
		cost = line_core.cost
		ally_hp = line_core.ally_core_hp
		soshin_count += 1
		soshin_cd = 4.0
		core_dim = 1.0
		_set_deploy_feedback("소신  ·  코스트 +3  ·  등불함 HP -70", 2.4)
		_combat_audio("soshin", {}, 1.0)
		return
	var floor_hp := ally_hp_max * 0.12
	if ally_hp <= floor_hp: return
	var burn: float = min(ally_hp - floor_hp, ally_hp_max * 0.08)
	ally_hp -= burn
	cost = min(COST_MAX, cost + 3.0)
	soshin_cd = 4.0
	soshin_count += 1
	core_dim = 1.0
	var names_burned: int = max(1, int(round(burn / (ally_hp_max / float(roster_names.size())))))
	mangja_burned += names_burned
	roster_struck = min(roster_names.size(), roster_struck + names_burned)
	_align_orbs_for_soshin()
	_combat_audio("soshin", { "burned": names_burned }, 1.0)
	float_world("소신 −%d 망자" % names_burned, Vector3(ALLY_X + 1.8, 2.4, 0), Color(1.0, 0.5, 0.4))
	if ally_hp < ally_hp_max * 0.22:
		var u := Unit2D.new()
		var ashen_def := _with_unit_visual(EDEF["ashen"], ENEMY)
		u.setup(self, ENEMY, ashen_def, _soldier_tex(STRIKER, ENEMY, ashen_def.get("visual", {})))
		u.ashen = true
		u.position = Vector2(ALLY_X + 1.8, randf_range(-0.10, 0.10))
		units.append(u); world_root.add_child(u)
		float_world("재의 사도가 등을 돌렸다", Vector3(ALLY_X + 2.6, 3.0, 0), Color(0.82, 0.82, 0.86))
		_combat_audio("ash_spawn", {}, 1.0)

func _align_orbs_for_soshin() -> void:
	var role: int = STRIKER
	for u in units:
		if not u.dead and u.team == ALLY:
			role = u.utype
			break
	var align_count: int = min(4, command_orbs.size())
	for i in align_count:
		command_orbs[i] = _make_orb(i + soshin_count, role, ORB_ENHANCED)
	selected_orbs.clear()
	_refresh_orb_buttons()
	_set_deploy_feedback("소신  ·  %s 오브 4개 강제 정렬" % _orb_label(role), 2.4)

func _on_skill() -> void:
	if not _tutorial_enabled("command"):
		_set_deploy_feedback("등불함 지휘기는 ST5에서 해금됩니다")
		return
	if not running: return
	if line_core_mode:
		line_core.ally_core_hp = ally_hp
		line_core.enemy_core_hp = enemy_hp
		if ally_hp / ally_hp_max <= 0.25 and line_core.cast_last_stand():
			last_stand_ready = false
			last_stand_used = true
			core_invuln = 4.0
			var last_snapshot: Dictionary = line_core.snapshot()
			ally_hp = float(last_snapshot["ally_core_hp"])
			enemy_hp = float(last_snapshot["enemy_core_hp"])
			_sync_core_visuals(last_snapshot)
			_set_deploy_feedback("최후 신호  ·  전선 후퇴  ·  방벽 4초", 3.0)
			return
		line_core.cost = cost
		if skill_cd > 0.0 or not line_core.cast_command(float(command_skill.get("damage", 48.0)), float(command_skill.get("push", 0.0))):
			return
		skill_cd = float(command_skill.get("cooldown", 18.0))
		_sync_core_visuals(line_core.snapshot())
		_set_deploy_feedback("%s 발동" % str(command_skill.get("label", "등불함 포격")), 1.6)
		return
	if last_stand_ready:
		last_stand_ready = false
		last_stand_used = true
		core_invuln = float(last_stand_contract.get("barrier", 4.0))
		skill_cd = max(skill_cd, float(last_stand_contract.get("cooldown", 8.0)))
		var push: float = float(last_stand_contract.get("push", 4.2))
		var damage: float = float(last_stand_contract.get("damage", 28.0))
		for u in units.duplicate():
			if u.dead or u.team != ENEMY: continue
			u.position.x = min(ENEMY_X - 0.7, u.position.x + push)
			u.take_damage(damage, 1.0)
		var last_label: String = str(last_stand_contract.get("label", "최후 신호"))
		float_world("%s — 등불 방벽" % last_label, Vector3(ALLY_X + 3.0, 3.2, 0), AMBER)
		_set_deploy_feedback("등불 방벽 %.0f초  ·  지금 전선을 재배치하세요" % core_invuln, 4.0)
		_combat_audio("last_stand", { "phase": "cast" }, 1.0)
		shake(0.8)
		return
	if skill_cd > 0.0: return
	skill_cd = float(command_skill.get("cooldown", 18.0))
	var cmd_damage: float = float(command_skill.get("damage", 48.0))
	var cmd_push: float = float(command_skill.get("push", 0.0))
	var target_side_x: float = float(command_skill.get("target_side_x", 0.0))
	for u in units.duplicate():
		if u.dead or u.team != ENEMY: continue
		if u.position.x > target_side_x:
			if cmd_push > 0.0:
				u.position.x = min(ENEMY_X - 0.7, u.position.x + cmd_push)
			u.take_damage(cmd_damage, 1.0)
	var cmd_label: String = str(command_skill.get("label", "등불함 포격"))
	float_world(cmd_label, Vector3(3.0, 3.2, 0), AMBER)
	_combat_audio("command_skill", {}, 1.0)

# ---------- 루프 ----------
func _process(delta: float) -> void:
	_tick_combat_audio(delta)
	if core_dim > 0.0:
		core_dim = max(0.0, core_dim - delta * 1.6)
	core_invuln = max(0.0, core_invuln - delta)
	deploy_feedback_time = max(0.0, deploy_feedback_time - delta)
	if overlay != null:
		overlay.queue_redraw()
	trauma = max(0.0, trauma - delta * 2.0)
	if line_core_mode:
		_process_line_core(delta)
		return
	if ended:
		return
	if paused_by_player:
		return

	elapsed += delta
	var regen := COST_REGEN
	if ally_hp / ally_hp_max < enemy_hp / enemy_hp_max:
		regen *= 1.15
	cost = min(COST_MAX, cost + regen * delta)
	if units.size() > 0 and cost > max_unused_cost:
		max_unused_cost = cost

	soshin_cd = max(0.0, soshin_cd - delta)
	skill_cd = max(0.0, skill_cd - delta)
	for i in card_cd.size():
		card_cd[i] = max(0.0, card_cd[i] - delta)

	while wave_idx < WAVES.size() and elapsed >= float(WAVES[wave_idx]["t"]):
		var wv: Dictionary = WAVES[wave_idx]
		for _n in int(wv["n"]):
			_spawn(EDEF[wv["id"]], ENEMY)
		wave_idx += 1

	_update_buttons()
	if enemy_hp <= 0.0:
		_end(true)
	elif ally_hp <= 0.0:
		_end(false)

func _process_line_core(delta: float) -> void:
	if ended or paused_by_player:
		return
	elapsed += delta
	while wave_idx < WAVES.size() and elapsed >= float(WAVES[wave_idx]["t"]):
		var wave: Dictionary = WAVES[wave_idx]
		for _n in int(wave["n"]):
			_spawn(EDEF[wave["id"]], ENEMY)
		wave_idx += 1
	line_core.step(delta)
	var snapshot: Dictionary = line_core.snapshot()
	_consume_line_core_events()
	cost = float(snapshot["cost"])
	ally_hp = float(snapshot["ally_core_hp"])
	enemy_hp = float(snapshot["enemy_core_hp"])
	_sync_core_visuals(snapshot)
	_update_buttons()
	if line_core.ended:
		_end(line_core.winner == LineBattle.ALLY)

func _consume_line_core_events() -> void:
	# LineBattle이 판정한 이벤트만 화면 유닛에 전달한다. 화면 유닛은
	# 타겟·피해량을 다시 계산하지 않고, 이미 확정된 결과를 연출한다.
	for event in line_core.consume_events():
		var kind := str(event.get("type", ""))
		if kind == "hit":
			var attacker = core_visuals.get(int(event.get("attacker", -1)))
			var target = core_visuals.get(int(event.get("target", -1)))
			if is_instance_valid(attacker):
				attacker.play_manual_attack()
			if is_instance_valid(target):
				target.play_manual_hit()
		elif kind == "death":
			var dying = core_visuals.get(int(event.get("uid", -1)))
			if is_instance_valid(dying) and not dying.dead:
				dying.die()
		elif kind == "core_hit":
			var team := int(event.get("team", LineBattle.ENEMY))
			var core_x := ENEMY_X if team == LineBattle.ENEMY else ALLY_X
			float_world("-%d" % int(round(float(event.get("amount", 0.0)))), Vector3(core_x, 2.2, 0), Color("ffd27a"))

func _sync_core_visuals(snapshot: Dictionary) -> void:
	for uid in core_visuals.keys():
		var visual = core_visuals[uid]
		if not is_instance_valid(visual):
			continue
		var found: Dictionary = {}
		for state in snapshot["units"]:
			if int(state["uid"]) == int(uid):
				found = state
				break
		if found.is_empty():
			continue
		var next_x := lerpf(ALLY_X, ENEMY_X, float(found["x"]) / LineBattle.FIELD_LENGTH)
		visual.set_manual_motion(bool(found.get("moving", false)), bool(found.get("engaged", false)))
		visual.position.x = next_x
		visual.hp = float(found["hp"])
		visual.max_hp = float(found["max_hp"])
		if not bool(found["alive"]) and not visual.dead:
			visual.die()

func _update_buttons() -> void:
	if soshin_btn == null or skill_btn == null:
		return
	for i in card_btns.size():
		if i >= hand_indices.size():
			card_btns[i].visible = false
			continue
		var deck_idx: int = int(hand_indices[i])
		var def: Dictionary = DECK[deck_idx]
		var ok: bool = running and card_cd[deck_idx] <= 0.0 and cost >= _card_cost(def) and ally_count() < CAP
		if i == pending_card_slot:
			card_btns[i].modulate = Color(1.35, 1.12, 0.72, 1.0)
		else:
			card_btns[i].modulate = Color(1, 1, 1, 1) if ok else Color(0.5, 0.5, 0.55, 0.85)
	soshin_btn.modulate = Color(1, 1, 1, 1) if (running and soshin_cd <= 0.0 and ally_hp > ally_hp_max * 0.12) else Color(0.5, 0.5, 0.55, 0.85)
	soshin_btn.visible = _tutorial_enabled("soshin")
	skill_btn.visible = _tutorial_enabled("command")
	if pause_btn != null:
		pause_btn.disabled = ended
	if last_stand_ready:
		skill_btn.text = "%s\n등불 방벽" % str(last_stand_contract.get("label", "최후 신호"))
		skill_btn.modulate = Color(1.35, 1.12, 0.72, 1.0)
	else:
		skill_btn.text = "%s\n지휘기" % str(command_skill.get("label", "등불함 포격"))
		skill_btn.modulate = Color(1, 1, 1, 1) if (running and skill_cd <= 0.0) else Color(0.5, 0.5, 0.55, 0.85)

func _end(win: bool) -> void:
	if ended: return
	ended = true; running = false
	var cause := ""
	if win:
		cause = "한 명의 망자도 태우지 않고 회랑을 지켰다." if soshin_count == 0 else "망자 %d명을 태워 다음 안전지대로 길을 열었다." % mangja_burned
	elif retreat_cause != "":
		cause = retreat_cause
	else:
		if not used_defender and ranged_deaths >= 2:
			cause = "디펜더 없이 후열이 무너졌다 — 관지기를 세웠어야 했다."
		elif last_stand_ready:
			cause = "해금된 최후 신호를 쓰지 못한 채 등불이 꺼졌다."
		elif cap_blocked_attempts >= 3 and max_unused_cost >= 7.0:
			cause = "전선 %d기가 포화된 사이 코스트가 막혔다 — 병력이 빠질 때 즉시 재배치해야 했다." % CAP
		elif max_unused_cost >= 7.0:
			cause = "코스트 %d을(를) 쓰지 못한 채 등불이 꺼졌다." % int(max_unused_cost)
		elif soshin_count >= 5:
			cause = "과한 소신으로 망자를 %d명 태웠고, 등불이 먼저 꺼졌다." % mangja_burned
		else:
			cause = "방어선이 블룸의 물량에 잠식됐다."
	var metrics := {
		"elapsed": elapsed,
		"soshin": soshin_count,
		"burned": mangja_burned,
		"ally_hp": ally_hp,
		"ally_hp_max": ally_hp_max,
		"cause": cause,
	}
	battle_feedback = GameState.compose_battle_feedback(win, metrics)
	GameState.feedback_screen_flash("battle_win" if win else "battle_loss")
	if from_run:
		GameState.on_battle_end(win, metrics)   # 진행 저장·해금(승리 시 current_stage 전진)
	else:
		GameState.emit_feedback("battle_win" if win else "battle_loss", battle_feedback)
	_show_end(win, cause)

func _on_retreat() -> void:
	if ended:
		return
	if line_core_mode:
		line_core.ended = true
		line_core.winner = LineBattle.ENEMY
	retreat_cause = "지휘관이 후퇴를 선택했다 — 편성과 배치 순서를 다시 조정하라."
	_combat_audio("retreat", {}, 0.8)
	_end(false)

func _toggle_pause() -> void:
	if ended:
		return
	_set_paused(not paused_by_player)

func _set_paused(active: bool) -> void:
	if ended:
		return
	paused_by_player = active
	running = not active
	if paused_by_player:
		_show_pause_panel()
	else:
		_hide_pause_panel()

func _show_pause_panel() -> void:
	if pause_panel != null:
		pause_panel.visible = true
		return
	pause_panel = Control.new()
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(pause_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.035, 0.04, 0.74)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(bg)
	var title := Label.new()
	title.text = "일시정지"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", AMBER)
	title.position = Vector2(0, 220); title.size = Vector2(W, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_panel.add_child(title)
	var resume := _pause_btn("계속", W * 0.5 - 90, 318, Color(0.5, 0.4, 0.2))
	resume.pressed.connect(func(): _set_paused(false))
	pause_panel.add_child(resume)
	var retry := _pause_btn("다시 시작", W * 0.5 - 90, 380, Color(0.28, 0.22, 0.22))
	retry.pressed.connect(func(): get_tree().reload_current_scene())
	pause_panel.add_child(retry)
	var mapb := _pause_btn("메인", W * 0.5 - 90, 442, Color(0.24, 0.3, 0.34))
	mapb.pressed.connect(func(): GameState.goto("res://legacy/vesper/home.tscn"))
	pause_panel.add_child(mapb)

func _hide_pause_panel() -> void:
	if pause_panel != null:
		pause_panel.visible = false

func _pause_btn(text: String, x: float, y: float, col: Color) -> Button:
	var b := _end_btn(text, x, col)
	b.position.y = y
	return b

# ---------- 연출 ----------
func float_world(text: String, wpos: Vector3, color: Color) -> void:
	var sp: Vector2 = world_to_screen(wpos)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", color)
	l.position = sp - Vector2(70, 10)
	l.size = Vector2(140, 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(l)
	var t := create_tween()
	t.tween_property(l, "position:y", l.position.y - 26.0, 0.7)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
	t.tween_callback(l.queue_free)

func spark(pos: Vector3, color: Color) -> void:
	if simulation_mode:
		return
	var fx := PixelFx2D.new()
	fx.position = Vector2(pos.x, -pos.y)
	fx.configure(PackedVector2Array([Vector2.ZERO]), color, 0.15)
	world_root.add_child(fx)

func _tick_combat_audio(delta: float) -> void:
	for key in combat_audio_cooldowns.keys():
		combat_audio_cooldowns[key] = max(0.0, float(combat_audio_cooldowns[key]) - delta)

func _combat_audio(event_id: String, payload := {}, cooldown := 0.16) -> bool:
	if simulation_mode:
		return false
	if float(combat_audio_cooldowns.get(event_id, 0.0)) > 0.0:
		return false
	combat_audio_cooldowns[event_id] = cooldown
	GameState.emit_feedback(event_id, payload)
	return true

func _attack_audio_event(kind: String) -> String:
	match kind:
		"heal":
			return "combat_heal"
		"rifle", "sniper", "core":
			return "attack_ranged"
		"shield", "ossuary", "tank":
			return "attack_guard"
		_:
			return "attack_melee"

func attack_fx(attacker, target, color: Color, kind := "") -> void:
	if target == null:
		return
	attack_fx_to_pos(attacker, target.top_world() - Vector3(0, 0.22, 0), color, kind)

func attack_fx_to_pos(attacker, target_pos: Vector3, color: Color, kind := "") -> void:
	if simulation_mode or attacker == null:
		return
	_combat_audio(_attack_audio_event(kind), { "kind": kind }, 0.10)
	var from: Vector3 = attacker.top_world() - Vector3(0, attacker.vh * 0.42, 0)
	var to: Vector3 = target_pos
	var c := color
	var linger := 0.12
	if kind == "heal":
		c = Color(0.6, 1.0, 0.7)
		linger = 0.20
	elif kind == "sniper":
		linger = 0.18
	_line_fx(from, to, c, linger)
	if kind == "blade" or kind == "claw" or kind == "ash":
		_line_fx(to + Vector3(-0.18, 0.18, 0), to + Vector3(0.22, -0.12, 0), c.lightened(0.15), 0.10)

func _line_fx(from: Vector3, to: Vector3, color: Color, lifetime: float) -> void:
	var fx := PixelFx2D.new()
	fx.configure(PackedVector2Array([Vector2(from.x, -from.y), Vector2(to.x, -to.y)]), color, lifetime)
	world_root.add_child(fx)

func death_fx(pos: Vector3, color: Color) -> void:
	if simulation_mode:
		return
	_combat_audio("unit_death", {}, 0.18)
	for i in range(4):
		var p := pos + Vector3(randf_range(-0.18, 0.18), randf_range(-0.12, 0.18), randf_range(-0.10, 0.10))
		spark(p, color.lightened(0.08))

func combat_hit_fx(unit, amount: float, mult: float) -> void:
	if simulation_mode or unit == null:
		return
	if amount >= 22.0 or mult > 1.05:
		_combat_audio("hit_heavy", { "amount": amount, "mult": mult }, 0.14)

func shake(a: float) -> void:
	trauma = min(1.0, trauma + a)

func hitstop(d: float) -> void:
	if simulation_mode or not running:
		return
	Engine.time_scale = 0.06
	_hs_count += 1
	await get_tree().create_timer(d, true, false, true).timeout
	_hs_count -= 1
	if _hs_count <= 0:
		_hs_count = 0
		Engine.time_scale = 1.0

# ---------- 2D 월드 ----------
func _build_world() -> void:
	# 논리 좌표는 기존 -8.5..8.5를 유지하고, 한 번의 2D transform으로
	# 1280x720 화면 중앙에 픽셀 월드를 배치한다.
	world_root = Node2D.new()
	world_root.position = Vector2(W * 0.5, 430.0)
	world_root.scale = Vector2(50.0, 50.0)
	add_child(world_root)
	var stage := Node2D.new()
	stage.set_script(load("res://legacy/vesper/battlefield_2d.gd"))
	world_root.add_child(stage)

func world_to_screen(world_pos: Vector3) -> Vector2:
	return Vector2(W * 0.5 + world_pos.x * 50.0, 430.0 - world_pos.y * 50.0)

# ---------- 픽셀 병사 텍스처 ----------
func _soldier_tex(utype: int, team: int, visual: Dictionary = {}) -> ImageTexture:
	var shape := str(visual.get("shape", "type_%d" % utype))
	var key := "%d_%d_%s" % [utype, team, shape]
	if _tcache.has(key):
		return _tcache[key]
	var body: Color = visual.get("primary", TYPE_COL[utype])
	var accent: Color = visual.get("accent", CYAN if team == ENEMY else AMBER)
	var tex := _make_soldier_tex(body, accent, team == ENEMY, shape)
	_tcache[key] = tex
	return tex

func _make_soldier_tex(body: Color, accent: Color, enemy: bool, shape: String) -> ImageTexture:
	var w := 18; var h := 30
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rim := accent if not enemy else accent.lightened(0.10)
	match shape:
		"shield", "ossuary", "tank":
			_fill(img, 6, 2, 11, 6, body.lightened(0.12))
			_fill(img, 4, 7, 13, 20, body)
			_fill(img, 3, 10, 5, 22, rim.darkened(0.15))
			_fill(img, 12, 10, 14, 22, body.darkened(0.20))
			_fill(img, 5, 21, 7, 29, body.darkened(0.18))
			_fill(img, 10, 21, 12, 29, body.darkened(0.18))
			_fill(img, 6, 11, 10, 18, rim)
		"rifle", "sniper":
			_fill(img, 7, 2, 10, 6, body.lightened(0.10))
			_fill(img, 5, 7, 11, 17, body)
			_fill(img, 4, 18, 6, 29, body.darkened(0.18))
			_fill(img, 9, 18, 11, 29, body.darkened(0.18))
			_fill(img, 10, 9, 17, 10, rim)
			_fill(img, 12, 11, 17, 12, body.darkened(0.30))
			if shape == "sniper":
				_fill(img, 14, 8, 17, 8, rim.lightened(0.10))
		"relic", "relay":
			_fill(img, 7, 2, 10, 6, body.lightened(0.10))
			_fill(img, 5, 7, 12, 18, body)
			_fill(img, 3, 9, 4, 15, rim)
			_fill(img, 13, 9, 14, 15, rim)
			_fill(img, 6, 19, 8, 29, body.darkened(0.18))
			_fill(img, 10, 19, 12, 29, body.darkened(0.18))
			_fill(img, 8, 10, 9, 16, rim.lightened(0.20))
		"spore":
			_fill(img, 6, 3, 11, 8, rim)
			_fill(img, 4, 8, 13, 15, body)
			_fill(img, 6, 16, 11, 25, body.darkened(0.12))
			_fill(img, 4, 25, 6, 29, body.darkened(0.24))
			_fill(img, 11, 25, 13, 29, body.darkened(0.24))
		"claw", "ash", "banner", "blade":
			_fill(img, 7, 2, 10, 6, body.lightened(0.10))
			_fill(img, 5, 7, 12, 17, body)
			_fill(img, 3, 8, 4, 15, body.darkened(0.14))
			_fill(img, 13, 8, 14, 15, body.darkened(0.14))
			_fill(img, 5, 18, 7, 29, body.darkened(0.18))
			_fill(img, 10, 18, 12, 29, body.darkened(0.18))
			_fill(img, 11, 9, 16, 11, rim)
			if shape == "banner":
				_fill(img, 3, 4, 4, 18, rim.darkened(0.12))
				_fill(img, 4, 4, 9, 8, rim)
			if shape == "ash":
				_fill(img, 6, 11, 11, 13, rim.darkened(0.10))
		_:
			_fill(img, 7, 2, 10, 6, body.lightened(0.08))
			_fill(img, 5, 7, 12, 17, body)
			_fill(img, 3, 8, 4, 15, body.darkened(0.12))
			_fill(img, 13, 8, 14, 15, body.darkened(0.12))
			_fill(img, 5, 18, 7, 29, body.darkened(0.18))
			_fill(img, 10, 18, 12, 29, body.darkened(0.18))
			_fill(img, 11, 9, 16, 11, rim)
	_fill(img, 8, 3, 9, 4, rim)
	_outline(img, Color(0.04, 0.05, 0.06, 1.0))
	return ImageTexture.create_from_image(img)

func _fill(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, c)

func _outline(img: Image, oc: Color) -> void:
	var w := img.get_width(); var h := img.get_height()
	var src := img.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			var near := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.0:
					near = true; break
			if near:
				img.set_pixel(x, y, oc)

func _make_blob_tex() -> ImageTexture:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - s / 2.0, y - s / 2.0).length() / (s / 2.0)
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * a))
	return ImageTexture.create_from_image(img)

# ---------- UI ----------
func _btn_style(b: Button, base: Color) -> void:
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 15)
	var sb := StyleBoxFlat.new()
	sb.bg_color = base; sb.set_corner_radius_all(8)
	sb.set_border_width_all(2); sb.border_color = base.lightened(0.2)
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate(); sh.bg_color = base.lightened(0.12)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_color_override("font_color", Color(0.97, 0.96, 0.93))

func _orb_style(b: Button, base: Color, state := ORB_NORMAL, selected := false) -> void:
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 17)
	var sb := StyleBoxFlat.new()
	var alpha: float = 0.72 if selected else 0.26
	if state == ORB_ENHANCED:
		alpha += 0.14
	if state == ORB_CORRUPTED:
		base = Color(0.78, 0.42, 0.86)
		alpha += 0.10
	sb.bg_color = Color(base.r, base.g, base.b, min(alpha, 0.92))
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2 if selected else 1)
	if state == ORB_CORRUPTED:
		sb.border_color = Color(1.0, 0.35, 0.72, 0.95)
	elif state == ORB_ENHANCED:
		sb.border_color = Color(1.0, 0.90, 0.56, 0.95)
	else:
		sb.border_color = Color(1.0, 0.90, 0.56, 0.95) if selected else Color(base.r, base.g, base.b, 0.78)
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate()
	sh.bg_color = Color(base.r, base.g, base.b, 0.88)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_color_override("font_color", Color(0.96, 0.97, 0.94))

func _refresh_orb_buttons() -> void:
	var orbs_enabled := _tutorial_enabled("orbs")
	for i in orb_btns.size():
		if i >= command_orbs.size():
			orb_btns[i].visible = false
			continue
		var role: int = _orb_role(i)
		var state: int = _orb_state(i)
		var b: Button = orb_btns[i]
		b.visible = orbs_enabled
		b.text = _orb_label(role, state)
		_orb_style(b, _orb_color(role), state, selected_orbs.has(i))
	if orb_cast_btn != null:
		orb_cast_btn.visible = orbs_enabled
		var count: int = selected_orbs.size()
		orb_cast_btn.text = "오브 발동\n%d / 1·2·4" % count
		orb_cast_btn.modulate = Color(1, 1, 1, 1) if (count == 1 or count == 2 or count == 4) else Color(0.55, 0.55, 0.6, 0.85)

func _refresh_card_button(slot: int) -> void:
	if slot < 0 or slot >= card_btns.size() or slot >= hand_indices.size():
		return
	var deck_idx: int = int(hand_indices[slot])
	var def: Dictionary = DECK[deck_idx]
	var b: Button = card_btns[slot]
	b.visible = true
	var leader_mark := " L" if bool(def.get("leader", false)) else ""
	b.text = "%s%s\nC%d  %s" % [def["name"], leader_mark, int(_card_cost(def)), TYPE_GLYPH[def["type"]]]
	_btn_style(b, Color(TYPE_COL[def["type"]]).darkened(0.45))
	b.icon = null
	if def.has("art") and ResourceLoader.exists(def["art"]):
		b.icon = load(def["art"])
		b.add_theme_constant_override("icon_max_width", 48)
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("h_separation", 6)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	overlay = Node2D.new()
	overlay.set_script(load("res://legacy/vesper/overlay.gd"))
	overlay.main = self
	ui.add_child(overlay)

	var bx := 26.0
	for i in HAND_SIZE:
		var b := Button.new()
		b.position = Vector2(bx, 648); b.size = Vector2(158, 58)
		b.pressed.connect(_on_card.bind(i))
		ui.add_child(b); card_btns.append(b)
		_refresh_card_button(i)
		bx += 166.0

	var ox := 520.0
	var oy := 538.0
	for i in ORB_COUNT:
		var b := Button.new()
		var col: int = i % ORB_COLS
		var row: int = i / ORB_COLS
		b.position = Vector2(ox + col * 42.0, oy + row * 42.0)
		b.size = Vector2(36, 36)
		b.pressed.connect(_on_orb_button.bind(i))
		ui.add_child(b)
		orb_btns.append(b)
	_refresh_orb_buttons()

	orb_cast_btn = Button.new()
	orb_cast_btn.position = Vector2(870, 548)
	orb_cast_btn.size = Vector2(150, 58)
	_btn_style(orb_cast_btn, Color(0.22, 0.20, 0.30))
	orb_cast_btn.pressed.connect(_on_orb_cast)
	ui.add_child(orb_cast_btn)
	_refresh_orb_buttons()

	soshin_btn = Button.new()
	soshin_btn.text = "소신\n등불 연소"
	soshin_btn.position = Vector2(870, 648); soshin_btn.size = Vector2(150, 58)
	_btn_style(soshin_btn, Color(0.5, 0.16, 0.13))
	soshin_btn.pressed.connect(_on_soshin)
	ui.add_child(soshin_btn)

	skill_btn = Button.new()
	skill_btn.text = "%s\n지휘기" % str(command_skill.get("label", "등불함 포격"))
	skill_btn.position = Vector2(1034, 648); skill_btn.size = Vector2(150, 58)
	_btn_style(skill_btn, Color(0.16, 0.30, 0.36))
	skill_btn.pressed.connect(_on_skill)
	ui.add_child(skill_btn)

	var dex_btn := Button.new()
	dex_btn.text = "도감"
	dex_btn.position = Vector2(393, 17); dex_btn.size = Vector2(74, 28)
	_btn_style(dex_btn, Color(0.22, 0.20, 0.30))
	dex_btn.add_theme_font_size_override("font_size", 14)
	dex_btn.pressed.connect(_open_roster)
	ui.add_child(dex_btn)

	retreat_btn = Button.new()
	retreat_btn.text = "후퇴"
	retreat_btn.position = Vector2(477, 17); retreat_btn.size = Vector2(74, 28)
	_btn_style(retreat_btn, Color(0.38, 0.18, 0.18))
	retreat_btn.add_theme_font_size_override("font_size", 14)
	retreat_btn.pressed.connect(_on_retreat)
	ui.add_child(retreat_btn)

	pause_btn = Button.new()
	pause_btn.text = "일시정지"
	pause_btn.position = Vector2(561, 17); pause_btn.size = Vector2(96, 28)
	_btn_style(pause_btn, Color(0.22, 0.20, 0.30))
	pause_btn.add_theme_font_size_override("font_size", 14)
	pause_btn.pressed.connect(_toggle_pause)
	ui.add_child(pause_btn)

func _open_roster() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.add_child(load("res://legacy/vesper/roster.tscn").instantiate())
	add_child(layer)

func _show_end(win: bool, cause: String) -> void:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(panel)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.06, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)
	var accent := AMBER if win else Color(0.52, 0.62, 0.72)
	for i in range(5):
		var stripe := ColorRect.new()
		stripe.color = Color(accent.r, accent.g, accent.b, 0.05 + float(i) * 0.018)
		stripe.position = Vector2(220 + i * 64, 178 + i * 18)
		stripe.size = Vector2(840 - i * 96, 2)
		panel.add_child(stripe)
	var feedback := GameState.last_battle_feedback if from_run and not GameState.last_battle_feedback.is_empty() else battle_feedback
	var title := Label.new()
	title.text = "회랑을 열었다" if win else "등불이 꺼졌다"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", AMBER if win else Color(0.7, 0.78, 0.82))
	title.position = Vector2(0, 188); title.size = Vector2(W, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate.a = 0.0
	panel.add_child(title)
	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 0.18)
	var grade := Label.new()
	grade.text = "전술 평가  %s  ·  %s" % [str(feedback.get("grade", "D")), str(feedback.get("grade_desc", "재정비 필요"))]
	grade.add_theme_font_override("font", font)
	grade.add_theme_font_size_override("font_size", 26)
	grade.add_theme_color_override("font_color", accent)
	grade.position = Vector2(0, 260); grade.size = Vector2(W, 36)
	grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(grade)
	var sub := Label.new()
	sub.text = "사인(死因)  ·  " + cause
	sub.add_theme_font_override("font", font)
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
	sub.position = Vector2(0, 314); sub.size = Vector2(W, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(sub)
	var info := Label.new()
	info.text = "생존 %.0f초 · 소신 %d회 · 망자 %d 소실 · 등불 %.0f%%" % [
		elapsed, soshin_count, mangja_burned, float(feedback.get("ally_pct", 0.0)) * 100.0]
	info.add_theme_font_override("font", font)
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(0.6, 0.66, 0.7))
	info.position = Vector2(0, 350); info.size = Vector2(W, 24)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(info)
	var xp := Label.new()
	xp.text = str(feedback.get("xp_line", ""))
	xp.add_theme_font_override("font", font)
	xp.add_theme_font_size_override("font_size", 16)
	xp.add_theme_color_override("font_color", Color(0.78, 0.82, 0.70))
	xp.position = Vector2(0, 378); xp.size = Vector2(W, 24)
	xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(xp)

	# 최초 클리어 보상 — 각인재 + 신규 동료를 한 줄로 묶어 메타 루프를 닫는다.
	if from_run and win and (GameState.last_brand_reward or GameState.last_unlocked_name != ""):
		var unl := Label.new()
		var rewards := []
		if GameState.last_brand_reward:
			rewards.append("각인재 +1")
		if GameState.last_unlocked_name != "":
			rewards.append("새 동료 · %s" % GameState.last_unlocked_name)
		unl.text = "획득 — " + "   ·   ".join(rewards)
		unl.add_theme_font_override("font", font)
		unl.add_theme_font_size_override("font_size", 19)
		unl.add_theme_color_override("font_color", AMBER)
		unl.position = Vector2(0, 410); unl.size = Vector2(W, 26)
		unl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(unl)

	# 라우팅: 실제 런이면 회랑/다음, 단독 실행이면 재시작
	if not from_run:
		var again := _end_btn("다시", W * 0.5 - 80, Color(0.2, 0.3, 0.34))
		again.pressed.connect(func(): get_tree().reload_current_scene())
		panel.add_child(again)
	elif win:
		if GameState.all_cleared():
			var ending := Label.new()
			ending.text = "엔딩 — 매듭이 풀리고 등불함은 다음 회랑의 좌표를 받아 적었다."
			ending.add_theme_font_override("font", font)
			ending.add_theme_font_size_override("font_size", 18)
			ending.add_theme_color_override("font_color", AMBER)
			ending.position = Vector2(0, 440); ending.size = Vector2(W, 26)
			ending.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			panel.add_child(ending)
			var mapb := _end_btn("회랑 맵", W * 0.5 - 90, Color(0.5, 0.4, 0.2))
			mapb.position.y = 490
			mapb.pressed.connect(func(): GameState.goto("res://legacy/vesper/stagemap.tscn"))
			panel.add_child(mapb)
			var loopb := _end_btn("변종 도전", W * 0.5 + 90, Color(0.24, 0.3, 0.34))
			loopb.position.y = 490
			loopb.pressed.connect(func():
				GameState.current_stage = GameState.STAGES.size()
				GameState.goto("res://legacy/vesper/squad.tscn"))
			panel.add_child(loopb)
		else:
			var nextb := _end_btn("다음 회랑 →", W * 0.5 - 176, Color(0.5, 0.4, 0.2))
			nextb.pressed.connect(func(): GameState.goto("res://legacy/vesper/squad.tscn"))
			panel.add_child(nextb)
			var mapb := _end_btn("회랑 맵", W * 0.5 + 16, Color(0.24, 0.3, 0.34))
			mapb.pressed.connect(func(): GameState.goto("res://legacy/vesper/stagemap.tscn"))
			panel.add_child(mapb)
	else:
		var retry := _end_btn("다시", W * 0.5 - 176, Color(0.3, 0.24, 0.24))
		retry.pressed.connect(func(): get_tree().reload_current_scene())
		panel.add_child(retry)
		var mapb := _end_btn("회랑 맵", W * 0.5 + 16, Color(0.24, 0.3, 0.34))
		mapb.pressed.connect(func(): GameState.goto("res://legacy/vesper/stagemap.tscn"))
		panel.add_child(mapb)

func _end_btn(text: String, x: float, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.position = Vector2(x, 500); b.size = Vector2(160, 50)
	_btn_style(b, col)
	return b
