extends Control

## 베스퍼 회랑 — 타이틀 → 캐릭터 선택 → 1대1 픽셀 격투 → 결과 루프.

enum Phase { TITLE, SELECT, BATTLE, RESULT }

var phase := Phase.TITLE
var _font: Font
var _title_layer: Control
var _briefing_layer: Control
var _select_layer: Control
var _select_status: Label
var _select_start: Button
var _selected_player: Dictionary = {}
var _selected_enemy: Dictionary = {}
var _fighter_buttons: Array[Button] = []
var _battle_layer: Control
var _battle_node: Node = null
var _result_layer: Control
var _result_title: Label
var _result_body: Label


func _ready() -> void:
	_font = load("res://assets/Galmuri11.ttf")
	var project_theme := Theme.new()
	project_theme.default_font = _font
	project_theme.default_font_size = 13
	theme = project_theme
	_build_ui()
	_show_title()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_title()
	_build_briefing()
	_build_select()
	_build_battle_layer()
	_build_result()


# ── 타이틀 ──────────────────────────────────────────────
func _build_title() -> void:
	_title_layer = Control.new()
	_title_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_title_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.06, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_layer.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := Label.new()
	title.text = "베스퍼 회랑\nTHE VESPER CORRIDOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.74, 0.36))
	box.add_child(title)

	var sub := Label.new()
	sub.text = "다크 SF 사이드뷰 실시간 전략 라인 배틀러"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.6, 0.75, 0.78))
	box.add_child(sub)

	var btn_start := Button.new()
	btn_start.text = "회랑 진입"
	btn_start.custom_minimum_size = Vector2(220, 48)
	btn_start.add_theme_font_size_override("font_size", 16)
	btn_start.pressed.connect(_on_start_pressed)
	box.add_child(btn_start)
	# center the button
	btn_start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


# ── 브리핑 ──────────────────────────────────────────────
func _build_briefing() -> void:
	_briefing_layer = Control.new()
	_briefing_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_briefing_layer.visible = false
	add_child(_briefing_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.06, 0.07, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_briefing_layer.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 50)
	_briefing_layer.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "작전 브리핑"
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(1.0, 0.74, 0.36))
	vbox.add_child(header)

	var rules := [
		"코스트가 자동으로 차오릅니다. 하단 카드를 눌러 유닛을 소환하세요.",
		"전선이 전진할수록 더 앞쪽에 유닛을 배치할 수 있습니다.",
		"오브 보드에서 같은 색 인접 오브를 1/2/4개 선택해 스킬을 발동하세요.",
		"위기 시 [소신(燒身)]으로 등불함 HP를 태워 코스트를 즉시 충전할 수 있습니다.",
		"적 매듭(코어)의 HP를 0으로 만들면 승리합니다.",
	]
	for rule in rules:
		var line := Label.new()
		line.text = "• " + rule
		line.add_theme_font_size_override("font_size", 14)
		line.add_theme_color_override("font_color", Color(0.7, 0.85, 0.88))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(line)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	vbox.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var btn_launch := Button.new()
	btn_launch.text = "전투 개시"
	btn_launch.custom_minimum_size = Vector2(180, 48)
	btn_launch.add_theme_font_size_override("font_size", 16)
	btn_launch.pressed.connect(_launch_battle)
	btn_row.add_child(btn_launch)

	var btn_back := Button.new()
	btn_back.text = "타이틀로"
	btn_back.custom_minimum_size = Vector2(120, 44)
	btn_back.pressed.connect(_show_title)
	btn_row.add_child(btn_back)


# ── 전투 컨테이너 ──────────────────────────────────────
func _build_battle_layer() -> void:
	_battle_layer = Control.new()
	_battle_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle_layer.visible = false
	add_child(_battle_layer)


# ── 결과 ──────────────────────────────────────────────
func _build_result() -> void:
	_result_layer = Control.new()
	_result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.visible = false
	_result_layer.z_index = 100
	add_child(_result_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.03, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 280)
	panel.add_theme_stylebox_override("panel", _panel_style("183032"))
	center.add_child(panel)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 24)
	pad.add_theme_constant_override("margin_right", 24)
	pad.add_theme_constant_override("margin_top", 20)
	pad.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(pad)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	pad.add_child(vb)

	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_size_override("font_size", 28)
	vb.add_child(_result_title)

	_result_body = Label.new()
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_body.add_theme_font_size_override("font_size", 14)
	_result_body.add_theme_color_override("font_color", Color("c0d6d2"))
	_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_result_body)

	var btn_retry := Button.new()
	btn_retry.text = "타이틀로 돌아가기"
	btn_retry.custom_minimum_size = Vector2(180, 44)
	btn_retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_retry.pressed.connect(_show_title)
	vb.add_child(btn_retry)


# ── 페이즈 전환 ──────────────────────────────────────
func _show_title() -> void:
	phase = Phase.TITLE
	_title_layer.visible = true
	_briefing_layer.visible = false
	_select_layer.visible = false
	_battle_layer.visible = false
	_result_layer.visible = false
	_clear_battle()


func _on_start_pressed() -> void:
	phase = Phase.SELECT
	_title_layer.visible = false
	_briefing_layer.visible = false
	_select_layer.visible = true
	_battle_layer.visible = false
	_result_layer.visible = false
	_selected_player.clear()
	_selected_enemy.clear()
	_update_select_state()


func _build_select() -> void:
	_select_layer = Control.new()
	_select_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_select_layer.visible = false
	add_child(_select_layer)
	var bg := ColorRect.new()
	bg.color = Color("091419")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_select_layer.add_child(bg)
	var title := Label.new()
	title.text = "DUEL SELECT  //  한 명을 골라라"
	title.position = Vector2(48, 34)
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("f4ad52"))
	_select_layer.add_child(title)
	_select_status = Label.new()
	_select_status.position = Vector2(50, 82)
	_select_status.add_theme_font_override("font", _font)
	_select_status.add_theme_font_size_override("font_size", 17)
	_select_status.add_theme_color_override("font_color", Color("c0d6d2"))
	_select_layer.add_child(_select_status)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(44, 132)
	grid.size = Vector2(1192, 430)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	_select_layer.add_child(grid)
	var state = get_node_or_null("/root/GameState")
	var roster: Array = state.all_chars_list() if state != null else []
	for def in roster:
		var button := Button.new()
		button.custom_minimum_size = Vector2(285, 128)
		button.text = "%s\n%s  ·  %s" % [str(def.get("name", "전사")), str(def.get("role", "격투가")), str(def.get("rarity", "R"))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", _font)
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", Color("e9eee5"))
		button.add_theme_color_override("font_hover_color", Color("fff0bc"))
		button.add_theme_constant_override("h_separation", 12)
		_select_button_style(button, Color("162b30"))
		if def.has("art") and ResourceLoader.exists(str(def["art"])):
			button.icon = load(str(def["art"]))
			button.add_theme_constant_override("icon_max_width", 62)
		button.pressed.connect(_select_fighter.bind(def))
		grid.add_child(button)
		_fighter_buttons.append(button)
	_select_start = Button.new()
	_select_start.text = "대전 시작"
	_select_start.position = Vector2(1000, 602)
	_select_start.size = Vector2(220, 54)
	_select_start.add_theme_font_override("font", _font)
	_select_start.add_theme_font_size_override("font_size", 18)
	_select_button_style(_select_start, Color("8a552e"))
	_select_start.pressed.connect(_launch_battle)
	_select_layer.add_child(_select_start)
	var hint := Label.new()
	hint.text = "첫 번째 선택 = 나    ·    두 번째 선택 = 상대    ·    같은 캐릭터 미러 매치 가능"
	hint.position = Vector2(50, 610)
	hint.add_theme_font_override("font", _font)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("719296"))
	_select_layer.add_child(hint)

func _select_fighter(def: Dictionary) -> void:
	if _selected_player.is_empty():
		_selected_player = def.duplicate(true)
	else:
		_selected_enemy = def.duplicate(true)
	_update_select_state()

func _update_select_state() -> void:
	if _select_status == null:
		return
	if _selected_player.is_empty():
		_select_status.text = "PLAYER 1  ·  먼저 내 캐릭터를 선택하세요"
	elif _selected_enemy.is_empty():
		_select_status.text = "PLAYER 1  [%s]  VS  ?  ·  상대 캐릭터를 선택하세요" % str(_selected_player.get("name", ""))
	else:
		_select_status.text = "PLAYER 1  [%s]  VS  CPU  [%s]  ·  준비 완료" % [str(_selected_player.get("name", "")), str(_selected_enemy.get("name", ""))]
	_select_start.disabled = _selected_player.is_empty() or _selected_enemy.is_empty()
	for button in _fighter_buttons:
		button.modulate = Color.WHITE
		if not _selected_player.is_empty() and button.text.begins_with(str(_selected_player.get("name", ""))):
			button.modulate = Color("ffd98a")
		if not _selected_enemy.is_empty() and button.text.begins_with(str(_selected_enemy.get("name", ""))):
			button.modulate = Color("8ee2e4")

func _select_button_style(button: Button, base: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(base, 0.94)
	normal.border_color = Color("31575b")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(0)
	var hover := normal.duplicate()
	hover.bg_color = Color("24444a")
	hover.border_color = Color("e7b865")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("304f4d")
	pressed.border_color = Color("f4ad52")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)


func _launch_battle() -> void:
	if _selected_player.is_empty() or _selected_enemy.is_empty():
		return
	phase = Phase.BATTLE
	_title_layer.visible = false
	_briefing_layer.visible = false
	_select_layer.visible = false
	_result_layer.visible = false
	_battle_layer.visible = true

	_clear_battle()
	var state = get_node_or_null("/root/GameState")
	if state != null:
		state.new_game()

	# 1대1 격투 씬은 2D 픽셀 월드지만 UI와 독립된 SubViewport에서 렌더한다.
	var svp := SubViewport.new()
	svp.size = Vector2i(1280, 720)
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svp.transparent_bg = true
	svp.own_world_3d = false

	var battle_scene = load("res://scenes/duel/duel.tscn")
	if battle_scene == null:
		push_error("duel.tscn 로드 실패")
		_show_title()
		return

	_battle_node = battle_scene.instantiate()
	_battle_node.player_def = _selected_player.duplicate(true)
	_battle_node.enemy_def = _selected_enemy.duplicate(true)
	svp.add_child(_battle_node)

	var svpc := SubViewportContainer.new()
	svpc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svpc.stretch = true
	svpc.add_child(svp)

	_battle_layer.add_child(svpc)


func _clear_battle() -> void:
	if _battle_node != null:
		_battle_node = null
	# 전투 레이어 자식 전부 제거 (SubViewportContainer 포함)
	for child in _battle_layer.get_children():
		child.queue_free()


func _process(_delta: float) -> void:
	if phase != Phase.BATTLE or _battle_node == null:
		return
	# battle3d가 ended 상태면 결과 화면 표시
	if _battle_node.ended and not _result_layer.visible:
		var win: bool = _battle_node.winner == 0
		_show_result(win)


func _show_result(win: bool) -> void:
	phase = Phase.RESULT
	_result_layer.visible = true
	if win:
		_result_title.text = "DUEL WON  //  VICTORY"
		_result_title.add_theme_color_override("font_color", Color(1.0, 0.74, 0.36))
		_result_body.text = "%s가 승리했습니다.\n\n라운드 %d - %d\n대전 시간 %.0f초" % [str(_selected_player.get("name", "PLAYER")),
			_battle_node.player_round_wins, _battle_node.enemy_round_wins, _battle_node.elapsed]
	else:
		_result_title.text = "DUEL LOST  //  DEFEAT"
		_result_title.add_theme_color_override("font_color", Color(0.92, 0.47, 0.42))
		_result_body.text = "%s에게 패배했습니다.\n\n라운드 %d - %d\n대전 시간 %.0f초" % [str(_selected_enemy.get("name", "RIVAL")),
			_battle_node.player_round_wins, _battle_node.enemy_round_wins, _battle_node.elapsed]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if phase == Phase.SELECT:
			_show_title()
		elif phase == Phase.RESULT:
			_show_title()


# ── 유틸 ──────────────────────────────────────────────
func _panel_style(color_hex: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color_hex)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.border_color = Color("315257")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
