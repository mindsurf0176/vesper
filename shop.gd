extends Control
## 상점 화면 — 실제 결제 없이 수익 구조를 목업으로 검증한다.

const AMBER := Color(1.0, 0.74, 0.36)
const BG := Color(0.045, 0.065, 0.08)

var font: Font
var currency_label: Label
var status_label: Label

func _ready() -> void:
	font = load("res://assets/Galmuri11.ttf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(_label("상점", 44, AMBER, Vector2(52, 42), Vector2(260, 54)))
	currency_label = _label(GameState.currency_text(), 16, Color(0.86, 0.90, 0.88), Vector2(720, 48), Vector2(500, 24))
	currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(currency_label)
	var x := 70.0
	for pack in GameState.SHOP_PACKS:
		_pack_card(pack, Vector2(x, 160))
		x += 370.0
	status_label = _label("모든 상품은 테스트 지급입니다. 실제 결제·광고 SDK는 아직 연결하지 않았습니다.", 16,
		Color(0.72, 0.76, 0.78), Vector2(70, 530), Vector2(1000, 28))
	add_child(status_label)
	add_child(_btn("메인", Vector2(52, 642), Color(0.4, 0.42, 0.46), Vector2(120, 40), func(): GameState.goto("res://home.tscn")))

func _pack_card(pack: Dictionary, pos: Vector2) -> void:
	var box := ColorRect.new()
	box.color = Color(0.62, 0.70, 0.86, 0.08)
	box.position = pos
	box.size = Vector2(320, 300)
	add_child(box)
	add_child(_label(str(pack["title"]), 24, AMBER, pos + Vector2(22, 22), Vector2(276, 32)))
	add_child(_label(str(pack["price_label"]), 18, Color(0.82, 0.88, 0.90), pos + Vector2(22, 62), Vector2(276, 28)))
	var rewards: Dictionary = pack.get("rewards", {})
	var reward_lines := []
	if rewards.has("lumen"):
		reward_lines.append("루멘 +%d" % int(rewards["lumen"]))
	if rewards.has("recruit_tickets"):
		reward_lines.append("모집권 +%d" % int(rewards["recruit_tickets"]))
	if rewards.has("gold"):
		reward_lines.append("골드 +%d" % int(rewards["gold"]))
	add_child(_label("\n".join(reward_lines), 17, Color(0.93, 0.88, 0.72), pos + Vector2(22, 108), Vector2(276, 70)))
	var desc := _label(str(pack["desc"]), 13, Color(0.66, 0.72, 0.74), pos + Vector2(22, 180), Vector2(276, 52))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(desc)
	var bought := int(GameState.shop_claims.get(pack["id"], 0))
	var limit := int(pack.get("limit", 99))
	var buy := _btn("테스트 구매  %d/%d" % [bought, limit], pos + Vector2(42, 242), AMBER, Vector2(236, 42),
		func(): _buy(str(pack["id"])))
	add_child(buy)

func _buy(pack_id: String) -> void:
	var res := GameState.buy_shop_pack(pack_id)
	status_label.text = str(res.get("message", ""))
	currency_label.text = GameState.currency_text()

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
