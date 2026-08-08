extends Control
## 로컬 채팅 목업. 서버 없이 저장 로그로 채팅 UX를 검증한다.

const AMBER := Color(1.0, 0.74, 0.36)
const BG := Color(0.045, 0.065, 0.08)

var font: Font
var feed: VBoxContainer
var input: LineEdit
var status_label: Label

func _ready() -> void:
	font = load("res://assets/Galmuri11.ttf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh_feed()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(_label("회랑 채팅", 44, AMBER, Vector2(52, 42), Vector2(360, 54)))
	var sc := ScrollContainer.new()
	sc.position = Vector2(70, 126)
	sc.size = Vector2(1040, 420)
	add_child(sc)
	feed = VBoxContainer.new()
	feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(feed)
	input = LineEdit.new()
	input.position = Vector2(70, 575)
	input.size = Vector2(850, 40)
	input.placeholder_text = "메시지 입력"
	input.add_theme_font_override("font", font)
	input.add_theme_font_size_override("font_size", 16)
	add_child(input)
	add_child(_btn("전송", Vector2(940, 575), AMBER, Vector2(120, 40), _send))
	add_child(_btn("메인", Vector2(52, 642), Color(0.4, 0.42, 0.46), Vector2(120, 40), func(): GameState.goto("res://home.tscn")))
	status_label = _label("서버 채팅 전 단계: 로컬 저장 채팅 목업입니다.", 14, Color(0.64, 0.70, 0.72), Vector2(70, 620), Vector2(760, 22))
	add_child(status_label)

func _send() -> void:
	var res := GameState.send_chat_message(input.text)
	status_label.text = str(res.get("message", ""))
	input.text = ""
	_refresh_feed()

func _refresh_feed() -> void:
	for child in feed.get_children():
		child.queue_free()
	for msg in GameState.chat_list():
		var speaker := str(msg.get("speaker", "???"))
		var text := str(msg.get("text", ""))
		var col := Color(0.78, 0.84, 0.86) if bool(msg.get("system", false)) else Color(0.92, 0.92, 0.88)
		var l := _label("%s: %s" % [speaker, text], 16, col, Vector2.ZERO, Vector2(1000, 28))
		feed.add_child(l)

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
	b.add_theme_font_size_override("font_size", 16)
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
