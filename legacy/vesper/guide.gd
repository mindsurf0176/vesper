extends Control
## 가이드 화면 — 전투/오브/소신/메타 튜토리얼을 언제든 재확인한다.

const AMBER := Color(1.0, 0.74, 0.36)
const BG := Color(0.045, 0.065, 0.08)
const GREEN := Color(0.48, 0.76, 0.70)

var font: Font
var topic_box: VBoxContainer
var detail_label: Label
var status_label: Label
var selected_id := ""

func _ready() -> void:
	font = load("res://assets/Galmuri11.ttf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var topics := GameState.tutorial_topics()
	if not topics.is_empty():
		selected_id = str(topics[0].get("id", ""))
	_build()
	_refresh()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(_label("가이드", 44, AMBER, Vector2(52, 42), Vector2(260, 54)))
	topic_box = VBoxContainer.new()
	topic_box.position = Vector2(70, 130)
	topic_box.size = Vector2(360, 420)
	add_child(topic_box)
	var panel := ColorRect.new()
	panel.color = Color(0.20, 0.34, 0.32, 0.13)
	panel.position = Vector2(480, 130)
	panel.size = Vector2(650, 420)
	add_child(panel)
	detail_label = _label("", 18, Color(0.84, 0.88, 0.86), Vector2(510, 160), Vector2(590, 330))
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(detail_label)
	add_child(_btn("확인 처리", Vector2(510, 500), GREEN, Vector2(150, 42), _mark_viewed))
	status_label = _label("가이드는 로컬 저장으로 확인 여부를 남깁니다.", 15,
		Color(0.70, 0.76, 0.78), Vector2(70, 610), Vector2(900, 28))
	add_child(status_label)
	add_child(_btn("메인", Vector2(52, 642), Color(0.4, 0.42, 0.46), Vector2(120, 40), func(): GameState.goto("res://home.tscn")))

func _refresh() -> void:
	for child in topic_box.get_children():
		topic_box.remove_child(child)
		child.queue_free()
	for topic in GameState.tutorial_topics():
		topic_box.add_child(_topic_card(topic))
	_show_selected()

func _topic_card(topic: Dictionary) -> Control:
	var card := ColorRect.new()
	card.color = Color(0.18, 0.38, 0.34, 0.13)
	card.custom_minimum_size = Vector2(330, 72)
	var viewed := bool(topic.get("viewed", false))
	card.add_child(_label("%s%s" % ["✓ " if viewed else "", str(topic.get("title", ""))],
		17, AMBER if str(topic.get("id", "")) == selected_id else Color(0.84, 0.88, 0.86),
		Vector2(14, 10), Vector2(210, 24)))
	var btn := _btn("보기", Vector2(230, 18), GREEN, Vector2(80, 34), func(): _select(str(topic.get("id", ""))))
	card.add_child(btn)
	return card

func _select(topic_id: String) -> void:
	selected_id = topic_id
	_refresh()

func _show_selected() -> void:
	var topic := GameState.tutorial_topic(selected_id)
	if topic.is_empty():
		detail_label.text = "가이드 항목이 없습니다."
		return
	var lines := [str(topic.get("title", "")), ""]
	var steps: Array = topic.get("steps", [])
	for i in range(steps.size()):
		lines.append("%d. %s" % [i + 1, str(steps[i])])
	detail_label.text = "\n".join(lines)

func _mark_viewed() -> void:
	var res := GameState.mark_tutorial_viewed(selected_id)
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
