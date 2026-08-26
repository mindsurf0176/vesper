extends Control

const VesperUITheme = preload("res://scenes/ui/vesper_ui.gd")
const VesperBackdropScene = preload("res://scenes/ui/vesper_backdrop.gd")
const SquadPrepViewScene = preload("res://scenes/prep/squad_prep_view.gd")

## STARLINE의 준비 → 전투 → 결과 → 게임오버 흐름.
## STARLINE gameplay core와 Vesper passive presentation을 연결한다.

enum Phase { MAP, PREP, PLAN, BATTLE, RESULT, GAMEOVER }

const FIRST_PREP_TIME := 45.0
const PREP_TIME := 30.0
const RESULT_TIME := 4.0

var game: Match
var corridor: CorridorRun
var sim: CombatSim = null
var phase := Phase.PREP
var speed := 1.0
var rng := RandomNumberGenerator.new()
var pairs: Array = []
var foe_seat := -1

var econ: Econ:
	get: return game.econ
var player: Econ.Player:
	get: return game.human_seat().player
var round_no: int:
	get: return game.round_no

var _accum := 0.0
var _prep_left := FIRST_PREP_TIME
var _result_left := RESULT_TIME
var _font: Font
var _prep
var _battle_layer: Control
var _view: BattlePresenter
var _battle_top: Label
var _speed_btn: Button
var _command_btn: Button
var _command_left := 0.0
var _turn_left := 0.0
var _plan_buttons: Array[Button] = []
var _confirm_plan_btn: Button
var _planned_orders: Array[String] = []
var _planned_powers: Array[int] = []
var _command_hand: Array[Dictionary] = []
var _discarded_cards: Array[Dictionary] = []
var _action_points := 3
var _result_layer: Control
var _result_title: Label
var _result_body: Label
var _result_count: Label
var _help_layer: Control
var _corridor_layer: Control
var _corridor_box: VBoxContainer
var _pending_relic_choices: Array[String] = []


func _ready() -> void:
	rng.randomize()
	game = Match.create(rng.randi(), true)
	_seed_starter_squad()
	_font = load("res://assets/IBMPlexSansKR-Regular.otf")
	if _font == null or not _font.has_char("가".unicode_at(0)):
		_font = load("res://assets/Galmuri11.ttf")
	var project_theme := Theme.new()
	project_theme.default_font = _font
	project_theme.default_font_size = 15
	theme = project_theme
	_build_ui()
	corridor = CorridorRun.new(rng.randi())
	_show_corridor()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := VesperBackdropScene.new()
	add_child(backdrop)
	_prep = SquadPrepViewScene.new()
	add_child(_prep)
	_prep.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prep.ready_requested.connect(_start_battle)
	_prep.help_requested.connect(_show_help)
	_build_battle()
	_build_result()
	_build_help()
	_build_corridor()


func _build_corridor() -> void:
	_corridor_layer = Control.new()
	_corridor_layer.z_index = 60
	add_child(_corridor_layer)
	_corridor_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.09, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_corridor_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_corridor_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(760.0, maxf(320.0, get_viewport_rect().size.x - 32.0)), 410)
	panel.add_theme_stylebox_override("panel", _panel_style("122326"))
	center.add_child(panel)
	_corridor_box = VBoxContainer.new()
	_corridor_box.add_theme_constant_override("separation", 14)
	panel.add_child(_corridor_box)


func _build_battle() -> void:
	_battle_layer = Control.new()
	add_child(_battle_layer)
	_battle_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle_layer.visible = false
	var root_box := VBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", 0)
	_battle_layer.add_child(root_box)
	var top := PanelContainer.new()
	top.custom_minimum_size.y = 76
	top.add_theme_stylebox_override("panel", _panel_style("122326"))
	root_box.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	top.add_child(row)
	_battle_top = _label("", 16, "e8efeb")
	_battle_top.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_battle_top.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_battle_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_battle_top)
	_speed_btn = _button("배속 x1", _on_speed)
	row.add_child(_speed_btn)
	_command_btn = _button("지휘기", _on_command)
	row.add_child(_command_btn)
	for i in 3:
		var plan_button := _button("", _on_card_pressed.bind(i))
		plan_button.custom_minimum_size.x = 110
		_plan_buttons.append(plan_button)
		row.add_child(plan_button)
	_confirm_plan_btn = _button("작전 확정", _confirm_plan)
	_confirm_plan_btn.custom_minimum_size.x = 88
	row.add_child(_confirm_plan_btn)
	row.add_child(_button("도움말", _show_help))
	_view = BattlePresenter.new()
	_view.font = _font
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(_view)


func _build_result() -> void:
	_result_layer = Control.new()
	_result_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_layer.z_index = 50
	add_child(_result_layer)
	_result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.03, 0.035, 0.82)
	_result_layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_result_layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 310)
	panel.add_theme_stylebox_override("panel", _panel_style("183032"))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	_result_title = _label("", 28, "f3c777")
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_title)
	_result_body = _label("", 14, "e8efeb")
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_result_body)
	_result_count = _label("", 12, "8fa6a8")
	_result_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_count)
	var next := _button("계속", _on_result_continue)
	next.custom_minimum_size.y = 42
	box.add_child(next)


func _build_help() -> void:
	_help_layer = Control.new()
	_help_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_layer.z_index = 100
	add_child(_help_layer)
	_help_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.03, 0.035, 0.90)
	_help_layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_help_layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 0)
	panel.add_theme_stylebox_override("panel", _panel_style("183032"))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := _label("STARLINE — 강림 순서를 설계하세요", 22, "f3c777")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_help_step("① 5개의 항성 기억 중 사도를 호출한다", "같은 기억 셋은 자동으로 중첩 관측되고, 같은 원소의 사도를 모으면 강해집니다."))
	box.add_child(_help_step("② 9칸 대기석에서 강림 편성판으로 옮긴다", "편성판 왼쪽 사도부터 차례로 단일 항성 회랑에 강림합니다."))
	box.add_child(_help_step("③ 상대 편성과 관측 순위를 보고 순서를 확정한다", "강한 사도를 앞에 두면 항성 기운을 모으는 동안 전선이 빕니다."))
	var rule := _label("근접 ▶ 원거리 ▶ 방어 ▶ 근접  ·  전투는 자동 진행", 14, "8bd9c6")
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rule)
	var close := _button("관측 회랑으로", _hide_help)
	close.custom_minimum_size.y = 42
	box.add_child(close)


func _help_step(title: String, body: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_child(_label(title, 16, "e8efeb"))
	box.add_child(_label("     " + body, 13, "b3c4c2"))
	return box


func _show_help() -> void:
	_help_layer.visible = true


func _hide_help() -> void:
	_help_layer.visible = false


func _begin_round() -> void:
	if corridor != null and corridor.is_finished():
		_show_corridor_result()
		return
	phase = Phase.PREP
	sim = null
	_view.bind_sim(null)
	_command_left = 0.0
	_result_layer.visible = false
	_battle_layer.visible = false
	_prep.visible = true
	_configure_corridor_encounter()
	pairs = game.pair_up()
	_normalize_human_pair()
	_prep_left = FIRST_PREP_TIME if round_no == 1 else PREP_TIME
	_prep.bind_match(game)
	_prep.set_time_left(_prep_left)
	_prep.set_message("항성 기억을 호출하고 왼쪽부터 강림 순서를 만드세요.")


func _normalize_human_pair() -> void:
	foe_seat = -1
	var human := game.human_seat().index
	for i in pairs.size():
		var pair: Array = pairs[i]
		if int(pair[0]) == human:
			foe_seat = int(pair[1])
			break
		if int(pair[1]) == human:
			pairs[i] = [human, int(pair[0])]
			foe_seat = int(pair[0])
			break
	game.current_pairs = pairs.duplicate(true)


func _configure_corridor_encounter() -> void:
	if corridor == null:
		return
	var node := corridor.current()
	var kind := str(node.get("kind", "전투"))
	var ids: Array[String] = ["aries", "sagittarius"]
	if kind == "엘리트":
		ids = ["taurus", "aries", "sagittarius", "scorpio"]
	elif kind == "보스":
		ids = ["capricorn", "sagittarius", "virgo", "scorpio", "aries"]
	var foe := game.seats[1].player
	foe.roster.clear()
	var threat := float(node.get("threat", 1.0))
	var threat_level := maxi(0, roundi((threat - 1.0) * 3.0))
	foe.level = clampi(3 + ids.size() + threat_level, UnitDB.MIN_LEVEL, UnitDB.MAX_LEVEL)
	for i in ids.size():
		foe.roster.append({"def_id": ids[i], "star": 2 if kind == "보스" or kind == "엘리트" else 1, "order": i})


func _process(delta: float) -> void:
	if _help_layer != null and _help_layer.visible:
		return
	match phase:
		Phase.MAP:
			return
		Phase.PREP:
			_prep_left = maxf(0.0, _prep_left - delta)
			_prep.set_time_left(_prep_left)
			if _prep_left <= 5.0 and player.queue_count() == 0:
				_prep.set_message("편성된 사도가 없습니다 — 이번 회차는 빈 회랑으로 맞섭니다.")
			if _prep_left <= 0.0:
				_start_battle(true)
		Phase.BATTLE:
			_command_left = maxf(0.0, _command_left - delta)
			_step_battle(delta)
		Phase.RESULT:
			_result_left = maxf(0.0, _result_left - delta)
			_result_count.text = "%.1f초 뒤 다음 밤" % _result_left
			if _result_left <= 0.0:
				_next_round()


func _start_battle(from_timeout: bool = false) -> void:
	if phase != Phase.PREP:
		return
	if player.queue_count() == 0 and not from_timeout:
		_prep.set_message("강림 편성판에 사도를 하나 이상 올려야 준비를 마칠 수 있습니다.")
		return
	if foe_seat < 0 or foe_seat == game.human_seat().index:
		_resolve_and_show({})
		return
	sim = game.build_sim(game.human_seat().index, foe_seat)
	_view.label_left = game.human_seat().name
	_view.label_right = game.seats[foe_seat].name
	_view.bind_sim(sim)
	_view.set_playback_speed(speed)
	_command_left = 0.0
	_turn_left = 0.0
	_enter_plan()
	_accum = 0.0
	_prep.visible = false
	_battle_layer.visible = true
	_refresh_battle_hud()


func _on_tactical_order(order: String) -> void:
	if phase != Phase.PLAN or sim == null:
		return
	if _action_points <= 0:
		return
	_planned_orders.append(order)
	_action_points -= 1
	_refresh_battle_hud()


func _card_catalog() -> Array[Dictionary]:
	return [
		{"id": "charge", "name": "선봉 돌격", "order": "전진", "power": 1, "cost": 1, "hint": "전선 +12"},
		{"id": "breakthrough", "name": "강행 돌파", "order": "전진", "power": 2, "cost": 2, "hint": "전선 +24"},
		{"id": "guard", "name": "보호 진형", "order": "방어", "power": 1, "cost": 1, "hint": "전원 보호막"},
		{"id": "fortify", "name": "긴급 방벽", "order": "방어", "power": 2, "cost": 2, "hint": "강한 보호막"},
		{"id": "focus", "name": "집중 사격", "order": "집중", "power": 1, "cost": 1, "hint": "최약 적 36 피해"},
		{"id": "execute", "name": "처형 명령", "order": "집중", "power": 2, "cost": 2, "hint": "최약 적 72 피해"},
	]


func _draw_hand() -> void:
	_command_hand.clear()
	var deck := _card_catalog()
	deck.shuffle()
	for i in mini(3, deck.size()):
		_command_hand.append(deck[i])


func _on_card_pressed(hand_index: int) -> void:
	if phase != Phase.PLAN or sim == null:
		return
	if hand_index < 0 or hand_index >= _command_hand.size():
		return
	var card: Dictionary = _command_hand[hand_index]
	var card_cost := int(card["cost"])
	if _action_points < card_cost:
		return
	_action_points -= card_cost
	_planned_orders.append(str(card["order"]))
	_planned_powers.append(int(card["power"]))
	_discarded_cards.append(card)
	_command_hand.remove_at(hand_index)
	_refresh_battle_hud()


func _confirm_plan() -> void:
	if phase != Phase.PLAN or sim == null or _planned_orders.is_empty():
		return
	for i in _planned_orders.size():
		sim.apply_tactical_order(_planned_orders[i], _planned_powers[i])
	phase = Phase.BATTLE
	_turn_left = 6.0
	_refresh_battle_hud()


func _enter_plan() -> void:
	phase = Phase.PLAN
	_action_points = 3
	_planned_orders.clear()
	_planned_powers.clear()
	_draw_hand()
	_refresh_battle_hud()


func _step_battle(delta: float) -> void:
	if sim == null:
		return
	_accum += delta * speed
	var guard := 0
	while _accum >= Defs.TICK and not sim.finished and guard < 900:
		sim.step(Defs.TICK)
		_accum -= Defs.TICK
		guard += 1
	_refresh_battle_hud()
	if sim.finished:
		_resolve_and_show({game.human_seat().index: sim.result()})
	elif _turn_left <= 0.0:
		_enter_plan()


func _refresh_battle_hud() -> void:
	if sim == null:
		return
	var ally_front := 0.0
	var enemy_front := 100.0
	for unit in sim.units:
		if not unit.is_active():
			continue
		if unit.team == 0:
			ally_front = maxf(ally_front, unit.screen_x())
		else:
			enemy_front = minf(enemy_front, unit.screen_x())
	var line_state := "전선 균형"
	if ally_front - enemy_front > 8.0:
		line_state = "아군 전선 우세"
	elif enemy_front - ally_front > 8.0:
		line_state = "전선 밀림"
	var plan_text := "AP %d/3" % _action_points
	if not _planned_orders.is_empty():
		plan_text += "  예약: " + " + ".join(_planned_orders)
	var turn_state := plan_text if phase == Phase.PLAN else "라인 실행 중 · 다음 계획까지 %.1fs" % _turn_left
	_battle_top.text = "NIGHT %02d   %s  %d HP     VS     %d HP  %s\n%.1fs / %ds   ·   %s  ·  %s" % [
		round_no, game.human_seat().name, int(sim.core_hp[0]), int(sim.core_hp[1]),
		game.seats[foe_seat].name, sim.time, int(Defs.MAX_BATTLE_TIME), line_state, turn_state]
	if not player.relics.is_empty():
		_battle_top.text += "   ·   유물: " + ", ".join(_relic_names(player.relics))
	_command_btn.disabled = phase != Phase.BATTLE or _command_left > 0.0 or sim.finished
	_command_btn.text = "지휘기 %.1f" % _command_left if _command_left > 0.0 else "지휘기"
	for i in _plan_buttons.size():
		var plan_button := _plan_buttons[i]
		if phase == Phase.PLAN and i < _command_hand.size():
			var card: Dictionary = _command_hand[i]
			plan_button.text = "%s\n%d AP · %s" % [card["name"], card["cost"], card["hint"]]
			plan_button.tooltip_text = "%s: %s" % [card["name"], card["hint"]]
			plan_button.disabled = sim.finished or _action_points < int(card["cost"])
		else:
			plan_button.text = "빈 손패"
			plan_button.disabled = true
	_confirm_plan_btn.disabled = phase != Phase.PLAN or sim.finished or _planned_orders.is_empty()


func _on_command() -> void:
	if phase != Phase.BATTLE or sim == null or _command_left > 0.0:
		return
	if sim.cast_command_strike(48.0):
		_command_left = 12.0
		_refresh_battle_hud()


func _on_tactic(tactic: String) -> void:
	if phase != Phase.PREP:
		return
	player.tactic = tactic
	_prep.set_message("전술 변경: %s — %s" % [tactic, _tactic_description(tactic)])
	_prep.refresh_all()


func _tactic_description(tactic: String) -> String:
	return {"압박":"공격력 +12%", "요새":"최대 HP +15%, 공격 속도 -8%", "순환":"공격 속도 +14%, 최대 HP -8%"}.get(tactic, "")


func _resolve_and_show(precomputed: Dictionary) -> void:
	var before_hp := player.hp
	var this_round := round_no
	game.resolve_round(pairs, precomputed)
	var lost := before_hp - player.hp
	var human := game.human_seat().index
	var settle := {}
	var verdict := "두 관측 기록이 맞섰다"
	for result in game.last_results:
		if int(result["a"]) != human and int(result["b"]) != human:
			continue
		settle = result["settle_a"] if int(result["a"]) == human else result["settle_b"]
		if int(result["winner_seat"]) == human:
			verdict = "승리"
		elif int(result["winner_seat"]) >= 0:
			verdict = "패배"
		break
	var income := int(settle.get("income", 0))
	var interest := int(settle.get("interest", 0))
	var streak_bonus := int(settle.get("streak_bonus", 0))
	_result_title.text = verdict
	_result_body.text = "%d번째 밤 · %s vs %s\n\n체력 -%d   ·   수입 +%d   ·   이자 +%d   ·   연속 보너스 +%d\n현재 체력 %d   ·   골드 %d   ·   생존 관측자 %d/%d\n\n%s" % [
		this_round, game.seats[human].name,
		game.seats[foe_seat].name if foe_seat >= 0 else "고요한 밤", lost, income, interest,
		streak_bonus, player.hp, player.gold, game.living_seats().size(), Match.SEATS,
		_other_results(human)]
	_result_layer.visible = true
	_battle_layer.visible = true
	_prep.visible = false
	if sim != null:
		_view.show_victory(sim.winner)
	if not player.is_alive() or game.is_over():
		phase = Phase.GAMEOVER
		_result_title.text = "오늘의 밤이 끝났다 — 최종 %d등" % game.human_placement()
		_result_count.text = "새로운 밤을 시작할 수 있습니다."
	else:
		corridor.complete_current()
		_queue_latest_relic_choice()
		phase = Phase.RESULT
		_result_left = RESULT_TIME
		_result_count.text = "계속을 눌러 유물을 선택하세요" if not _pending_relic_choices.is_empty() else "%.1f초 뒤 다음 회랑" % _result_left


func _other_results(human: int) -> String:
	var out: PackedStringArray = []
	for result in game.last_results:
		if int(result["a"]) == human or int(result["b"]) == human:
			continue
		var a := game.seats[int(result["a"])].name
		var b := game.seats[int(result["b"])].name
		var winner := int(result["winner_seat"])
		out.append("%s = %s" % [a, b] if winner < 0 else "%s > %s" % [
			game.seats[winner].name, b if winner == int(result["a"]) else a])
	return "다른 회랑:" + "   ".join(out) if not out.is_empty() else ""


func _on_result_continue() -> void:
	if phase == Phase.RESULT:
		if not _pending_relic_choices.is_empty():
			_show_relic_choice()
		elif corridor.is_finished():
			_show_corridor_result()
		else:
			_show_corridor()
	elif phase == Phase.GAMEOVER:
		_restart()


func _next_round() -> void:
	_begin_round()


func _restart() -> void:
	rng.randomize()
	game = Match.create(rng.randi(), true)
	_seed_starter_squad()
	corridor = CorridorRun.new(rng.randi())
	speed = 1.0
	_speed_btn.text = "배속 x1"
	_show_corridor()


func _seed_starter_squad() -> void:
	var p := game.human_seat().player
	p.roster = [
		{"def_id":"aries", "star":1, "order":0},
		{"def_id":"sagittarius", "star":1, "order":1},
		{"def_id":"taurus", "star":1, "order":2},
	]


func _show_corridor() -> void:
	if corridor == null or corridor.is_finished():
		_show_corridor_result()
		return
	phase = Phase.MAP
	_prep.visible = false
	_battle_layer.visible = false
	_result_layer.visible = false
	_help_layer.visible = false
	_corridor_layer.visible = true
	for child in _corridor_box.get_children():
		child.queue_free()
	var title := _label("VESPER CORRIDOR  //  회랑 탐험", 26, "f3c777")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corridor_box.add_child(title)
	var current := corridor.current()
	var path := HBoxContainer.new()
	path.alignment = BoxContainer.ALIGNMENT_CENTER
	path.add_theme_constant_override("separation", 8)
	for floor in range(1, 6):
		var node_mark := _label("●\n%d" % floor, 13, "72d7d0" if floor < int(current.get("floor", 1)) else "f2b95f" if floor == int(current.get("floor", 1)) else "60788a")
		node_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		path.add_child(node_mark)
		if floor < 5:
			path.add_child(_label("—", 13, "38566b"))
	_corridor_box.add_child(path)
	var info := _label("SEED %d   ·   FLOOR %d/5\n%s  ·  위협 배율 %.1f" % [corridor.seed, int(current.get("floor", 1)), current.get("name", ""), float(current.get("threat", 1.0))], 15, "b9cfca")
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corridor_box.add_child(info)
	var note := _label("전투 노드에서는 기존 라인배틀러 준비와 전투가 이어집니다.\n보급과 이벤트를 선택하면 다음 전투를 유리하게 만들 수 있습니다.", 14, "e8efeb")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corridor_box.add_child(note)
	if not player.relics.is_empty():
		var relics := _label("보유 유물: " + ", ".join(_relic_names(player.relics)), 13, "8bd9c6")
		relics.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_corridor_box.add_child(relics)
	var options := corridor.available_options()
	if not options.is_empty():
		_corridor_box.add_child(_label("2층 경로를 선택하세요", 15, "f3c777"))
		for i in options.size():
			var option: Dictionary = options[i]
			var option_button := _button("%s  ·  위협 %.1f" % [option.get("name", "회랑"), float(option.get("threat", 1.0))], _choose_corridor.bind(i))
			option_button.custom_minimum_size.y = 46
			_corridor_box.add_child(option_button)
	else:
		var enter := _button("%s 진입" % current.get("name", "회랑"), _choose_corridor)
		enter.custom_minimum_size.y = 52
		_corridor_box.add_child(enter)
	var restart := _button("새 회랑 생성", _restart)
	_corridor_box.add_child(restart)


func _choose_corridor(option_index: int = -1) -> void:
	if phase != Phase.MAP:
		return
	if option_index >= 0 and not corridor.choose_option(option_index):
		return
	_corridor_layer.visible = false
	var node := corridor.current()
	var kind := str(node.get("kind", "전투"))
	if kind == "보급" or kind == "이벤트":
		var p := game.human_seat().player
		p.gold += 6 if kind == "보급" else 3
		p.hp = mini(Econ.START_HP, p.hp + (12 if kind == "보급" else 0))
		corridor.complete_current()
		_queue_latest_relic_choice()
		_show_relic_choice() if not _pending_relic_choices.is_empty() else _show_corridor()
		return
	game.seats[1].name = str(node.get("name", "회랑의 적"))
	_begin_round()
	_show_help()


func _show_corridor_result() -> void:
	phase = Phase.GAMEOVER
	_result_layer.visible = true
	_battle_layer.visible = false
	_prep.visible = false
	_result_title.text = "회랑 돌파 완료"
	_result_body.text = "베스퍼 매듭을 통과했습니다.\n\n새로운 시드로 다시 회랑에 도전할 수 있습니다."
	_result_count.text = "RUN CLEAR"


func _queue_latest_relic_choice() -> void:
	_pending_relic_choices.clear()
	if corridor.rewards.is_empty():
		return
	var reward: Dictionary = corridor.rewards.back()
	for relic in reward.get("relic_choices", []):
		if not player.relics.has(str(relic)):
			_pending_relic_choices.append(str(relic))


func _show_relic_choice() -> void:
	phase = Phase.MAP
	_prep.visible = false
	_battle_layer.visible = false
	_result_layer.visible = false
	_help_layer.visible = false
	_corridor_layer.visible = true
	for child in _corridor_box.get_children():
		child.queue_free()
	var title := _label("회랑 보상  //  유물 하나를 선택하세요", 25, "f3c777")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corridor_box.add_child(title)
	var body := _label("선택한 유물은 이번 런이 끝날 때까지 모든 라인 전투에 적용됩니다.", 14, "e8efeb")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corridor_box.add_child(body)
	for relic in _pending_relic_choices:
		var button := _button("%s\n%s" % [_relic_name(relic), _relic_description(relic)], _choose_relic.bind(relic))
		button.custom_minimum_size.y = 58
		_corridor_box.add_child(button)


func _choose_relic(relic: String) -> void:
	if not _pending_relic_choices.has(relic):
		return
	player.relics.append(relic)
	_pending_relic_choices.clear()
	_show_corridor()


func _relic_names(relics: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for relic in relics:
		out.append(_relic_name(relic))
	return out


func _relic_name(relic: String) -> String:
	return {"ember_cache":"잔불 보관함", "signal_lens":"신호 렌즈", "hollow_crown":"공허 왕관"}.get(relic, relic)


func _relic_description(relic: String) -> String:
	return {"ember_cache":"아군 최대 HP +10%", "signal_lens":"아군 공격 속도 +12%", "hollow_crown":"아군 공격력 +15%"}.get(relic, "알 수 없는 효과")


func _on_buy(slot: int) -> void:
	_prep.set_message("" if econ.buy(player, slot) else "골드가 모자라거나 대기석이 가득 찼습니다.")
	_prep.refresh_all()


func _on_sell(index: int) -> void:
	if econ.sell(player, index):
		_prep.set_message("항성 기억을 공용 관측망으로 돌려보냈습니다.")
	_prep.refresh_all()


func _on_place(index: int, order: int) -> void:
	_prep.set_message("" if econ.enqueue(player, index, order) else "강림 슬롯이 가득 찼습니다. 레벨을 올리세요.")
	_prep.refresh_all()


func _on_to_bench(index: int) -> void:
	_prep.set_message("" if econ.to_bench(player, index) else "대기석이 가득 찼습니다.")
	_prep.refresh_all()


func _on_reroll() -> void:
	if not econ.reroll(player):
		_prep.set_message("새 항성 기억을 호출할 골드가 모자랍니다.")
	_prep.refresh_all()


func _on_buy_xp() -> void:
	if not econ.buy_xp(player):
		_prep.set_message("경험치를 살 수 없습니다.")
	_prep.refresh_all()


func _on_lock() -> void:
	econ.set_shop_locked(player, not player.shop_locked)
	_prep.set_message("잠근 호출 신호는 다음 회차에도 유지됩니다." if player.shop_locked else "호출 신호 잠금을 풀었습니다.")
	_prep.refresh_all()


func _on_speed() -> void:
	speed = 1.0 if speed >= 4.0 else speed * 2.0
	_speed_btn.text = "배속 x%d" % int(speed)
	_view.set_playback_speed(speed)


func _panel_style(color_hex: String) -> StyleBoxFlat:
	return VesperUITheme.panel(Color(color_hex), VesperUITheme.LINE, 8)


func _label(text: String, font_size: int, color_hex: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(color_hex))
	return label


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	VesperUITheme.apply_button(button)
	button.clip_text = true
	button.pressed.connect(callback)
	return button
