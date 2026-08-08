extends Control
## 크레딧/법적 고지 목업. 실제 출시 전 스토어 표기와 라이선스 목록으로 확장한다.

const AMBER := Color(1.0, 0.74, 0.36)
const BG := Color(0.045, 0.065, 0.08)

var font: Font

func _ready() -> void:
	font = load("res://assets/Galmuri11.ttf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(_label("크레딧", 44, AMBER, Vector2(52, 42), Vector2(260, 54)))
	var y := 130.0
	for entry in GameState.credits_list():
		add_child(_label("%s  ·  %s" % [str(entry.get("role", "")), str(entry.get("name", ""))],
			18, Color(0.84, 0.88, 0.86), Vector2(110, y), Vector2(900, 28)))
		y += 44.0
	var legal := _label(
		"법적/운영 고지\n\n" +
		"- 이 빌드는 로컬 개발용입니다. 실제 결제, 광고, 채팅 서버, 개인정보 수집은 연결되어 있지 않습니다.\n" +
		"- 출시 전 스토어 약관, 개인정보 처리방침, 청소년 보호, 신고/차단, 라이선스 표기를 별도 검증해야 합니다.\n" +
		"- 카운터사이드/스도리카는 장르적 참고점이며, 캐릭터·세계관·규칙·UI 표현은 베스퍼 회랑 고유 방향으로 유지합니다.",
		16, Color(0.72, 0.78, 0.78), Vector2(110, 360), Vector2(930, 180))
	legal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(legal)
	add_child(_btn("메인", Vector2(52, 642), Color(0.4, 0.42, 0.46), Vector2(120, 40), func(): GameState.goto("res://home.tscn")))

func _label(text: String, sz: int, col: Color, pos: Vector2, size: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l

func _btn(text: String, pos: Vector2, col: Color, size: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color(0.94, 0.95, 0.96))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.16)
	sb.border_color = Color(col.r, col.g, col.b, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate()
	sh.bg_color = Color(col.r, col.g, col.b, 0.30)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.pressed.connect(cb)
	return b
