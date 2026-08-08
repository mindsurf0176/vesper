extends Control
## 프로필/성장 화면 — 계정 레벨과 캐릭터 레벨업이 전투 계약에 반영되는지 확인한다.

const AMBER := Color(1.0, 0.74, 0.36)
const BG := Color(0.045, 0.065, 0.08)
const CYAN := Color(0.44, 0.78, 0.88)

var font: Font
var list_box: VBoxContainer
var status_label: Label
var account_label: Label
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
	add_child(_label("프로필 / 성장", 44, AMBER, Vector2(52, 42), Vector2(380, 54)))
	account_label = _label("", 16, Color(0.78, 0.84, 0.84), Vector2(54, 102), Vector2(580, 24))
	add_child(account_label)
	currency_label = _label("", 16, Color(0.86, 0.90, 0.88), Vector2(720, 48), Vector2(500, 24))
	currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(currency_label)
	var sc := ScrollContainer.new()
	sc.position = Vector2(70, 150)
	sc.size = Vector2(1080, 438)
	add_child(sc)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list_box)
	status_label = _label("레벨업은 HP/피해/치유 수치를 레벨당 4% 올립니다. 기본 Lv.1은 기존 밸런스 유지.", 15,
		Color(0.70, 0.76, 0.78), Vector2(70, 610), Vector2(980, 28))
	add_child(status_label)
	add_child(_btn("메인", Vector2(52, 642), Color(0.4, 0.42, 0.46), Vector2(120, 40), func(): GameState.goto("res://home.tscn")))

func _refresh() -> void:
	account_label.text = "%s   ·   보유 %d/%d" % [GameState.account_text(), GameState.unlocked.size(), GameState.ALL_CHARS.size()]
	currency_label.text = GameState.currency_text()
	for child in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()
	for c in GameState.unlocked_defs():
		list_box.add_child(_character_card(c))

func _character_card(c: Dictionary) -> Control:
	var card := ColorRect.new()
	card.color = Color(0.12, 0.34, 0.38, 0.13)
	card.custom_minimum_size = Vector2(1030, 112)
	var cname := str(c.get("name", ""))
	var level := GameState.character_level(cname)
	card.add_child(_label("%s  Lv.%d/%d" % [cname, level, GameState.CHARACTER_MAX_LEVEL],
		20, AMBER, Vector2(18, 12), Vector2(400, 28)))
	card.add_child(_label(str(c.get("role", "")), 14, Color(0.72, 0.80, 0.82), Vector2(18, 42), Vector2(420, 24)))
	var stat_line := "HP %d   DMG %d   HEAL %d   조각 %d" % [
		int(c.get("hp", 0)),
		int(c.get("dmg", 0)),
		int(c.get("heal", 0)),
		int(GameState.character_shards.get(cname, 0)),
	]
	card.add_child(_label(stat_line, 14, Color(0.84, 0.86, 0.76), Vector2(18, 70), Vector2(520, 24)))
	var cost := GameState.character_upgrade_cost(cname)
	var btn_text := "최대 레벨" if level >= GameState.CHARACTER_MAX_LEVEL else "레벨업  골드 %d" % cost
	var btn := _btn(btn_text, Vector2(760, 34), CYAN, Vector2(220, 42), func(): _upgrade(cname))
	btn.disabled = level >= GameState.CHARACTER_MAX_LEVEL
	card.add_child(btn)
	return card

func _upgrade(cname: String) -> void:
	var res := GameState.upgrade_character(cname)
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
