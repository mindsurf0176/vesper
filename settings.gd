extends Control
## 설정 화면 — 실제 오디오 믹서/플랫폼 옵션 연결 전 로컬 설정 계약을 검증한다.

const AMBER := Color(1.0, 0.74, 0.36)
const BG := Color(0.045, 0.065, 0.08)
const BLUE := Color(0.60, 0.68, 0.78)

var font: Font
var list_box: VBoxContainer
var status_label: Label
var terms_label: Label

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
	add_child(_label("설정", 44, AMBER, Vector2(52, 42), Vector2(260, 54)))
	add_child(_label("실제 오디오/진동/프레임 옵션 연결 전 저장 계약을 먼저 닫는 화면입니다.", 15,
		Color(0.70, 0.76, 0.78), Vector2(54, 102), Vector2(760, 24)))
	list_box = VBoxContainer.new()
	list_box.position = Vector2(70, 150)
	list_box.size = Vector2(760, 360)
	add_child(list_box)
	terms_label = _label("", 15, Color(0.84, 0.82, 0.66), Vector2(70, 532), Vector2(760, 26))
	add_child(terms_label)
	add_child(_btn("테스트 약관 확인", Vector2(70, 566), AMBER, Vector2(190, 42), _accept_terms))
	add_child(_btn("기본값", Vector2(282, 566), BLUE, Vector2(140, 42), _reset))
	status_label = _label("설정은 세이브에 저장됩니다.", 15, Color(0.70, 0.76, 0.78), Vector2(70, 618), Vector2(760, 24))
	add_child(status_label)
	add_child(_btn("메인", Vector2(52, 642), Color(0.4, 0.42, 0.46), Vector2(120, 40), func(): GameState.goto("res://home.tscn")))

func _refresh() -> void:
	for child in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()
	list_box.add_child(_setting_row("마스터 볼륨", "master_volume", true))
	list_box.add_child(_setting_row("BGM 볼륨", "bgm_volume", true))
	list_box.add_child(_setting_row("효과음 볼륨", "sfx_volume", true))
	list_box.add_child(_setting_row("진동", "vibration", false))
	list_box.add_child(_setting_row("움직임 줄이기", "reduced_motion", false))
	list_box.add_child(_setting_row("60 FPS 우선", "fps_60", false))
	list_box.add_child(_setting_row("안전 영역 보정", "safe_area", false))
	terms_label.text = "약관 상태: %s  ·  버전 %s" % ["확인 필요" if GameState.terms_needed() else "확인 완료", GameState.TERMS_VERSION]

func _setting_row(title: String, key: String, is_volume: bool) -> Control:
	var card := ColorRect.new()
	card.color = Color(0.28, 0.34, 0.42, 0.14)
	card.custom_minimum_size = Vector2(720, 48)
	card.add_child(_label(title, 17, Color(0.86, 0.90, 0.90), Vector2(18, 10), Vector2(260, 28)))
	card.add_child(_label(_setting_value(key), 15, Color(0.84, 0.82, 0.66), Vector2(330, 12), Vector2(180, 24)))
	var btn := _btn("변경", Vector2(560, 7), BLUE, Vector2(110, 34), func(): _change_setting(key, is_volume))
	card.add_child(btn)
	return card

func _setting_value(key: String) -> String:
	var data := GameState.settings_copy()
	if ["master_volume", "bgm_volume", "sfx_volume"].has(key):
		return "%d%%" % int(round(float(data.get(key, 1.0)) * 100.0))
	return "켜짐" if bool(data.get(key, false)) else "꺼짐"

func _change_setting(key: String, is_volume: bool) -> void:
	var res := GameState.cycle_volume_setting(key) if is_volume else GameState.toggle_setting(key)
	status_label.text = str(res.get("message", ""))
	_refresh()

func _accept_terms() -> void:
	var res := GameState.accept_terms()
	status_label.text = str(res.get("message", ""))
	_refresh()

func _reset() -> void:
	var res := GameState.reset_settings()
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
