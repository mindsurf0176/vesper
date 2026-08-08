extends Control
## 모바일 메인 화면 — 전투/모집/상점/채팅/도감으로 가는 허브.

const AMBER := Color(1.0, 0.74, 0.36)
const COLD := Color(0.36, 0.86, 0.92)
const BG := Color(0.045, 0.075, 0.085)

var font: Font
var status_label: Label
var currency_label: Label

func _ready() -> void:
	font = load("res://assets/Galmuri11.ttf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := _label("등불함 지휘실", 46, AMBER, Vector2(48, 34), Vector2(420, 58))
	add_child(title)
	var st := GameState.current_stage_def()
	status_label = _label("현재 회랑 · %s / 돌파 %d/%d" % [st["name"], GameState.cleared.size(), GameState.STAGES.size()],
		17, Color(0.64, 0.70, 0.72), Vector2(52, 92), Vector2(760, 28))
	add_child(status_label)
	var account := _label(GameState.account_text(), 15, Color(0.76, 0.82, 0.82), Vector2(52, 120), Vector2(760, 24))
	add_child(account)
	currency_label = _label(GameState.currency_text(), 16, Color(0.86, 0.90, 0.88), Vector2(760, 42), Vector2(460, 26))
	currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(currency_label)

	_panel("오늘의 운구", "출석 보상과 모집권을 챙기고 회랑에 진입하세요.", Vector2(62, 150), Vector2(520, 128), AMBER)
	var daily := _btn("출석 보상 받기", Vector2(92, 222), Color(0.42, 0.28, 0.12), Vector2(190, 40))
	daily.pressed.connect(_claim_daily)
	add_child(daily)

	_panel("전투 준비", "스테이지 규칙을 확인하고 편성·각인을 조정합니다.", Vector2(62, 310), Vector2(520, 180), COLD)
	add_child(_nav_btn("회랑 진입", Vector2(92, 388), AMBER, "res://stagemap.tscn"))
	add_child(_nav_btn("편성", Vector2(300, 388), COLD, "res://squad.tscn"))

	_panel("모바일 메타", "모집, 상점, 채팅, 미션, 우편, 성장, 시스템 화면까지 저장되는 목업 라이브옵스입니다.", Vector2(650, 150), Vector2(520, 430), Color(0.62, 0.64, 0.82))
	add_child(_nav_btn("모집", Vector2(690, 238), AMBER, "res://gacha.tscn"))
	add_child(_nav_btn("상점", Vector2(900, 238), Color(0.55, 0.72, 0.95), "res://shop.tscn"))
	add_child(_nav_btn("채팅", Vector2(690, 306), Color(0.52, 0.78, 0.62), "res://chat.tscn"))
	var roster := _btn("도감", Vector2(900, 306), Color(0.45, 0.55, 0.70), Vector2(170, 48))
	roster.pressed.connect(_open_roster)
	add_child(roster)
	add_child(_nav_btn("미션", Vector2(690, 374), Color(0.72, 0.56, 0.88), "res://missions.tscn"))
	add_child(_nav_btn("우편", Vector2(900, 374), Color(0.78, 0.62, 0.40), "res://mail.tscn"))
	add_child(_nav_btn("성장", Vector2(690, 442), Color(0.44, 0.78, 0.88), "res://growth.tscn"))
	add_child(_nav_btn("설정", Vector2(900, 442), Color(0.60, 0.68, 0.78), "res://settings.tscn"))
	var notice_text := "공지 %d" % GameState.unread_notice_count() if GameState.unread_notice_count() > 0 else "공지"
	add_child(_nav_btn(notice_text, Vector2(690, 510), Color(0.92, 0.62, 0.42), "res://notice.tscn", Vector2(112, 40)))
	add_child(_nav_btn("가이드", Vector2(820, 510), Color(0.48, 0.76, 0.70), "res://guide.tscn", Vector2(112, 40)))
	add_child(_nav_btn("크레딧", Vector2(950, 510), Color(0.70, 0.62, 0.88), "res://credits.tscn", Vector2(112, 40)))

	var bottom := _label("수익구조 목업: 초회팩 · 월정액 · 보상형 광고 · 루멘 모집. 실제 결제/광고 SDK는 미연동.", 14,
		Color(0.58, 0.62, 0.64), Vector2(0, 625), Vector2(1280, 24))
	bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(bottom)
	add_child(_nav_btn("타이틀", Vector2(48, 642), Color(0.4, 0.42, 0.46), "res://title.tscn", Vector2(120, 40)))

func _claim_daily() -> void:
	var res := GameState.claim_daily_reward()
	status_label.text = str(res.get("message", ""))
	currency_label.text = GameState.currency_text()

func _open_roster() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.add_child(load("res://roster.tscn").instantiate())
	add_child(layer)

func _panel(title: String, body: String, pos: Vector2, size: Vector2, col: Color) -> void:
	var box := ColorRect.new()
	box.color = Color(col.r, col.g, col.b, 0.08)
	box.position = pos
	box.size = size
	add_child(box)
	var h := _label(title, 24, col, pos + Vector2(24, 18), Vector2(size.x - 48, 30))
	add_child(h)
	var b := _label(body, 15, Color(0.74, 0.78, 0.78), pos + Vector2(24, 54), Vector2(size.x - 48, 48))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(b)

func _nav_btn(text: String, pos: Vector2, col: Color, path: String, size := Vector2(170, 48)) -> Button:
	var b := _btn(text, pos, col, size)
	b.pressed.connect(func(): GameState.goto(path))
	return b

func _label(text: String, sz: int, col: Color, pos: Vector2, size: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l

func _btn(text: String, pos: Vector2, col: Color, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 18)
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
	return b
