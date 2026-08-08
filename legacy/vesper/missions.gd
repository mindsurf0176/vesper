extends Control
## 미션/배틀패스 화면 — 일일·업적 진행도와 패스 보상을 로컬 저장 상태로 검증한다.

const AMBER := Color(1.0, 0.74, 0.36)
const BG := Color(0.045, 0.065, 0.08)
const VIOLET := Color(0.72, 0.56, 0.88)

var font: Font
var mission_list: VBoxContainer
var pass_list: VBoxContainer
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
	add_child(_label("미션 / 회랑 패스", 44, AMBER, Vector2(52, 38), Vector2(420, 56)))
	account_label = _label("", 16, Color(0.78, 0.84, 0.84), Vector2(52, 96), Vector2(520, 24))
	add_child(account_label)
	currency_label = _label("", 16, Color(0.86, 0.90, 0.88), Vector2(720, 48), Vector2(500, 24))
	currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(currency_label)

	var left_title := _label("일일 / 업적", 24, VIOLET, Vector2(70, 132), Vector2(360, 32))
	add_child(left_title)
	var mission_scroll := ScrollContainer.new()
	mission_scroll.position = Vector2(70, 174)
	mission_scroll.size = Vector2(730, 408)
	add_child(mission_scroll)
	mission_list = VBoxContainer.new()
	mission_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_scroll.add_child(mission_list)

	var right_title := _label("회랑 패스", 24, AMBER, Vector2(850, 132), Vector2(320, 32))
	add_child(right_title)
	var pass_scroll := ScrollContainer.new()
	pass_scroll.position = Vector2(850, 174)
	pass_scroll.size = Vector2(340, 408)
	add_child(pass_scroll)
	pass_list = VBoxContainer.new()
	pass_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_scroll.add_child(pass_list)

	status_label = _label("미션은 전투·모집·채팅·상점·성장 행동으로 진행됩니다.", 15,
		Color(0.70, 0.76, 0.78), Vector2(70, 604), Vector2(960, 28))
	add_child(status_label)
	add_child(_btn("메인", Vector2(52, 642), Color(0.4, 0.42, 0.46), Vector2(120, 40), func(): GameState.goto("res://home.tscn")))

func _refresh() -> void:
	account_label.text = "%s   ·   패스 Lv.%d / XP %d" % [GameState.account_text(), GameState.battle_pass_level(), GameState.battle_pass_xp]
	currency_label.text = GameState.currency_text()
	for child in mission_list.get_children():
		mission_list.remove_child(child)
		child.queue_free()
	for mission in GameState.mission_defs():
		mission_list.add_child(_mission_card(mission))
	for child in pass_list.get_children():
		pass_list.remove_child(child)
		child.queue_free()
	for reward_def in GameState.battle_pass_track():
		pass_list.add_child(_pass_card(reward_def))

func _mission_card(mission: Dictionary) -> Control:
	var card := ColorRect.new()
	card.color = Color(0.40, 0.32, 0.52, 0.13)
	card.custom_minimum_size = Vector2(700, 112)
	var progress := GameState.mission_progress(mission)
	var title := "%s · %s" % [str(mission.get("category", "")), str(mission.get("title", ""))]
	card.add_child(_label(title, 18, AMBER, Vector2(18, 12), Vector2(420, 26)))
	var desc := _label(str(mission.get("desc", "")), 14, Color(0.72, 0.78, 0.78), Vector2(18, 42), Vector2(470, 24))
	card.add_child(desc)
	var progress_text := "진행 %d/%d" % [int(progress.get("value", 0)), int(progress.get("target", 1))]
	var rewards: Dictionary = mission.get("rewards", {})
	var reward_line := "%s · 패스 XP +%d" % [GameState.rewards_text(rewards), int(mission.get("pass_xp", 0))]
	card.add_child(_label("%s   |   %s" % [progress_text, reward_line], 13,
		Color(0.84, 0.82, 0.66), Vector2(18, 70), Vector2(510, 24)))
	var claimed := bool(progress.get("claimed", false))
	var complete := bool(progress.get("complete", false))
	var btn_text := "수령 완료" if claimed else ("수령" if complete else "진행 중")
	var btn := _btn(btn_text, Vector2(560, 35), VIOLET, Vector2(120, 42), func(): _claim_mission(str(mission.get("id", ""))))
	btn.disabled = claimed or not complete
	card.add_child(btn)
	return card

func _pass_card(reward_def: Dictionary) -> Control:
	var card := ColorRect.new()
	card.color = Color(0.48, 0.34, 0.10, 0.14)
	card.custom_minimum_size = Vector2(310, 96)
	var level := int(reward_def.get("level", 0))
	var reached := level <= GameState.battle_pass_level()
	var claimed := GameState.battle_pass_claimed.has(str(level))
	card.add_child(_label("Lv.%d · %s" % [level, str(reward_def.get("title", ""))], 17, AMBER, Vector2(16, 12), Vector2(210, 24)))
	var rewards: Dictionary = reward_def.get("rewards", {})
	card.add_child(_label(GameState.rewards_text(rewards), 13, Color(0.84, 0.82, 0.66), Vector2(16, 42), Vector2(180, 24)))
	var btn_text := "수령 완료" if claimed else ("수령" if reached else "잠김")
	var btn := _btn(btn_text, Vector2(206, 30), AMBER, Vector2(88, 36), func(): _claim_pass(level))
	btn.disabled = claimed or not reached
	card.add_child(btn)
	return card

func _claim_mission(mission_id: String) -> void:
	var res := GameState.claim_mission(mission_id)
	status_label.text = str(res.get("message", ""))
	_refresh()

func _claim_pass(level: int) -> void:
	var res := GameState.claim_battle_pass(level)
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
