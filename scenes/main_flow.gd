extends Control

const VesperUITheme = preload("res://scenes/ui/vesper_ui.gd")
const VesperBackdropScene = preload("res://scenes/ui/vesper_backdrop.gd")
const SquadPrepViewScene = preload("res://scenes/prep/squad_prep_view.gd")

## STARLINE의 준비 → 전투 → 결과 → 게임오버 흐름.
## STARLINE gameplay core와 Vesper passive presentation을 연결한다.

enum Phase { MAP, PREP, BATTLE, RESULT, GAMEOVER }

const FIRST_PREP_TIME := 45.0
const PREP_TIME := 30.0
const RESULT_TIME := 4.0

var game: CorridorSession
var corridor: CorridorRun
var sim: CombatSim = null
var phase := Phase.PREP
var speed := 1.0
var rng := RandomNumberGenerator.new()
var pairs: Array = []
var foe_seat := -1

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
var _plan_buttons: Array[Button] = []
var _result_layer: Control
var _result_title: Label
var _result_body: Label
var _result_count: Label
var _help_layer: Control
var _corridor_layer: Control
var _corridor_box: VBoxContainer
var _pending_relic_choices: Array[String] = []
var _intro_pending := true
var _squad_locked := false
var _encounter_kind := "전투"
var _prep_expired := false
var _has_seen_battle_help := false
var _help_close: Button
var _help_return_focus: Control


func _ready() -> void:
	rng.randomize()
	game = CorridorSession.create(rng.randi())
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
	row.add_child(_button("도움말", _show_help))
	_view = BattlePresenter.new()
	_view.font = _font
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(_view)
	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size.y = 132
	card_panel.add_theme_stylebox_override("panel", _panel_style("0d1a25"))
	root_box.add_child(card_panel)
	var card_bar := HBoxContainer.new()
	card_bar.add_theme_constant_override("separation", 10)
	card_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	card_panel.add_child(card_bar)
	for i in 4:
		var plan_button := _button("", _on_deploy_card.bind(i))
		plan_button.custom_minimum_size = Vector2(128, 96)
		plan_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plan_button.add_theme_font_size_override("font_size", 14)
		_plan_buttons.append(plan_button)
		card_bar.add_child(plan_button)


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
	var title := _label("STARLINE — 회랑을 돌파하는 법", 22, "f3c777")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_help_step("① 후보 3명 중 1명씩 4명을 고른다", "매번 다른 후보가 제시됩니다. 드래프트한 원정대는 이번 런 내내 함께하며, 휴식처에서는 선봉 순서를 바꿀 수 있습니다."))
	box.add_child(_help_step("② 전투 중 하단 카드를 눌러 사도를 출격한다", "코스트는 시간이 지나면 차오릅니다. 누구를 먼저 내보낼지, 언제 아껴둘지가 핵심입니다."))
	box.add_child(_help_step("③ 지도를 고르고 유물을 쌓는다", "엘리트는 강하지만 보상이 좋습니다. 보스 전에는 회복과 유물 조합을 준비하세요."))
	var rule := _label("코스트가 차면 하단 사도 카드를 눌러 출격  ·  전투는 실시간 진행", 14, "8bd9c6")
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rule)
	_help_close = _button("관측 회랑으로", _hide_help)
	var close := _help_close
	close.custom_minimum_size.y = 42
	box.add_child(close)


func _help_step(title: String, body: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_child(_label(title, 16, "e8efeb"))
	box.add_child(_label("     " + body, 13, "b3c4c2"))
	return box


func _show_help() -> void:
	_help_return_focus = get_viewport().gui_get_focus_owner()
	_help_layer.visible = true
	_help_close.call_deferred("grab_focus")


func _hide_help() -> void:
	_help_layer.visible = false
	if is_instance_valid(_help_return_focus):
		_help_return_focus.call_deferred("grab_focus")
	_help_return_focus = null


func _input(event: InputEvent) -> void:
	if _help_layer == null or not _help_layer.visible or not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_ESCAPE:
		_hide_help()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_TAB:
		_help_close.grab_focus()
		get_viewport().set_input_as_handled()


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
	_prep_expired = false
	_prep.bind_match(game)
	_prep.set_time_left(_prep_left)
	_prep.set_message("후보 3명 중 1명씩 선택해 원정대 4명을 완성하세요.")
	if _squad_locked:
		_prep.visible = false
		_start_battle()


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
	_encounter_kind = kind
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
		foe.roster.append({"def_id": ids[i], "star": 2 if kind == "보스" or kind == "엘리트" else 1, "order": i, "encounter_pattern": kind if kind == "보스" or kind == "엘리트" else ""})


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
			if _prep_left <= 0.0 and not _prep_expired:
				_prep_expired = true
				if player.queue_count() == 4:
					_start_battle(true)
				else:
					_prep.set_message("원정대 4명을 모두 선택해야 전투를 시작할 수 있습니다.")
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
	if player.queue_count() != 4:
		_prep.set_message("원정대 4명을 모두 선택해야 전투를 시작할 수 있습니다.")
		return
	if foe_seat < 0 or foe_seat == game.human_seat().index:
		_resolve_and_show({})
		return
	sim = game.build_sim(game.human_seat().index, foe_seat)
	_squad_locked = true
	_view.label_left = game.human_seat().name
	_view.label_right = game.seats[foe_seat].name
	_view.bind_sim(sim)
	_view.set_playback_speed(speed)
	_view.set_field_scroll(0.0)
	_command_left = 0.0
	phase = Phase.BATTLE
	_accum = 0.0
	_prep.visible = false
	_battle_layer.visible = true
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


func _refresh_battle_hud() -> void:
	if sim == null:
		return
	var ally_front := 0.0
	var enemy_front := Defs.FIELD_LEN
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
	var turn_state := "실시간 출격 · 코스트 %.1f/14" % float(sim.cost[0])
	var pattern_state := ""
	var interval := 6.0 if _encounter_kind == "엘리트" else 5.0 if _encounter_kind == "보스" else 0.0
	if interval > 0.0:
		var until_pattern := interval - fmod(sim.time, interval)
		pattern_state = "  ·  ⚠ %s %.1fs" % ["검은 파동" if _encounter_kind == "엘리트" else "매듭 재생", until_pattern]
	_battle_top.text = "NIGHT %02d   %s  %d HP     VS     %d HP  %s\n%.1fs / %ds   ·   %s  ·  %s" % [
		round_no, game.human_seat().name, int(sim.core_hp[0]), int(sim.core_hp[1]),
		game.seats[foe_seat].name, sim.time, int(Defs.MAX_BATTLE_TIME), line_state, turn_state + pattern_state]
	if not player.relics.is_empty():
		_battle_top.text += "   ·   유물: " + ", ".join(_relic_names(player.relics))
	_command_btn.disabled = phase != Phase.BATTLE or _command_left > 0.0 or sim.finished or not _has_active_enemy()
	_command_btn.text = "지휘기 %.1f" % _command_left if _command_left > 0.0 else "지휘기"
	var available: Array = []
	for unit in sim.units:
		if unit.team == 0 and not unit.deployed and unit.alive:
			available.append(unit)
	for i in _plan_buttons.size():
		var plan_button := _plan_buttons[i]
		if phase == Phase.BATTLE and i < available.size():
			var unit: CombatSim.SimUnit = available[i]
			var can_deploy := float(sim.cost[0]) >= unit.deploy_cost
			plan_button.text = "%s\n%d 코스트 · %s" % [unit.display_name, int(unit.deploy_cost), "출격 가능" if can_deploy else "충전 중"]
			plan_button.tooltip_text = "%s 출격 · 현재 코스트 %.1f" % [unit.display_name, float(sim.cost[0])]
			plan_button.disabled = sim.finished or not can_deploy
		else:
			plan_button.text = "출격 완료"
			plan_button.disabled = true
func _on_deploy_card(hand_index: int) -> void:
	if phase != Phase.BATTLE or sim == null or sim.finished:
		return
	var available: Array = []
	for unit in sim.units:
		if unit.team == 0 and not unit.deployed and unit.alive:
			available.append(unit)
	if hand_index < 0 or hand_index >= available.size():
		return
	var unit: CombatSim.SimUnit = available[hand_index]
	if sim.manual_deploy(0, unit.uid):
		_refresh_battle_hud()


func _on_command() -> void:
	if phase != Phase.BATTLE or sim == null or _command_left > 0.0:
		return
	if sim.cast_command_strike(48.0):
		_command_left = 12.0
		_refresh_battle_hud()


func _has_active_enemy() -> bool:
	if sim == null:
		return false
	for unit in sim.units:
		if unit.team == 1 and unit.is_active():
			return true
	return false


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
	_result_body.text = "%d번째 원정 전투 · %s vs %s\n\n체력 -%d   ·   수입 +%d   ·   이자 +%d   ·   연속 보너스 +%d\n현재 원정 체력 %d   ·   골드 %d\n\n다음 층으로 이동할 수 있습니다." % [
		this_round, game.seats[human].name,
		game.seats[foe_seat].name if foe_seat >= 0 else "고요한 밤", lost, income, interest,
		streak_bonus, player.hp, player.gold]
	_result_layer.visible = true
	_battle_layer.visible = true
	_prep.visible = false
	if sim != null:
		_view.show_victory(sim.winner)
	if not player.is_alive() or game.is_over():
		phase = Phase.GAMEOVER
		_result_title.text = "원정 실패"
		_result_count.text = "새로운 원정을 시작할 수 있습니다."
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
	game = CorridorSession.create(rng.randi())
	_seed_starter_squad()
	corridor = CorridorRun.new(rng.randi())
	_intro_pending = true
	_squad_locked = false
	_has_seen_battle_help = false
	speed = 1.0
	_speed_btn.text = "배속 x1"
	_show_corridor()


func _seed_starter_squad() -> void:
	var p := game.human_seat().player
	p.roster = []


func _show_corridor() -> void:
	if corridor == null or corridor.is_finished():
		_show_corridor_result()
		return
	if _intro_pending:
		_show_expedition_intro()
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
	var note := _label("전투 노드에서는 하단 사도 카드를 눌러 실시간으로 출격합니다.\n보급·이벤트·휴식처에서 다음 전투를 준비할 수 있습니다.", 14, "e8efeb")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corridor_box.add_child(note)
	if not player.relics.is_empty():
		var relics := _label("보유 유물: " + ", ".join(_relic_names(player.relics)), 13, "8bd9c6")
		relics.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_corridor_box.add_child(relics)
	var options := corridor.available_options()
	if not options.is_empty():
		_corridor_box.add_child(_label("%d층 경로를 선택하세요" % int(current.get("floor", 1)), 15, "f3c777"))
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


func _show_expedition_intro() -> void:
	phase = Phase.MAP
	_prep.visible = false
	_battle_layer.visible = false
	_result_layer.visible = false
	_help_layer.visible = false
	_corridor_layer.visible = true
	for child in _corridor_box.get_children():
		child.queue_free()
	var kicker := _label("VESPER // 원정 기록 01", 12, "8bd9c6")
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corridor_box.add_child(kicker)
	var title := _label("회랑으로 내려간다", 30, "f3c777")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corridor_box.add_child(title)
	var rule := _label("빛이 끊긴 뒤에는, 선택만이 길을 만든다.", 15, "e8efeb")
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corridor_box.add_child(rule)
	_corridor_box.add_child(HSeparator.new())
	var mission := _label("이번 원정의 목표\n5개 층을 통과하고 베스퍼 매듭을 파괴하세요.\n전투에서 출격 타이밍을 잡고, 쓰러지기 전에 회복할 장소를 찾으세요.", 14, "b9cfca")
	mission.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_corridor_box.add_child(mission)
	var squad_names: PackedStringArray = []
	for unit in player.queued_units():
		var def := UnitDB.get_def(str(unit.get("def_id", "")))
		squad_names.append(str(def.get("name", "미확인")))
	var squad_summary := "  /  ".join(squad_names) if not squad_names.is_empty() else "드래프트로 4명 선택"
	var squad := _label("원정대  ·  " + squad_summary + "\n출격 카드  ·  4장  ·  유물 %d개" % player.relics.size(), 14, "f2b95f")
	squad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corridor_box.add_child(squad)
	var warning := _label("경고  ·  회랑에서는 쓰러진 사도를 되살릴 수 없습니다.", 12, "d28d7d")
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corridor_box.add_child(warning)
	var start := _button("원정 시작", _start_expedition)
	VesperUITheme.apply_button(start, true)
	start.custom_minimum_size.y = 54
	_corridor_box.add_child(start)


func _start_expedition() -> void:
	_intro_pending = false
	_show_corridor()


func _choose_corridor(option_index: int = -1) -> void:
	if phase != Phase.MAP:
		return
	if option_index >= 0 and not corridor.choose_option(option_index):
		return
	_corridor_layer.visible = false
	var node := corridor.current()
	var kind := str(node.get("kind", "전투"))
	if kind == "휴식":
		_show_rest_choice()
		return
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
	if not _has_seen_battle_help:
		_has_seen_battle_help = true
		_show_help()


func _show_corridor_result() -> void:
	phase = Phase.GAMEOVER
	_result_layer.visible = true
	_battle_layer.visible = false
	_prep.visible = false
	_result_title.text = "회랑 돌파 완료"
	_result_body.text = "베스퍼 매듭을 통과했습니다.\n\n새로운 시드로 다시 회랑에 도전할 수 있습니다."
	_result_count.text = "RUN CLEAR"


func _show_rest_choice() -> void:
	phase = Phase.MAP
	_prep.visible = false
	_battle_layer.visible = false
	_result_layer.visible = false
	_help_layer.visible = false
	_corridor_layer.visible = true
	for child in _corridor_box.get_children():
		child.queue_free()
	var title := _label("휴식처  //  다음 전투를 준비하세요", 25, "f3c777")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corridor_box.add_child(title)
	var body := _label("한 번만 선택할 수 있습니다. 회복하거나, 출격 진형을 재정비하세요.", 14, "e8efeb")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corridor_box.add_child(body)
	var heal := _button("회복  ·  체력 +20", _rest_heal)
	heal.custom_minimum_size.y = 58
	_corridor_box.add_child(heal)
	var reorder := _button("진형 재정비  ·  선봉 교대", _rest_reorder)
	reorder.custom_minimum_size.y = 58
	_corridor_box.add_child(reorder)


func _rest_heal() -> void:
	if corridor.current().get("kind", "") != "휴식":
		return
	player.hp = mini(Econ.START_HP, player.hp + 20)
	corridor.complete_current()
	_show_corridor()


func _rest_reorder() -> void:
	if corridor.current().get("kind", "") != "휴식" or player.queued_units().size() < 2:
		return
	var queued := player.queued_units()
	var first_order := int(queued[0].get("order", 0))
	queued[0]["order"] = int(queued[queued.size() - 1].get("order", queued.size() - 1))
	queued[queued.size() - 1]["order"] = first_order
	corridor.complete_current()
	_show_corridor()


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
	var body := _label("선택한 유물은 이번 런 동안 모든 라인 전투에 적용됩니다.", 14, "e8efeb")
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
