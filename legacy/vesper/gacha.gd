extends Control
## 모집 화면 — 확률 공개, 천장, 10회 SR 보장, 중복 조각 전환.

const AMBER := Color(1.0, 0.74, 0.36)
const BG := Color(0.045, 0.065, 0.08)

var font: Font
var currency_label: Label
var result_label: Label

func _ready() -> void:
	font = load("res://assets/Galmuri11.ttf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(_label("망자 모집", 44, AMBER, Vector2(52, 42), Vector2(360, 54)))
	currency_label = _label(GameState.currency_text(), 16, Color(0.86, 0.90, 0.88), Vector2(720, 48), Vector2(500, 24))
	currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(currency_label)
	var rates := _label(GameState.gacha_rates_text(), 16, Color(0.70, 0.76, 0.78), Vector2(56, 108), Vector2(900, 26))
	add_child(rates)
	var pity := _label("현재 SSR 천장 카운트: %d / %d" % [GameState.gacha_pity, GameState.GACHA_PITY_LIMIT],
		16, Color(0.82, 0.75, 0.60), Vector2(56, 138), Vector2(420, 24))
	add_child(pity)
	add_child(_btn("1회 모집\n모집권 1 또는 루멘 160", Vector2(76, 220), AMBER, Vector2(260, 74), func(): _pull(1)))
	add_child(_btn("10회 모집\nSR 이상 1명 보장", Vector2(360, 220), Color(0.58, 0.48, 0.9), Vector2(260, 74), func(): _pull(10)))
	add_child(_btn("메인", Vector2(52, 642), Color(0.4, 0.42, 0.46), Vector2(120, 40), func(): GameState.goto("res://home.tscn")))
	result_label = _label("모집 결과가 여기에 표시됩니다.", 17, Color(0.88, 0.90, 0.90), Vector2(74, 336), Vector2(1040, 230))
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(result_label)

func _pull(count: int) -> void:
	var res := GameState.draw_gacha(count)
	currency_label.text = GameState.currency_text()
	if not bool(res.get("ok", false)):
		result_label.text = str(res.get("message", "모집 실패"))
		return
	var lines := [str(res.get("message", ""))]
	for item in res.get("results", []):
		var line := "[%s] %s" % [str(item.get("rarity", "")), str(item.get("name", ""))]
		if bool(item.get("duplicate", false)):
			line += "  ·  중복 → 조각 +%d" % int(item.get("shards", 0))
		else:
			line += "  ·  신규 합류"
		lines.append(line)
	lines.append("천장: %d / %d" % [GameState.gacha_pity, GameState.GACHA_PITY_LIMIT])
	result_label.text = "\n".join(lines)

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
	b.add_theme_font_size_override("font_size", 17)
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
