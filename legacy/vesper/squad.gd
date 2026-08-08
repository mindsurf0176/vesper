extends Control
## 편성 화면 — 해금된 캐릭터 중 스쿼드 선택(최대 SQUAD_MAX) → 출격.

const AMBER := Color(1.0, 0.74, 0.36)
const COLD := Color(0.36, 0.86, 0.92)
const BG := Color(0.05, 0.08, 0.09)
enum { STRIKER, RANGER, DEFENDER, SNIPER, SUPPORT }  # GameState와 동일 순서
const TYPE_COL := {
	STRIKER: Color(0.92, 0.47, 0.42), RANGER: Color(0.42, 0.82, 0.86),
	DEFENDER: Color(0.55, 0.62, 0.92), SNIPER: Color(0.92, 0.68, 0.98),
	SUPPORT: Color(0.58, 0.86, 0.56) }
const TYPE_GLYPH := { STRIKER: "S", RANGER: "R", DEFENDER: "D", SNIPER: "N", SUPPORT: "+" }

var font: Font
var selected: Array = []       # 선택된 이름
var count_label: Label
var brand_label: Label
var launch_btn: Button
var cards: Array = []          # {name, button, imprint_button, def}

func _ready() -> void:
	font = load("res://assets/Galmuri11.ttf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG; bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var st := GameState.current_stage_def()
	add_child(_label("편성", 36, AMBER, Vector2(48, 36), Vector2(300, 46)))
	add_child(_label("진입 · %s — %s" % [st["name"], st["sub"]], 18, Color(0.6, 0.66, 0.7), Vector2(50, 86), Vector2(700, 24)))

	# 기본 선택: 해금분 중 앞에서 SQUAD_MAX까지
	var defs := GameState.unlocked_defs()
	for i in defs.size():
		if selected.size() < GameState.SQUAD_MAX:
			selected.append(defs[i]["name"])

	var x0 := 60.0
	var y0 := 170.0
	var cw := 210.0
	var gap := 24.0
	for i in defs.size():
		var col := i % 5
		var row := i / 5
		var pos := Vector2(x0 + col * (cw + gap), y0 + row * 220.0)
		_card(defs[i], pos, cw)

	count_label = _label("", 20, Color(0.8, 0.84, 0.88), Vector2(60, 566), Vector2(400, 28))
	add_child(count_label)
	brand_label = _label("", 16, AMBER, Vector2(60, 600), Vector2(760, 26))
	add_child(brand_label)

	var back := _btn("← 회랑", Vector2(60, 646), Color(0.5, 0.5, 0.56), Vector2(120, 44))
	back.pressed.connect(func(): GameState.goto("res://stagemap.tscn"))
	add_child(back)

	launch_btn = _btn("출격 →", Vector2(1280 - 240, 636), AMBER, Vector2(180, 56))
	launch_btn.add_theme_font_size_override("font_size", 24)
	launch_btn.pressed.connect(_launch)
	add_child(launch_btn)

	_refresh()

func _card(def: Dictionary, pos: Vector2, w: float) -> void:
	var col: Color = TYPE_COL[def["type"]]
	var b := Button.new()
	b.toggle_mode = true
	b.position = pos; b.size = Vector2(w, 196)
	b.pressed.connect(_toggle.bind(def["name"]))
	add_child(b)

	var nm := _label(def["name"], 22, Color(0.94, 0.95, 0.97), pos + Vector2(0, 14), Vector2(w, 30))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nm)
	var role := _label(def.get("role", ""), 13, col, pos + Vector2(0, 46), Vector2(w, 20))
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(role)
	if def.has("art") and ResourceLoader.exists(def["art"]):
		var frame := Control.new()
		frame.position = pos + Vector2(w * 0.5 - 42, 74); frame.size = Vector2(84, 84)
		frame.clip_contents = true
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(frame)
		var tr := TextureRect.new()
		tr.texture = load(def["art"])
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tr)
	var cost := _label("C%d · %s" % [int(def["cost"]), TYPE_GLYPH[def["type"]]], 15, Color(0.7, 0.74, 0.78), pos + Vector2(0, 164), Vector2(w, 22))
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cost)

	var imprint_btn := _btn("", pos + Vector2(0, 204), AMBER, Vector2(w, 62))
	imprint_btn.add_theme_font_size_override("font_size", 13)
	imprint_btn.pressed.connect(_imprint_action.bind(def["name"]))
	add_child(imprint_btn)
	cards.append({ "name": def["name"], "button": b, "imprint_button": imprint_btn, "def": def })

func _toggle(cname: String) -> void:
	if selected.has(cname):
		selected.erase(cname)
	else:
		if selected.size() >= GameState.SQUAD_MAX:
			return
		selected.append(cname)
	_refresh()

func _imprint_action(cname: String) -> void:
	GameState.cycle_imprint(cname)
	_refresh()

func _refresh() -> void:
	for c in cards:
		var on: bool = selected.has(c["name"])
		var col: Color = TYPE_COL[c["def"]["type"]]
		c["button"].button_pressed = on
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col.r, col.g, col.b, 0.20 if on else 0.06)
		sb.border_color = Color(col.r, col.g, col.b, 0.95 if on else 0.35)
		sb.set_border_width_all(2 if on else 1)
		sb.set_corner_radius_all(10)
		c["button"].add_theme_stylebox_override("normal", sb)
		c["button"].add_theme_stylebox_override("hover", sb)
		c["button"].add_theme_stylebox_override("pressed", sb)
		var ib: Button = c["imprint_button"]
		var imp := GameState.selected_imprint(c["name"])
		var slot_open: bool = GameState.imprint_unlocked.has(c["name"])
		if slot_open and not imp.is_empty():
			ib.text = "★ %s\n%s" % [imp["label"], imp["desc"]]
			ib.disabled = false
			ib.modulate = Color(1, 1, 1, 1)
		else:
			ib.text = "☆ 각인 슬롯 해금\n각인재 1 필요"
			ib.disabled = GameState.brand_points <= 0
			ib.modulate = Color(1, 1, 1, 1) if not ib.disabled else Color(0.5, 0.5, 0.55, 0.75)
	count_label.text = "선택 %d / %d" % [selected.size(), GameState.SQUAD_MAX]
	brand_label.text = "각인재  %d   ·   슬롯 해금 후 버튼을 눌러 두 각인을 전환" % GameState.brand_points
	launch_btn.disabled = selected.is_empty()
	launch_btn.modulate = Color(1, 1, 1, 1) if not selected.is_empty() else Color(0.5, 0.5, 0.55, 0.7)

func _launch() -> void:
	if selected.is_empty():
		return
	# ALL_CHARS 순서 유지해 편성
	var order := []
	for c in GameState.ALL_CHARS:
		if selected.has(c["name"]):
			order.append(c["name"])
	GameState.squad = order
	GameState.goto("res://battle3d.tscn")

func _label(text: String, sz: int, col: Color, pos: Vector2, size: Vector2) -> Label:
	var l := Label.new()
	l.text = text; l.position = pos; l.size = size
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l

func _btn(text: String, pos: Vector2, col: Color, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text; b.position = pos; b.size = size
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.16)
	sb.border_color = Color(col.r, col.g, col.b, 0.7)
	sb.set_border_width_all(1); sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate(); sh.bg_color = Color(col.r, col.g, col.b, 0.3)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_stylebox_override("disabled", sb)
	return b
