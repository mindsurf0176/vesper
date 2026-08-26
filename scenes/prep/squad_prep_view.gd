class_name SquadPrepView
extends Control

signal ready_requested
signal help_requested
signal pressed

const SQUAD_POOL := ["aries", "sagittarius", "taurus", "scorpio", "virgo", "capricorn"]
const VesperUITheme = preload("res://scenes/ui/vesper_ui.gd")
const VesperBackdropScene = preload("res://scenes/ui/vesper_backdrop.gd")
const UnitCardScene = preload("res://scenes/components/unit_card.gd")

var game: CorridorSession
var message := ""
var prep_time := 0.0
var _status: Label
var _timer: Label
var _squad_box: HBoxContainer
var _pool_box: GridContainer
var _message: Label
var _ready_btn: Button

func _ready() -> void:
	_build_ui()

func bind_match(value: CorridorSession) -> void:
	game = value
	refresh_all()

func set_time_left(value: float) -> void:
	prep_time = value
	if _timer != null:
		_timer.text = "준비 %02d" % ceili(prep_time)

func set_message(value: String) -> void:
	message = value
	if _message != null:
		_message.text = value

func refresh_all() -> void:
	if game == null or not is_node_ready():
		return
	var p := game.human_seat().player
	_status.text = "NIGHT %02d   ·   HP %d   ·   보유 유물 %d개" % [game.round_no, p.hp, p.relics.size()]
	_message.text = message if not message.is_empty() else "이번 원정에 데려갈 4명을 선택하고 전투 시작을 누르세요."
	_ready_btn.disabled = p.queued_units().size() != 4
	_rebuild_squad(p)
	_rebuild_pool(p)

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(VesperBackdropScene.new())
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var top := PanelContainer.new()
	top.custom_minimum_size.y = 68
	top.add_theme_stylebox_override("panel", VesperUITheme.panel(Color("101b29"), VesperUITheme.LINE, 8))
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	top.add_child(top_row)
	var step := VesperUITheme.title_label("STEP 1 / 2\nSQUAD", 13)
	step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(step)
	_status = VesperUITheme.title_label("", 15)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_status)
	_timer = VesperUITheme.title_label("준비 45", 18)
	top_row.add_child(_timer)
	var help := _button("도움말", func(): help_requested.emit())
	top_row.add_child(help)
	var squad_panel := _section("이번 런에 데려갈 4명", 190)
	root.add_child(squad_panel)
	_squad_box = HBoxContainer.new()
	_squad_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_squad_box.add_theme_constant_override("separation", 12)
	squad_panel.get_child(0).add_child(_squad_box)
	var pool_panel := _section("사도 선택 · 6명 중 4명 · 카드를 눌러 교대", 270)
	pool_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pool_panel)
	_pool_box = GridContainer.new()
	_pool_box.columns = 3
	_pool_box.add_theme_constant_override("separation", 8)
	pool_panel.get_child(0).add_child(_pool_box)
	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	_message = VesperUITheme.title_label("", 13)
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_message)
	_ready_btn = _button("전투 시작", func(): ready_requested.emit(), true)
	_ready_btn.custom_minimum_size = Vector2(180, 46)
	bottom.add_child(_ready_btn)

func _rebuild_squad(p: Econ.Player) -> void:
	_clear(_squad_box)
	for unit in p.queued_units():
		var card := _card(unit, true)
		_squad_box.add_child(card)
	for i in range(4 - p.queued_units().size()):
		var empty := PanelContainer.new()
		empty.custom_minimum_size = Vector2(128, 112)
		empty.add_theme_stylebox_override("panel", VesperUITheme.panel(Color("0c1621"), VesperUITheme.LINE, 8))
		empty.add_child(VesperUITheme.title_label("선택 필요", 14))
		_squad_box.add_child(empty)

func _rebuild_pool(p: Econ.Player) -> void:
	_clear(_pool_box)
	for id in SQUAD_POOL:
		var selected := false
		for unit in p.queued_units():
			if str(unit.get("def_id", "")) == id:
				selected = true
		var card := _card({"def_id": id, "star": 1, "order": -1}, selected)
		card.pressed.connect(func(): _toggle_unit(id))
		_pool_box.add_child(card)

func _card(unit: Dictionary, selected: bool) -> Button:
	var d := UnitDB.get_def(str(unit["def_id"]))
	var ability := UnitDB.ability(str(unit["def_id"]))
	var card := Button.new()
	card.custom_minimum_size = Vector2(128, 112)
	card.text = "%s\n%s  ·  %d 코스트\n%s\n%s" % [str(d["name"]), Defs.ROLE_NAMES[d["role"]], UnitDB.deploy_cost(unit["def_id"]), str(ability["name"]), "선택됨" if selected else "선택"]
	card.tooltip_text = UnitDB.ability_text(str(unit["def_id"]))
	card.add_theme_font_size_override("font_size", 15)
	card.add_theme_color_override("font_color", VesperUITheme.TEXT)
	card.add_theme_color_override("font_hover_color", Color("ffffff"))
	card.add_theme_stylebox_override("normal", VesperUITheme.button(Color("183147") if selected else Color("101b29"), VesperUITheme.AMBER if selected else VesperUITheme.LINE, 8))
	card.add_theme_stylebox_override("hover", VesperUITheme.button(Color("24465d"), VesperUITheme.CYAN, 8))
	card.add_theme_stylebox_override("pressed", VesperUITheme.button(Color("0c1723"), VesperUITheme.AMBER, 8))
	card.add_theme_stylebox_override("focus", VesperUITheme.button(Color("24465d"), VesperUITheme.AMBER, 8))
	card.focus_mode = Control.FOCUS_ALL
	return card

func _toggle_unit(id: String) -> void:
	var p := game.human_seat().player
	var found := -1
	for i in p.roster.size():
		if str(p.roster[i].get("def_id", "")) == id and int(p.roster[i].get("order", -1)) >= 0:
			found = i
	if found >= 0:
		p.roster[found]["order"] = -1
	else:
		if p.queued_units().size() >= 4:
			set_message("4명만 데려갈 수 있습니다. 먼저 한 명을 교대하세요.")
			return
		p.roster.append({"def_id": id, "star": 1, "order": p.queued_units().size()})
	refresh_all()

func _section(title: String, height: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = height
	panel.add_theme_stylebox_override("panel", VesperUITheme.panel(Color("101b29"), VesperUITheme.LINE, 8))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var label := VesperUITheme.title_label(title, 14)
	label.add_theme_color_override("font_color", VesperUITheme.AMBER)
	box.add_child(label)
	return panel

func _button(text: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	VesperUITheme.apply_button(button, primary)
	button.pressed.connect(callback)
	return button

func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit()
		accept_event()
