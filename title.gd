extends Control
## 타이틀 화면 — 게임 진입점. 이어하기 / 새 게임 / 도감 / 종료.

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

	var title := _label("베스퍼 회랑", 72, AMBER)
	title.position = Vector2(0, 150); title.size = Vector2(1280, 88)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sub := _label("VESPER CORRIDOR", 20, Color(0.5, 0.62, 0.66))
	sub.position = Vector2(0, 244); sub.size = Vector2(1280, 28)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var tag := _label("등불이 꺼지기 전에, 회랑을 연다", 17, Color(0.62, 0.66, 0.7))
	tag.position = Vector2(0, 286); tag.size = Vector2(1280, 24)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tag)

	var y := 380.0
	if GameState.has_save():
		_menu_btn("이어하기", y, COLD, func(): GameState.goto("res://home.tscn"))
		y += 66.0
	_menu_btn("새 게임", y, AMBER, func():
		GameState.new_game()
		GameState.goto("res://home.tscn"))
	y += 66.0
	_menu_btn("도감", y, Color(0.6, 0.7, 0.8), _open_roster)
	y += 66.0
	_menu_btn("도움말", y, Color(0.5, 0.62, 0.74), _open_help)
	y += 66.0
	_menu_btn("종료", y, Color(0.7, 0.5, 0.5), func(): get_tree().quit())

func _label(text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l

func _menu_btn(text: String, y: float, col: Color, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = Vector2(1280 * 0.5 - 130, y); b.size = Vector2(260, 52)
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.14)
	sb.border_color = Color(col.r, col.g, col.b, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate()
	sh.bg_color = Color(col.r, col.g, col.b, 0.28)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.pressed.connect(cb)
	add_child(b)

func _open_roster() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.add_child(load("res://roster.tscn").instantiate())
	add_child(layer)

func _open_help() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(panel)
	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.045, 0.05, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)
	var title := _label("도움말", 44, AMBER)
	title.position = Vector2(0, 112); title.size = Vector2(1280, 58)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var body := _label(
		"목표: 등불함을 지키며 우측 매듭을 파괴한다.\n\n" +
		"카드: 코스트를 지불해 망자를 전선에 배치한다.\n" +
		"오브: 같은 색 인접 칸을 1/2/4개 골라 캐릭터 스킬을 발동한다.\n" +
		"소신: 등불함 HP를 태워 코스트를 만든다. 너무 태우면 재의 사도가 나온다.\n" +
		"지휘기: 등불함 포격. 위기에는 최후 신호로 바뀐다.\n" +
		"ESC/일시정지: 전투를 멈추고 다시 시작하거나 회랑 맵으로 돌아간다.\n\n" +
		"현재 빌드: 메인화면, 5스테이지 완주, 엔딩, 변종 도전, 모집/상점/채팅/미션/우편/성장/설정/공지/가이드 목업 지원.",
		18, Color(0.82, 0.86, 0.88))
	body.position = Vector2(260, 190); body.size = Vector2(760, 310)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(body)
	var close := _menu_button_instance("닫기", 540, Color(0.5, 0.5, 0.56))
	close.pressed.connect(func(): layer.queue_free())
	panel.add_child(close)

func _menu_button_instance(text: String, y: float, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.position = Vector2(1280 * 0.5 - 130, y); b.size = Vector2(260, 52)
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.14)
	sb.border_color = Color(col.r, col.g, col.b, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate()
	sh.bg_color = Color(col.r, col.g, col.b, 0.28)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	return b
