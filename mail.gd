extends Control
## 우편함 화면 — 서버 우편 전 단계의 로컬 지급/중복 방지 계약.

const AMBER := Color(1.0, 0.74, 0.36)
const BG := Color(0.045, 0.065, 0.08)

var font: Font
var mail_list_box: VBoxContainer
var status_label: Label
var currency_label: Label

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
	add_child(_label("우편함", 44, AMBER, Vector2(52, 42), Vector2(280, 54)))
	currency_label = _label("", 16, Color(0.86, 0.90, 0.88), Vector2(720, 48), Vector2(500, 24))
	currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(currency_label)
	add_child(_btn("전체 수령", Vector2(70, 112), AMBER, Vector2(150, 42), _claim_all))
	var sc := ScrollContainer.new()
	sc.position = Vector2(70, 174)
	sc.size = Vector2(1080, 420)
	add_child(sc)
	mail_list_box = VBoxContainer.new()
	mail_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(mail_list_box)
	status_label = _label("우편은 로컬 저장 상태로 중복 수령을 막습니다.", 15,
		Color(0.70, 0.76, 0.78), Vector2(70, 610), Vector2(900, 28))
	add_child(status_label)
	add_child(_btn("메인", Vector2(52, 642), Color(0.4, 0.42, 0.46), Vector2(120, 40), func(): GameState.goto("res://home.tscn")))

func _refresh() -> void:
	currency_label.text = GameState.currency_text()
	for child in mail_list_box.get_children():
		mail_list_box.remove_child(child)
		child.queue_free()
	for mail in GameState.mail_list():
		mail_list_box.add_child(_mail_card(mail))

func _mail_card(mail: Dictionary) -> Control:
	var card := ColorRect.new()
	card.color = Color(0.52, 0.38, 0.18, 0.13)
	card.custom_minimum_size = Vector2(1030, 116)
	card.add_child(_label("%s · %s" % [str(mail.get("from", "")), str(mail.get("title", ""))],
		20, AMBER, Vector2(18, 12), Vector2(620, 28)))
	var body := _label(str(mail.get("body", "")), 14, Color(0.72, 0.78, 0.78), Vector2(18, 46), Vector2(690, 38))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(body)
	var rewards: Dictionary = mail.get("rewards", {})
	card.add_child(_label(GameState.rewards_text(rewards), 14, Color(0.86, 0.82, 0.64), Vector2(18, 86), Vector2(650, 24)))
	var claimed := bool(mail.get("claimed", false))
	var btn := _btn("수령 완료" if claimed else "수령", Vector2(850, 38), AMBER, Vector2(130, 42), func(): _claim_one(str(mail.get("id", ""))))
	btn.disabled = claimed
	card.add_child(btn)
	return card

func _claim_one(mail_id: String) -> void:
	var res := GameState.claim_mail(mail_id)
	status_label.text = str(res.get("message", ""))
	_refresh()

func _claim_all() -> void:
	var res := GameState.claim_all_mail()
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
