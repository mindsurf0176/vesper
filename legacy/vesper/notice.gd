extends Control
## 공지 화면 — 서버 공지 전 단계의 로컬 피드/읽음 상태 계약.

const AMBER := Color(1.0, 0.74, 0.36)
const BG := Color(0.045, 0.065, 0.08)

var font: Font
var list_box: VBoxContainer
var status_label: Label

func _ready() -> void:
	font = load("res://assets/Galmuri11.ttf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(_label("공지", 44, AMBER, Vector2(52, 42), Vector2(260, 54)))
	add_child(_btn("전체 읽음", Vector2(70, 112), AMBER, Vector2(150, 42), _read_all))
	var sc := ScrollContainer.new()
	sc.position = Vector2(70, 174)
	sc.size = Vector2(1080, 420)
	add_child(sc)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list_box)
	status_label = _label("", 15, Color(0.70, 0.76, 0.78), Vector2(70, 610), Vector2(900, 28))
	add_child(status_label)
	add_child(_btn("메인", Vector2(52, 642), Color(0.4, 0.42, 0.46), Vector2(120, 40), func(): GameState.goto("res://home.tscn")))

func _refresh() -> void:
	for child in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()
	for notice in GameState.notice_list():
		list_box.add_child(_notice_card(notice))
	status_label.text = "읽지 않은 공지 %d개" % GameState.unread_notice_count()

func _notice_card(notice: Dictionary) -> Control:
	var card := ColorRect.new()
	card.color = Color(0.52, 0.32, 0.18, 0.13)
	card.custom_minimum_size = Vector2(1030, 120)
	var read := bool(notice.get("read", false))
	var mark := "읽음" if read else "NEW"
	card.add_child(_label("[%s] %s · %s" % [mark, str(notice.get("category", "")), str(notice.get("title", ""))],
		20, AMBER, Vector2(18, 12), Vector2(760, 28)))
	var body := _label(str(notice.get("body", "")), 14, Color(0.72, 0.78, 0.78), Vector2(18, 48), Vector2(760, 48))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(body)
	var btn := _btn("읽음" if read else "읽음 처리", Vector2(850, 38), AMBER, Vector2(130, 42), func(): _read_one(str(notice.get("id", ""))))
	btn.disabled = read
	card.add_child(btn)
	return card

func _read_one(notice_id: String) -> void:
	var res := GameState.mark_notice_read(notice_id)
	status_label.text = str(res.get("message", ""))
	_refresh()

func _read_all() -> void:
	var res := GameState.mark_all_notices_read()
	status_label.text = str(res.get("message", ""))
	_refresh()

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
