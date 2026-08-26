extends Node2D
## 베스퍼 회랑 — MVP1 전투 코어.
## 단일 라인 / 코스트 / 소신(코어 HP 연소) / 병종 상성 / 지휘관 스킬 / 웨이브 / 승패 / 사인 진단.
## 아트는 전부 플레이스홀더 도형 — 재미(특히 소신 트롤리 딜레마) 검증용.

const VUnit = preload("res://legacy/vesper/unit.gd")

const W := 1280.0
const H := 720.0
const LANE_Y := 472.0
const CAP := 9                 # 아군 동시 유닛 상한(가독성/성능)

enum { ALLY, ENEMY }
enum { STRIKER, RANGER, DEFENDER, SNIPER, SUPPORT }

const TYPE_GLYPH := { STRIKER: "S", RANGER: "R", DEFENDER: "D", SNIPER: "N", SUPPORT: "+" }
const TYPE_KO := { STRIKER: "스트라이커", RANGER: "레인저", DEFENDER: "디펜더", SNIPER: "스나이퍼", SUPPORT: "서포터" }

# 색
const BG := Color(0.055, 0.092, 0.10)
const LANE := Color(0.09, 0.15, 0.16)
const AMBER := Color(1.0, 0.74, 0.36)      # 아군 등불 온기
const COLD := Color(0.36, 0.86, 0.92)      # 블룸 청록 냉기
const C_STRIKER := Color(0.92, 0.47, 0.42)
const C_RANGER := Color(0.42, 0.82, 0.86)
const C_DEFENDER := Color(0.52, 0.62, 0.92)
const C_SNIPER := Color(0.92, 0.68, 0.98)
const C_SUPPORT := Color(0.58, 0.86, 0.56)

# 아군 편성(소환 카드)
var DECK := [
	{ "name": "진혼병", "type": STRIKER, "cost": 2, "hp": 78, "dmg": 13, "aspd": 1.5, "range": 36, "move": 74, "cd": 1.2, "radius": 13, "col": C_STRIKER },
	{ "name": "운구 소총수", "type": RANGER, "cost": 3, "hp": 46, "dmg": 11, "aspd": 1.1, "range": 205, "move": 56, "cd": 1.4, "radius": 12, "col": C_RANGER },
	{ "name": "관지기", "type": DEFENDER, "cost": 3, "hp": 215, "dmg": 6, "aspd": 0.9, "range": 40, "move": 46, "cd": 3.0, "radius": 17, "col": C_DEFENDER },
	{ "name": "소등사", "type": SNIPER, "cost": 5, "hp": 40, "dmg": 40, "aspd": 0.42, "range": 330, "move": 44, "cd": 5.0, "radius": 12, "col": C_SNIPER },
	{ "name": "집전 의무관", "type": SUPPORT, "cost": 4, "hp": 58, "dmg": 0, "heal": 15, "aspd": 0.8, "range": 150, "move": 56, "cd": 4.0, "radius": 12, "col": C_SUPPORT },
]

# 적(블룸 항체)
var EDEF := {
	"rusher": { "name": "급조 항체", "type": STRIKER, "hp": 56, "dmg": 9, "aspd": 1.3, "range": 34, "move": 78, "radius": 12, "col": C_STRIKER },
	"spore":  { "name": "확산체", "type": RANGER, "hp": 42, "dmg": 8, "aspd": 1.0, "range": 150, "move": 52, "radius": 12, "col": C_RANGER },
	"tank":   { "name": "만성 염증체", "type": DEFENDER, "hp": 330, "dmg": 17, "aspd": 0.7, "range": 40, "move": 33, "radius": 22, "col": C_DEFENDER },
	"ashen":  { "name": "재의 사도", "type": STRIKER, "hp": 90, "dmg": 14, "aspd": 1.2, "range": 36, "move": 70, "radius": 14, "col": C_STRIKER },
}

# 웨이브: {t(초), id, n}
var WAVES := [
	{ "t": 2.0, "id": "rusher", "n": 2 },
	{ "t": 8.0, "id": "rusher", "n": 2 }, { "t": 9.0, "id": "spore", "n": 1 },
	{ "t": 15.0, "id": "spore", "n": 2 },
	{ "t": 23.0, "id": "tank", "n": 1 }, { "t": 24.0, "id": "rusher", "n": 2 },
	{ "t": 33.0, "id": "rusher", "n": 3 },
	{ "t": 43.0, "id": "tank", "n": 1 }, { "t": 44.0, "id": "spore", "n": 2 },
	{ "t": 54.0, "id": "rusher", "n": 2 }, { "t": 55.0, "id": "spore", "n": 1 },
]

const COST_MAX := 10.0
const COST_REGEN := 0.62

var font: Font
var units: Array = []
var running := true
var ended := false

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
var core_dim := 0.0          # 소신 시 등불 깜빡임

# 각명(명단) — 플레이버: 소신 때 이름이 지워짐
var roster_names := ["하준", "서연", "도윤", "지우", "민재", "수아", "은우", "예린", "현성", "다은", "태경", "소율"]
var roster_struck := 0

# 사인 진단 메트릭
var soshin_count := 0
var mangja_burned := 0
var max_unused_cost := 0.0
var used_defender := false
var ally_deaths := 0
var ranged_deaths := 0

# UI
var ui: CanvasLayer
var card_btns: Array = []
var soshin_btn: Button
var skill_btn: Button
var end_panel: Control

func ally_core_x() -> float: return 96.0
func enemy_core_x() -> float: return 1184.0

func _ready() -> void:
	font = load("res://assets/Galmuri11.ttf")
	card_cd.resize(DECK.size())
	for i in card_cd.size(): card_cd[i] = 0.0
	_build_ui()
	set_process(true)
	queue_redraw()

# ---------- 규칙 ----------
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
	else:
		ally_hp = max(0.0, ally_hp - amount)

func on_unit_death(u: VUnit, _killed: bool) -> void:
	units.erase(u)
	if u.team == ALLY:
		ally_deaths += 1
		if u.utype == RANGER or u.utype == SNIPER or u.utype == SUPPORT:
			ranged_deaths += 1

# ---------- 스폰 ----------
func _spawn(def: Dictionary, team: int) -> void:
	var u := VUnit.new()
	u.setup(self, team, def)
	var x: float = ally_core_x() + 44.0 if team == ALLY else enemy_core_x() - 44.0
	u.position = Vector2(x, LANE_Y + randf_range(-7.0, 7.0))
	units.append(u)
	add_child(u)

func _spawn_ally(def: Dictionary) -> void:
	_spawn(def, ALLY)
	float_text(def["name"], Vector2(ally_core_x() + 60.0, LANE_Y - 34.0), AMBER)

func _spawn_enemy(id: String) -> void:
	_spawn(EDEF[id], ENEMY)

# ---------- 입력 ----------
func _on_card(i: int) -> void:
	if not running: return
	var def: Dictionary = DECK[i]
	if card_cd[i] > 0.0 or cost < float(def["cost"]) or ally_count() >= CAP:
		return
	cost -= float(def["cost"])
	card_cd[i] = float(def["cd"])
	if def["type"] == DEFENDER: used_defender = true
	_spawn_ally(def)

func _on_soshin() -> void:
	if not running or soshin_cd > 0.0: return
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
	shake_core()
	float_text("소신 −%d 망자" % names_burned, Vector2(ally_core_x() + 70.0, LANE_Y - 60.0), Color(1.0, 0.5, 0.4))
	# 재의 사도화: 등불이 임계 이하로 떨어지면 아군이 적이 됨
	if ally_hp < ally_hp_max * 0.22:
		var u := VUnit.new()
		u.setup(self, ENEMY, EDEF["ashen"])
		u.ashen = true
		u.position = Vector2(ally_core_x() + 70.0, LANE_Y + randf_range(-6.0, 6.0))
		units.append(u); add_child(u)
		float_text("재의 사도가 등을 돌렸다", Vector2(ally_core_x() + 120.0, LANE_Y - 80.0), Color(0.8, 0.8, 0.85))

func _on_skill() -> void:                   # 마지막 통신(궤도 폭격)
	if not running or skill_cd > 0.0: return
	skill_cd = 18.0
	for u in units:
		if u.dead or u.team != ENEMY: continue
		if u.position.x > W * 0.42:
			u.take_damage(48.0, 1.0)
	float_text("마지막 통신 — 궤도 폭격", Vector2(W * 0.62, LANE_Y - 90.0), AMBER)

# ---------- 루프 ----------
func _process(delta: float) -> void:
	if core_dim > 0.0:
		core_dim = max(0.0, core_dim - delta * 1.6)
	if ended:
		queue_redraw(); return

	elapsed += delta
	# 코스트 리젠 + 백투더월(열세 시 가속)
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
			_spawn_enemy(wv["id"])
		wave_idx += 1

	_update_buttons()

	if enemy_hp <= 0.0:
		_end(true)
	elif ally_hp <= 0.0:
		_end(false)

	queue_redraw()

func _update_buttons() -> void:
	for i in card_btns.size():
		var def: Dictionary = DECK[i]
		var ok: bool = running and card_cd[i] <= 0.0 and cost >= float(def["cost"]) and ally_count() < CAP
		card_btns[i].modulate = Color(1, 1, 1, 1) if ok else Color(0.5, 0.5, 0.55, 0.85)
	soshin_btn.modulate = Color(1, 1, 1, 1) if (running and soshin_cd <= 0.0 and ally_hp > ally_hp_max * 0.12) else Color(0.5, 0.5, 0.55, 0.85)
	skill_btn.modulate = Color(1, 1, 1, 1) if (running and skill_cd <= 0.0) else Color(0.5, 0.5, 0.55, 0.85)

# ---------- 종료 / 사인 진단 ----------
func _end(win: bool) -> void:
	if ended: return
	ended = true
	running = false
	var cause := ""
	if win:
		if soshin_count == 0:
			cause = "한 명의 망자도 태우지 않고 회랑을 지켰다."
		else:
			cause = "망자 %d명을 태워 다음 안전지대로 길을 열었다." % mangja_burned
	else:
		if not used_defender and ranged_deaths >= 2:
			cause = "디펜더 없이 후열이 무너졌다 — 관지기를 세웠어야 했다."
		elif max_unused_cost >= 7.0:
			cause = "코스트 %d을(를) 쓰지 못한 채 등불이 꺼졌다." % int(max_unused_cost)
		elif soshin_count >= 5:
			cause = "과한 소신으로 망자를 %d명 태웠고, 등불이 먼저 꺼졌다." % mangja_burned
		else:
			cause = "방어선이 블룸의 물량에 잠식됐다."
	_show_end(win, cause)

# ---------- 연출 헬퍼 ----------
func float_text(text: String, world_pos: Vector2, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", color)
	l.position = world_pos - Vector2(40, 0)
	l.size = Vector2(80, 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 50
	add_child(l)
	var t := create_tween()
	t.tween_property(l, "position:y", l.position.y - 26.0, 0.7)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
	t.tween_callback(l.queue_free)

var _sparks: Array = []
func spark(world_pos: Vector2, color: Color) -> void:
	_sparks.append({ "p": world_pos, "c": color, "t": 0.12 })

func shake_core() -> void:
	var t := create_tween()
	t.tween_property(self, "position:x", 6.0, 0.04)
	t.tween_property(self, "position:x", -6.0, 0.04)
	t.tween_property(self, "position:x", 0.0, 0.04)

# ---------- 그리기 ----------
func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), BG)
	# 회랑 라인 밴드
	draw_rect(Rect2(0, LANE_Y - 46, W, 92), LANE)
	draw_line(Vector2(0, LANE_Y - 46), Vector2(W, LANE_Y - 46), Color(COLD.r, COLD.g, COLD.b, 0.22), 2.0)
	draw_line(Vector2(0, LANE_Y + 46), Vector2(W, LANE_Y + 46), Color(0, 0, 0, 0.3), 2.0)

	_draw_cores()
	_draw_top_hud()
	_draw_roster()

	# 스파크(타격 점멸)
	var keep: Array = []
	for s in _sparks:
		s["t"] -= get_process_delta_time()
		if s["t"] > 0.0:
			draw_circle(s["p"], 7.0 * (s["t"] / 0.12) + 2.0, Color(s["c"].r, s["c"].g, s["c"].b, 0.8))
			keep.append(s)
	_sparks = keep

func _draw_cores() -> void:
	# 아군 코어 = 등불(관)
	var ac := Vector2(ally_core_x(), LANE_Y)
	var glow: float = 0.55 + 0.25 * (ally_hp / ally_hp_max) - 0.3 * core_dim
	draw_circle(ac, 46.0, Color(AMBER.r, AMBER.g, AMBER.b, 0.10 + 0.10 * glow))
	draw_circle(ac, 30.0, Color(0.16, 0.13, 0.10))
	draw_circle(ac, 22.0, Color(AMBER.r, AMBER.g, AMBER.b, clamp(glow, 0.2, 0.95)))
	draw_arc(ac, 30.0, 0, TAU, 28, AMBER, 2.5)
	# 적 코어 = 매듭(블룸 면역핵)
	var ec := Vector2(enemy_core_x(), LANE_Y)
	draw_circle(ec, 44.0, Color(COLD.r, COLD.g, COLD.b, 0.10))
	draw_circle(ec, 30.0, Color(0.10, 0.20, 0.20))
	draw_circle(ec, 20.0, Color(COLD.r * 0.7, COLD.g * 0.8, COLD.b * 0.8, 0.85))
	draw_arc(ec, 30.0, 0, TAU, 28, COLD, 2.5)

func _bar(p: Vector2, sz: Vector2, frac: float, fill: Color, label: String) -> void:
	draw_rect(Rect2(p, sz), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(p, Vector2(sz.x * clamp(frac, 0, 1), sz.y)), fill)
	draw_rect(Rect2(p, sz), Color(1, 1, 1, 0.12), false, 1.0)
	draw_string(font, p + Vector2(8, sz.y - 6), label, HORIZONTAL_ALIGNMENT_LEFT, sz.x - 12, 14, Color(1, 1, 1, 0.92))

func _draw_top_hud() -> void:
	# 아군 등불(코어 HP)
	_bar(Vector2(28, 20), Vector2(360, 24), ally_hp / ally_hp_max, Color(AMBER.r, AMBER.g, AMBER.b, 0.85),
		"등불  %d / %d" % [int(ally_hp), int(ally_hp_max)])
	# 적 매듭(코어 HP)
	_bar(Vector2(W - 28 - 360, 20), Vector2(360, 24), enemy_hp / enemy_hp_max, Color(COLD.r * 0.8, COLD.g, COLD.b, 0.85),
		"매듭  %d / %d" % [int(enemy_hp), int(enemy_hp_max)])
	# 코스트 게이지(중앙)
	var cp := Vector2(W * 0.5 - 170, 22)
	draw_rect(Rect2(cp, Vector2(340, 20)), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(cp, Vector2(340 * clamp(cost / COST_MAX, 0, 1), 20)), Color(0.5, 0.8, 0.95, 0.9))
	for k in range(1, 10):
		var x := cp.x + 340.0 * (k / 10.0)
		draw_line(Vector2(x, cp.y), Vector2(x, cp.y + 20), Color(0, 0, 0, 0.35), 1.0)
	draw_string(font, Vector2(cp.x, cp.y + 38), "코스트  %.1f / %d" % [cost, int(COST_MAX)],
		HORIZONTAL_ALIGNMENT_CENTER, 340, 15, Color(0.8, 0.92, 1.0))

func _draw_roster() -> void:
	# 각명(명단) — 소신 때 위에서부터 지워짐
	var x := 28.0
	var y := 58.0
	draw_string(font, Vector2(x, y), "각명  남은 망자 %d" % (roster_names.size() - roster_struck),
		HORIZONTAL_ALIGNMENT_LEFT, 200, 13, Color(0.7, 0.78, 0.8))
	for i in roster_names.size():
		var yy := y + 18.0 + i * 15.0
		var struck := i < roster_struck
		var c := Color(0.35, 0.35, 0.38) if struck else Color(0.85, 0.8, 0.7)
		draw_string(font, Vector2(x + 6, yy), roster_names[i], HORIZONTAL_ALIGNMENT_LEFT, 120, 12, c)
		if struck:
			draw_line(Vector2(x + 4, yy - 4), Vector2(x + 70, yy - 4), Color(0.9, 0.4, 0.35, 0.7), 1.5)

# ---------- UI(버튼/종료 패널) ----------
func _btn_style(b: Button, base: Color) -> void:
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 15)
	var sb := StyleBoxFlat.new()
	sb.bg_color = base
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = base.lightened(0.2)
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate(); sh.bg_color = base.lightened(0.12)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_color_override("font_color", Color(0.97, 0.96, 0.93))

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	var bx := 26.0
	for i in DECK.size():
		var def: Dictionary = DECK[i]
		var b := Button.new()
		b.text = "%s\nC%d  %s" % [def["name"], int(def["cost"]), TYPE_GLYPH[def["type"]]]
		b.position = Vector2(bx, 648)
		b.size = Vector2(158, 58)
		_btn_style(b, Color(def["col"]).darkened(0.45))
		b.pressed.connect(_on_card.bind(i))
		ui.add_child(b)
		card_btns.append(b)
		bx += 166.0

	soshin_btn = Button.new()
	soshin_btn.text = "소신\n등불 연소"
	soshin_btn.position = Vector2(870, 648)
	soshin_btn.size = Vector2(150, 58)
	_btn_style(soshin_btn, Color(0.5, 0.16, 0.13))
	soshin_btn.pressed.connect(_on_soshin)
	ui.add_child(soshin_btn)

	skill_btn = Button.new()
	skill_btn.text = "마지막 통신\n궤도 폭격"
	skill_btn.position = Vector2(1034, 648)
	skill_btn.size = Vector2(150, 58)
	_btn_style(skill_btn, Color(0.16, 0.30, 0.36))
	skill_btn.pressed.connect(_on_skill)
	ui.add_child(skill_btn)

func _show_end(win: bool, cause: String) -> void:
	end_panel = Control.new()
	end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(end_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.06, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_panel.add_child(bg)

	var title := Label.new()
	title.text = "회랑을 열었다" if win else "등불이 꺼졌다"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", AMBER if win else Color(0.7, 0.78, 0.82))
	title.position = Vector2(0, 232); title.size = Vector2(W, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_panel.add_child(title)

	var sub := Label.new()
	sub.text = "사인(死因)  ·  " + cause
	sub.add_theme_font_override("font", font)
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
	sub.position = Vector2(0, 312); sub.size = Vector2(W, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_panel.add_child(sub)

	var info := Label.new()
	info.text = "소신 %d회 · 망자 %d 소실 · 생존 %.0f초" % [soshin_count, mangja_burned, elapsed]
	info.add_theme_font_override("font", font)
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(0.6, 0.66, 0.7))
	info.position = Vector2(0, 348); info.size = Vector2(W, 24)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_panel.add_child(info)

	var again := Button.new()
	again.text = "다시"
	again.position = Vector2(W * 0.5 - 80, 404); again.size = Vector2(160, 50)
	_btn_style(again, Color(0.2, 0.3, 0.34))
	again.pressed.connect(func(): get_tree().reload_current_scene())
	end_panel.add_child(again)
