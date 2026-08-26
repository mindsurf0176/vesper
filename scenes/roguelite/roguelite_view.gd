extends Control

## Vesper roguelite vertical slice.
## 기존 캐릭터 에셋을 재사용하고, 런/전투 상태는 데이터로만 관리한다.

const Actor = preload("res://scenes/duel/duel_actor.gd")
const Run = preload("res://core/roguelite_run.gd")

enum Phase { SELECT, MAP, BATTLE, REWARD, RESULT }

var phase := Phase.SELECT
var run
var roster: Array = []
var selected_team: Array[Dictionary] = []
var enemy_team: Array[Dictionary] = []
var player_hp: Array[float] = []
var enemy_hp: Array[float] = []
var player_active := 0
var enemy_active := 0
var turn := 1
var player_guarding := false
var enemy_intent := "공격"
var player_actor: Node2D
var enemy_actor: Node2D
var title: Label
var status: Label
var content: VBoxContainer
var action_row: HBoxContainer
var map_row: HBoxContainer
var team_label: Label
var enemy_label: Label
var log_label: Label
var hp_label: Label
var relic_label: Label
var selected_buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var font := load("res://assets/Galmuri11.ttf")
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 15
	self.theme = theme
	_build_shell()
	_show_select()

func _build_shell() -> void:
	var bg := ColorRect.new()
	bg.color = Color("091419")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 54)
	margin.add_theme_constant_override("margin_right", 54)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("f4ad52"))
	content.add_child(title)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_color", Color("c0d6d2"))
	content.add_child(status)

func _clear_content() -> void:
	for child in content.get_children():
		if child != title and child != status:
			child.queue_free()

func _show_select() -> void:
	phase = Phase.SELECT
	_clear_content()
	title.text = "VESPER // 회랑 편성"
	status.text = "이번 런에 데려갈 전투원 3명을 선택하세요."
	selected_team.clear()
	selected_buttons.clear()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	var state = get_node_or_null("/root/GameState")
	roster = state.all_chars_list() if state != null else []
	for def in roster:
		var button := Button.new()
		button.custom_minimum_size = Vector2(260, 104)
		button.text = "%s\n%s · %s" % [str(def.get("name", "전투원")), str(def.get("role", "")), str(def.get("rarity", "R"))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_toggle_fighter.bind(def, button))
		grid.add_child(button)
		selected_buttons.append(button)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	content.add_child(spacer)
	team_label = Label.new()
	team_label.add_theme_color_override("font_color", Color("f4ad52"))
	content.add_child(team_label)
	var start := Button.new()
	start.text = "회랑 출항"
	start.custom_minimum_size = Vector2(220, 52)
	start.disabled = true
	start.name = "StartRun"
	start.pressed.connect(_start_run)
	content.add_child(start)
	_update_select(start)

func _toggle_fighter(def: Dictionary, button: Button) -> void:
	var found := -1
	for i in selected_team.size():
		if str(selected_team[i].get("name", "")) == str(def.get("name", "")):
			found = i
	if found >= 0:
		selected_team.remove_at(found)
		button.modulate = Color.WHITE
	elif selected_team.size() < 3:
		selected_team.append(def.duplicate(true))
		button.modulate = Color("ffd98a")
	for child in content.get_children():
		if child.name == "StartRun":
			_update_select(child)

func _update_select(start: Button) -> void:
	start.disabled = selected_team.size() != 3
	var names: Array[String] = []
	for def in selected_team:
		names.append(str(def.get("name", "")))
	team_label.text = "편성 %d/3   %s" % [selected_team.size(), "  ·  ".join(names)]

func _start_run() -> void:
	run = Run.new(Time.get_unix_time_from_system())
	run.start_with_team(selected_team)
	_show_map()

func _show_map() -> void:
	phase = Phase.MAP
	_clear_content()
	title.text = "VESPER // 회랑 지도"
	status.text = "시드 %d   ·   유물 %d개   ·   변칙: %s" % [run.seed, run.relics.size(), _mutator_names()]
	map_row = HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 12)
	content.add_child(map_row)
	for i in run.nodes.size():
		var node: Dictionary = run.nodes[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(205, 150)
		button.text = "%s\n\nFLOOR %d\n위협 %.1f" % [str(node.get("type", "")), int(node.get("floor", 0)) + 1, float(node.get("threat", 1.0))]
		var branch_open: bool = run.node_index == 1 and i == 2
		button.disabled = i != run.node_index and not branch_open
		button.pressed.connect(_choose_node.bind(i))
		map_row.add_child(button)
	relic_label = Label.new()
	relic_label.text = "유물 없음"
	content.add_child(relic_label)
	var restart := Button.new()
	restart.text = "런 포기"
	restart.pressed.connect(_show_select)
	content.add_child(restart)

func _mutator_names() -> String:
	var names: Array[String] = []
	for item in run.mutators:
		names.append(str(item.get("name", "")))
	return " / ".join(names)

func _choose_node(index: int) -> void:
	var node: Dictionary = run.choose_next(index)
	if node.is_empty():
		return
	if str(node.get("type", "")) == "보급" or str(node.get("type", "")) == "회복":
		run.apply_rest(28.0)
		_show_reward("회복 완료", "팀 전체가 28 회복했습니다.")
	else:
		_start_battle(node)

func _start_battle(node: Dictionary) -> void:
	phase = Phase.BATTLE
	turn = 1
	player_active = 0
	enemy_active = 0
	player_guarding = false
	player_hp.clear(); enemy_hp.clear()
	for fighter in run.team:
		player_hp.append(float(fighter.get("run_hp", 100.0)))
	var enemy_seed := int(node.get("enemy_seed", 7))
	var enemy_rng := RandomNumberGenerator.new()
	enemy_rng.seed = enemy_seed
	enemy_team.clear()
	var pool := roster.duplicate()
	for i in 3:
		var pick: Dictionary = pool[enemy_rng.randi_range(0, pool.size() - 1)].duplicate(true)
		enemy_team.append(pick)
		enemy_hp.append(100.0 + float(node.get("threat", 1.0) - 1.0) * 20.0)
	_build_battle_ui(node)
	_update_battle_view()

func _build_battle_ui(node: Dictionary) -> void:
	_clear_content()
	title.text = "FLOOR %d  //  %s" % [int(node.get("floor", 0)) + 1, str(node.get("type", "전투"))]
	status.text = "TURN %d   ·   적 예고: %s" % [turn, enemy_intent]
	var team_row := HBoxContainer.new()
	team_row.add_theme_constant_override("separation", 30)
	content.add_child(team_row)
	var allies := Label.new()
	allies.custom_minimum_size = Vector2(430, 46)
	team_row.add_child(allies)
	team_label = allies
	var vs := Label.new()
	vs.text = "        VS        "
	vs.custom_minimum_size = Vector2(190, 46)
	team_row.add_child(vs)
	var foes := Label.new()
	foes.custom_minimum_size = Vector2(430, 46)
	team_row.add_child(foes)
	enemy_label = foes
	log_label = Label.new()
	log_label.custom_minimum_size.y = 42
	log_label.add_theme_color_override("font_color", Color("f6e8be"))
	content.add_child(log_label)
	hp_label = Label.new()
	content.add_child(hp_label)
	action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	content.add_child(action_row)
	_add_action("공격", "공격")
	_add_action("방어", "방어")
	_add_action("필살", "필살")
	_add_action("교대", "교대")

func _add_action(label: String, action: String) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(160, 58)
	button.pressed.connect(_player_action.bind(action))
	action_row.add_child(button)

func _player_action(action: String) -> void:
	if phase != Phase.BATTLE or _all_fallen(enemy_hp) or _all_fallen(player_hp):
		return
	var line := ""
	if action == "공격":
		var damage := 22.0 + float(selected_team[player_active].get("dmg", 10.0)) * 0.45
		if enemy_intent == "방어": damage *= 0.35
		enemy_hp[enemy_active] = maxf(0.0, enemy_hp[enemy_active] - damage)
		line = "%s의 공격! %s에게 %.0f 피해" % [selected_team[player_active].get("name", "전투원"), enemy_team[enemy_active].get("name", "적"), damage]
	elif action == "방어":
		player_guarding = true
		line = "%s가 방어 태세" % selected_team[player_active].get("name", "전투원")
	elif action == "필살":
		var damage := 42.0 + float(selected_team[player_active].get("dmg", 10.0))
		enemy_hp[enemy_active] = maxf(0.0, enemy_hp[enemy_active] - damage)
		line = "%s의 필살! %.0f 피해" % [selected_team[player_active].get("name", "전투원"), damage]
	elif action == "교대":
		player_active = _next_alive(player_hp, player_active)
		line = "%s가 전장에 합류" % selected_team[player_active].get("name", "전투원")
	player_hp[player_active] = maxf(0.0, player_hp[player_active])
	if _all_fallen(enemy_hp):
		_finish_battle(true, line)
		return
	_enemy_action()
	if phase != Phase.BATTLE:
		return
	log_label.text = line
	player_guarding = false
	turn += 1
	_update_battle_view()

func _enemy_action() -> void:
	enemy_intent = ["공격", "방어", "필살"][turn % 3]
	var damage := 18.0 + turn * 1.5
	if enemy_intent == "필살": damage *= 1.7
	if enemy_intent != "방어":
		if player_guarding: damage *= 0.25
		player_hp[player_active] = maxf(0.0, player_hp[player_active] - damage)
	if _all_fallen(player_hp):
		_finish_battle(false, "전원이 쓰러졌습니다.")

func _update_battle_view() -> void:
	status.text = "TURN %d   ·   다음 적 행동: %s" % [turn, enemy_intent]
	var ally_text: Array[String] = []
	for i in selected_team.size():
		ally_text.append(("> " if i == player_active else "  ") + "%s  %03d HP" % [selected_team[i].get("name", ""), int(player_hp[i])])
	team_label.text = "\n".join(ally_text)
	var foe_text: Array[String] = []
	for i in enemy_team.size():
		foe_text.append(("> " if i == enemy_active else "  ") + "%s  %03d HP" % [enemy_team[i].get("name", ""), int(enemy_hp[i])])
	enemy_label.text = "\n".join(foe_text)
	hp_label.text = "활성: %s  VS  %s" % [selected_team[player_active].get("name", ""), enemy_team[enemy_active].get("name", "")]
	_spawn_active_actors()

func _spawn_active_actors() -> void:
	if is_instance_valid(player_actor): player_actor.queue_free()
	if is_instance_valid(enemy_actor): enemy_actor.queue_free()
	player_actor = Actor.new(); player_actor.setup(selected_team[player_active], 0); player_actor.position = Vector2(430, 490); add_child(player_actor)
	enemy_actor = Actor.new(); enemy_actor.setup(enemy_team[enemy_active], 1); enemy_actor.position = Vector2(850, 490); add_child(enemy_actor)

func _next_alive(hps: Array[float], current: int) -> int:
	for offset in hps.size():
		var index := (current + offset + 1) % hps.size()
		if hps[index] > 0.0:
			return index
	return current

func _all_fallen(hps: Array[float]) -> bool:
	for hp in hps:
		if hp > 0.0: return false
	return true

func _finish_battle(won_battle: bool, result_text: String) -> void:
	for i in min(player_hp.size(), run.team.size()):
		run.team[i]["run_hp"] = player_hp[i]
		run.team[i]["fallen"] = player_hp[i] <= 0.0
	if won_battle:
		run.complete_current_node()
		_show_reward("전투 승리", result_text + "\n유물 보상을 선택하세요.")
	else:
		run.run_over = true
		run.won = false
		_show_result(false)

func _show_reward(header: String, body: String) -> void:
	phase = Phase.REWARD
	_clear_content()
	title.text = header
	status.text = body
	var reward := Button.new()
	reward.text = "유물 획득"
	reward.custom_minimum_size = Vector2(240, 60)
	reward.pressed.connect(_claim_reward)
	content.add_child(reward)
	var skip := Button.new()
	skip.text = "보상 건너뛰기"
	skip.pressed.connect(_show_map)
	content.add_child(skip)

func _claim_reward() -> void:
	var relic: Dictionary = run.add_relic()
	_show_map()
	if relic_label != null:
		relic_label.text = "획득: %s — %s" % [relic.get("name", "유물"), relic.get("desc", "")]

func _show_result(victory: bool) -> void:
	phase = Phase.RESULT
	_clear_content()
	title.text = "RUN CLEAR" if victory else "RUN OVER"
	status.text = "시드 %d\n유물 %d개\n다시 도전해 새로운 회랑을 엽니다." % [run.seed, run.relics.size()]
	var restart := Button.new()
	restart.text = "새 런 시작"
	restart.custom_minimum_size = Vector2(220, 58)
	restart.pressed.connect(_show_select)
	content.add_child(restart)

func _process(_delta: float) -> void:
	if phase == Phase.BATTLE and is_instance_valid(player_actor) and is_instance_valid(enemy_actor):
		if enemy_hp[enemy_active] <= 0.0:
			enemy_active = _next_alive(enemy_hp, enemy_active)
			_update_battle_view()
	if phase == Phase.MAP and run != null and run.run_over:
		_show_result(run.won)
