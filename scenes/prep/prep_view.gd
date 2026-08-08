class_name PrepView
extends Control

## 오토배틀러식 준비 화면. 편성판의 왼쪽 슬롯부터 차례대로 강림한다.

signal buy_requested(slot: int)
signal sell_requested(roster_index: int)
signal place_requested(roster_index: int, order: int)
signal bench_requested(roster_index: int)
signal reroll_requested
signal xp_requested
signal lock_requested
signal ready_requested
signal help_requested

var game: Match
var message := ""
var prep_time := 0.0
var selected_roster := -1
var selected_source := ""

var _hud: Label
var _timer: Label
var _message: Label
var _synergy_box: VBoxContainer
var _foe_box: HBoxContainer
var _board_box: HBoxContainer
var _bench_box: HBoxContainer
var _shop_box: HBoxContainer
var _rank_box: VBoxContainer
var _reroll_btn: Button
var _xp_btn: Button
var _lock_btn: Button
var _sell_btn: Button
var _ready_btn: Button


func _ready() -> void:
	_build_ui()


func bind_match(value: Match) -> void:
	game = value
	selected_roster = -1
	selected_source = ""
	refresh_all()


func set_time_left(value: float) -> void:
	prep_time = value
	if _timer != null:
		_timer.text = "준비 %02d" % ceili(prep_time)
		_timer.add_theme_color_override("font_color",
			Color("f2909f") if prep_time <= 5.0 else Color("ffd98a"))


func set_message(value: String) -> void:
	message = value
	if _message != null:
		_message.text = message


func refresh_all() -> void:
	if game == null or not is_node_ready():
		return
	var p := game.human_seat().player
	var foe := _human_foe()
	_hud.text = "%d번째 밤   ♥ %d   ◆ %d (+%d)   Lv.%d  XP %d/%s   강림 %d/%d   상대 %s" % [
		game.round_no, p.hp, p.gold, game.econ.interest(p.gold), p.level, p.xp,
		str(UnitDB.XP_TO_NEXT.get(p.level, "MAX")), p.queue_count(), p.level,
		game.seats[foe].name if foe >= 0 else "없음"]
	_message.text = message
	_rebuild_synergy(p)
	_rebuild_foe(foe)
	_rebuild_board(p)
	_rebuild_bench(p)
	_rebuild_shop(p)
	_rebuild_rank(foe)
	_reroll_btn.disabled = p.gold < Econ.REROLL_COST
	_xp_btn.disabled = p.gold < Econ.XP_COST or p.level >= UnitDB.MAX_LEVEL
	_lock_btn.text = "상점 잠금 ✓" if p.shop_locked else "상점 잠금"
	_sell_btn.disabled = selected_roster < 0
	_ready_btn.disabled = p.queue_count() == 0


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("12162c")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var top := PanelContainer.new()
	top.custom_minimum_size.y = 52
	top.add_theme_stylebox_override("panel", _panel("202643", 8))
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top.add_child(top_row)
	_hud = _label("", 14, "f0f2ff")
	_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_hud)
	_timer = _label("준비 45", 20, "ffd98a")
	_timer.custom_minimum_size.x = 90
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_row.add_child(_timer)
	var help := _button("?", func(): help_requested.emit())
	help.custom_minimum_size = Vector2(40, 36)
	top_row.add_child(help)

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 4)
	root.add_child(middle)

	var left := _section("원소의 흐름", 190)
	middle.add_child(left)
	_synergy_box = VBoxContainer.new()
	_synergy_box.add_theme_constant_override("separation", 8)
	left.get_child(0).add_child(_synergy_box)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 4)
	middle.add_child(center)
	var foe_panel := _section("다음 상대의 강림 순서", 0)
	foe_panel.custom_minimum_size.y = 104
	center.add_child(foe_panel)
	_foe_box = HBoxContainer.new()
	_foe_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_foe_box.add_theme_constant_override("separation", 3)
	foe_panel.get_child(0).add_child(_foe_box)

	var board_panel := _section("강림 편성판   왼쪽부터 차례로 내려온다", 0)
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(board_panel)
	_board_box = HBoxContainer.new()
	_board_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_board_box.add_theme_constant_override("separation", 4)
	board_panel.get_child(0).add_child(_board_box)

	var right := _section("별지기", 175)
	middle.add_child(right)
	_rank_box = VBoxContainer.new()
	_rank_box.add_theme_constant_override("separation", 5)
	right.get_child(0).add_child(_rank_box)

	var lower := VBoxContainer.new()
	lower.custom_minimum_size.y = 238
	lower.add_theme_constant_override("separation", 3)
	root.add_child(lower)

	var bench_panel := _section("대기석   카드를 선택한 뒤 편성 슬롯을 눌러도 된다", 0)
	bench_panel.custom_minimum_size.y = 112
	lower.add_child(bench_panel)
	_bench_box = HBoxContainer.new()
	_bench_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_bench_box.add_theme_constant_override("separation", 3)
	bench_panel.get_child(0).add_child(_bench_box)

	var shop_panel := _section("별 상점", 0)
	shop_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.add_child(shop_panel)
	var shop_row := HBoxContainer.new()
	shop_row.add_theme_constant_override("separation", 4)
	shop_panel.get_child(0).add_child(shop_row)
	_shop_box = HBoxContainer.new()
	_shop_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_shop_box.add_theme_constant_override("separation", 4)
	shop_row.add_child(_shop_box)
	var controls := VBoxContainer.new()
	controls.custom_minimum_size.x = 210
	shop_row.add_child(controls)
	var econ_row := HBoxContainer.new()
	controls.add_child(econ_row)
	_reroll_btn = _button("새 별 (%d)" % Econ.REROLL_COST, func(): reroll_requested.emit())
	_xp_btn = _button("XP (%d)" % Econ.XP_COST, func(): xp_requested.emit())
	econ_row.add_child(_reroll_btn)
	econ_row.add_child(_xp_btn)
	var manage_row := HBoxContainer.new()
	controls.add_child(manage_row)
	_lock_btn = _button("상점 잠금", func(): lock_requested.emit())
	manage_row.add_child(_lock_btn)
	_sell_btn = _button("선택 판매", _on_sell_selected)
	_sell_btn.disabled = true
	manage_row.add_child(_sell_btn)
	_ready_btn = _button("준비 완료", func(): ready_requested.emit())
	_ready_btn.custom_minimum_size.y = 38
	controls.add_child(_ready_btn)

	_message = _label("", 11, "ffd98a")
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_message)


func _rebuild_synergy(p: Econ.Player) -> void:
	_clear(_synergy_box)
	var tr := Traits.evaluate(p.queued_units())
	for e in Defs.Element.values():
		var n := int(tr.element_counts.get(e, 0))
		var row := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = StarVisuals.ELEMENT_ICON[e]
		icon.modulate = StarVisuals.ELEMENT_COLOR[e]
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var text := "%s  %d/3" % [Defs.ELEMENT_NAMES[e], n]
		if n >= Traits.TRINE:
			text += "  트라인"
		row.add_child(_label(text, 13, "f0f2ff" if n >= 2 else "7781ae"))
		_synergy_box.add_child(row)
	_synergy_box.add_child(_label("근접 ▶ 원거리 ▶ 방어 ▶ 근접", 10, "9aa3d4"))


func _rebuild_foe(foe: int) -> void:
	_clear(_foe_box)
	if foe < 0:
		_foe_box.add_child(_label("이번 밤은 맞설 상대가 없다", 12, "7781ae"))
		return
	for u in game.seats[foe].player.queued_units().slice(0, 7):
		var card := _make_card(u, -1, "foe", "")
		card.custom_minimum_size = Vector2(62, 72)
		card.selectable = false
		card.draggable = false
		_foe_box.add_child(card)


func _rebuild_board(p: Econ.Player) -> void:
	_clear(_board_box)
	var q := p.queued_units()
	var schedule := Econ.deploy_schedule(q, p.level)
	for i in UnitDB.MAX_LEVEL:
		var locked := i >= p.level
		var hint := "잠김" if locked else "비어 있음"
		if i < schedule.size():
			var item: Dictionary = schedule[i]
			hint = "%.1fs" % float(item["at"])
			if float(item["wait"]) >= 0.1:
				hint += "  대기 %.1f" % float(item["wait"])
		var slot := UnitSlot.new()
		slot.custom_minimum_size = Vector2(86, 120)
		slot.setup("board", i, "%d" % (i + 1), locked, hint)
		slot.pressed.connect(_on_slot_pressed)
		slot.unit_dropped.connect(_on_unit_dropped)
		if i < q.size():
			var idx := p.roster.find(q[i])
			var card := _make_card(q[i], idx, "board", hint)
			card.selected = idx == selected_roster
			slot.set_card(card)
		_board_box.add_child(slot)


func _rebuild_bench(p: Econ.Player) -> void:
	_clear(_bench_box)
	var bench := p.bench_units()
	for i in Econ.BENCH_SIZE:
		var slot := UnitSlot.new()
		slot.custom_minimum_size = Vector2(88, 92)
		slot.setup("bench", i, "", false, "")
		slot.pressed.connect(_on_slot_pressed)
		slot.unit_dropped.connect(_on_unit_dropped)
		if i < bench.size():
			var idx := p.roster.find(bench[i])
			var card := _make_card(bench[i], idx, "bench", "")
			card.selected = idx == selected_roster
			slot.set_card(card)
		_bench_box.add_child(slot)


func _rebuild_shop(p: Econ.Player) -> void:
	_clear(_shop_box)
	for i in Econ.SHOP_SLOTS:
		var id: String = p.shop[i] if i < p.shop.size() else ""
		if id == "":
			var empty := PanelContainer.new()
			empty.custom_minimum_size = Vector2(112, 92)
			empty.add_child(_label("품절", 12, "59628c"))
			_shop_box.add_child(empty)
			continue
		var d := UnitDB.get_def(id)
		var card := _make_card({"def_id": id, "star": 1, "order": -1}, -1, "shop", "")
		card.custom_minimum_size = Vector2(112, 92)
		card.draggable = false
		card.selectable = p.gold >= int(d["tier"])
		var shop_slot := i
		card.activated.connect(func(_card): buy_requested.emit(shop_slot))
		_shop_box.add_child(card)


func _rebuild_rank(foe: int) -> void:
	_clear(_rank_box)
	var human := game.human_seat().index
	var rank := 1
	for s in game.standings():
		var text := "%d  %s   ♥%d" % [rank, s.name, s.player.hp]
		var col := "f0f2ff"
		if s.index == human:
			col = "6ec8f0"
			text += "  나"
		elif s.index == foe:
			col = "f2909f"
			text += "  상대"
		if not s.alive():
			col = "59628c"
			text = "%d  %s   %d등" % [rank, s.name, s.placement]
		_rank_box.add_child(_label(text, 12, col))
		rank += 1


func _make_card(u: Dictionary, idx: int, source: String, time_text: String) -> UnitCard:
	var card := UnitCard.new()
	card.setup(u, idx, source, _unit_tooltip(u["def_id"], int(u.get("star", 1))), time_text)
	if idx >= 0:
		card.activated.connect(_on_card_activated)
	return card


func _on_card_activated(card: UnitCard) -> void:
	if card.source == "shop":
		return
	if selected_roster == card.roster_index:
		# 같은 카드를 다시 누르면 편성/벤치 사이를 빠르게 이동한다.
		if card.source == "board":
			bench_requested.emit(card.roster_index)
		else:
			place_requested.emit(card.roster_index, -1)
		selected_roster = -1
		selected_source = ""
	else:
		selected_roster = card.roster_index
		selected_source = card.source
	refresh_all()


func _on_sell_selected() -> void:
	if selected_roster < 0:
		return
	sell_requested.emit(selected_roster)
	selected_roster = -1
	selected_source = ""


func _on_slot_pressed(slot: UnitSlot) -> void:
	if selected_roster < 0:
		return
	if slot.area == "board":
		place_requested.emit(selected_roster, slot.slot_index)
	else:
		bench_requested.emit(selected_roster)
	selected_roster = -1
	selected_source = ""


func _on_unit_dropped(slot: UnitSlot, data: Dictionary) -> void:
	var idx := int(data["roster_index"])
	if slot.area == "board":
		place_requested.emit(idx, slot.slot_index)
	else:
		bench_requested.emit(idx)
	selected_roster = -1
	selected_source = ""


func _human_foe() -> int:
	if game == null:
		return -1
	var human := game.human_seat().index
	for pair in game.current_pairs:
		if int(pair[0]) == human:
			return int(pair[1])
		if int(pair[1]) == human:
			return int(pair[0])
	return -1


func _unit_tooltip(def_id: String, star: int) -> String:
	var d := UnitDB.get_def(def_id)
	var m := UnitDB.star_mult(star)
	var e: int = d["element"]
	return "%s  %s\n%s\n\n고유 능력: %s\n%s · %s\n체력 %d  공격 %d  방어 %d\n별의 기운 %d" % [
		d["name"], "★".repeat(star), d["flavor"], UnitDB.ability_text(def_id),
		Defs.ELEMENT_NAMES[e], Defs.ROLE_NAMES[d["role"]], int(float(d["hp"]) * m),
		int(float(d["atk"]) * m), int(d["armor"]), UnitDB.deploy_cost(def_id)]


func _section(title: String, min_w: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = min_w
	p.add_theme_stylebox_override("panel", _panel("202643", 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	v.add_child(_label(title, 11, "9aa3d4"))
	return p


func _panel(hex: String, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(hex)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb


func _label(text: String, size: int, hex: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(hex))
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()
