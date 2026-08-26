extends Control
## 회랑 맵 — 선형 스테이지 진행. 열린 스테이지 선택 → 편성 화면.

const AMBER := Color(1.0, 0.74, 0.36)
const COLD := Color(0.36, 0.86, 0.92)
const BG := Color(0.05, 0.08, 0.09)

var font: Font

func _ready() -> void:
	font = load("res://assets/Galmuri11.ttf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var head := _label("회랑", 40, AMBER, 32)
	head.position = Vector2(48, 40); head.size = Vector2(400, 50)
	add_child(head)
	var prog := _label("돌파 %d / %d" % [GameState.cleared.size(), GameState.STAGES.size()], 18, Color(0.6, 0.66, 0.7), 18)
	prog.position = Vector2(50, 92); prog.size = Vector2(400, 24)
	add_child(prog)

	# 스테이지 노드를 수평 회랑으로 배치 + 연결선
	var n := GameState.STAGES.size()
	var x0 := 130.0
	var gap := (1280.0 - x0 * 2.0) / float(maxi(1, n - 1))
	var cy := 380.0
	var line := ColorRect.new()
	line.color = Color(0.2, 0.24, 0.28)
	line.position = Vector2(x0, cy - 1); line.size = Vector2((n - 1) * gap, 3)
	add_child(line)
	# 돌파한 구간은 앰버로
	var lit := ColorRect.new()
	lit.color = Color(AMBER.r, AMBER.g, AMBER.b, 0.5)
	lit.position = Vector2(x0, cy - 1)
	lit.size = Vector2(float(mini(GameState.cleared.size(), n - 1)) * gap, 3)
	add_child(lit)

	for i in n:
		var st: Dictionary = GameState.STAGES[i]
		var x := x0 + i * gap
		var cleared: bool = GameState.stage_cleared(i)
		var open: bool = GameState.stage_open(i)
		_stage_node(i, st, Vector2(x, cy), cleared, open)

	var back := _flat_btn("← 메인", Vector2(48, 640), Color(0.5, 0.5, 0.56))
	back.pressed.connect(func(): GameState.goto("res://legacy/vesper/home.tscn"))
	add_child(back)

	if GameState.all_cleared():
		var done := _label("회랑을 끝까지 열었다 — 등불은 꺼지지 않았다", 20, AMBER, 20)
		done.position = Vector2(0, 480); done.size = Vector2(1280, 28)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(done)
		var loop := _flat_btn("변종 도전", Vector2(1280 * 0.5 - 70, 525), AMBER)
		loop.size = Vector2(140, 42)
		loop.pressed.connect(func():
			GameState.current_stage = GameState.STAGES.size()
			GameState.goto("res://legacy/vesper/squad.tscn"))
		add_child(loop)
	_recent_records()

func _stage_node(idx: int, st: Dictionary, center: Vector2, cleared: bool, open: bool) -> void:
	var col: Color
	if cleared: col = AMBER
	elif open: col = COLD
	else: col = Color(0.35, 0.38, 0.42)
	# 노드 원
	var b := Button.new()
	b.position = center - Vector2(30, 30); b.size = Vector2(60, 60)
	b.disabled = not open
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.16 if not cleared else 0.32)
	sb.border_color = Color(col.r, col.g, col.b, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(30)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("disabled", sb)
	var sh := sb.duplicate()
	sh.bg_color = Color(col.r, col.g, col.b, 0.42)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.text = "✓" if cleared else str(idx + 1)
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", col if not cleared else Color(0.1, 0.09, 0.07))
	b.add_theme_color_override("font_disabled_color", Color(col.r, col.g, col.b, 0.7))
	if open:
		b.pressed.connect(func():
			GameState.current_stage = idx
			GameState.goto("res://legacy/vesper/squad.tscn"))
	add_child(b)
	# 라벨(이름/부제)
	var nm := _label(st["name"], 18, col if open else Color(0.5, 0.52, 0.55), 18)
	nm.position = Vector2(center.x - 90, center.y + 42); nm.size = Vector2(180, 24)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(nm)
	var sb2 := _label(st["sub"] if open else "잠김", 13, Color(0.45, 0.48, 0.52), 13)
	sb2.position = Vector2(center.x - 90, center.y + 66); sb2.size = Vector2(180, 20)
	sb2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sb2)
	if open and st.has("rule_tags"):
		var tags := _label(" · ".join(st["rule_tags"]), 11, Color(0.56, 0.62, 0.64), 11)
		tags.position = Vector2(center.x - 100, center.y + 88); tags.size = Vector2(200, 18)
		tags.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(tags)

func _recent_records() -> void:
	if GameState.run_records.is_empty():
		return
	var title := _label("최근 기록", 15, Color(0.72, 0.78, 0.8), 15)
	title.position = Vector2(930, 70); title.size = Vector2(260, 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(title)
	var start: int = maxi(0, GameState.run_records.size() - 3)
	var y := 96.0
	for i in range(start, GameState.run_records.size()):
		var rec: Dictionary = GameState.run_records[i]
		var result := "승리" if bool(rec.get("win", false)) else "실패"
		var rules: Array = rec.get("rules", [])
		var rule_text := " · ".join(rules) if not rules.is_empty() else "규칙 없음"
		var line := _label("%s · %s · %s" % [str(rec.get("stage_name", "")), result, rule_text], 12, Color(0.54, 0.61, 0.64), 12)
		line.position = Vector2(700, y); line.size = Vector2(490, 18)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(line)
		y += 18.0

func _label(text: String, sz: int, col: Color, _sz2 := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l

func _flat_btn(text: String, pos: Vector2, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos; b.size = Vector2(120, 40)
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color(0.9, 0.92, 0.94))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.14)
	sb.border_color = Color(col.r, col.g, col.b, 0.6)
	sb.set_border_width_all(1); sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate(); sh.bg_color = Color(col.r, col.g, col.b, 0.26)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	return b
