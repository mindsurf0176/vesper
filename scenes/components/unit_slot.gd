class_name UnitSlot
extends PanelContainer

const VesperUITheme = preload("res://scenes/ui/vesper_ui.gd")

## 강림판과 벤치의 drop target. 클릭 이동도 같은 signal로 전달한다.

signal pressed(slot: UnitSlot)
signal unit_dropped(slot: UnitSlot, data: Dictionary)

var area := ""
var slot_index := -1
var locked := false
var selected := false:
	set(value):
		selected = value
		_apply_style()

var _title: Label
var _body: CenterContainer
var _hint: Label


func _init() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build()


func _build() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	add_child(v)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 11)
	_title.add_theme_color_override("font_color", Color("b8cec7"))
	v.add_child(_title)
	_body = CenterContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.add_theme_color_override("font_color", Color("7f9d98"))
	v.add_child(_hint)
	_apply_style()


func setup(kind: String, index: int, title: String, is_locked: bool = false,
		hint: String = "") -> void:
	area = kind
	slot_index = index
	locked = is_locked
	_title.text = title
	_hint.text = hint
	mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if locked else Control.CURSOR_POINTING_HAND
	_apply_style()


func clear_card() -> void:
	for c in _body.get_children():
		c.queue_free()


func set_card(card: Control) -> void:
	clear_card()
	_body.add_child(card)


func is_empty() -> bool:
	return _body.get_child_count() == 0


func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(self)
		accept_event()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return not locked and data is Dictionary and data.get("kind", "") == "unit"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	unit_dropped.emit(self, data)


func _apply_style() -> void:
	var bg := Color("0d1b1e")
	var border := Color("2c4a4e")
	if locked:
		bg = Color("091315")
		border = Color("1c3033")
	elif selected:
		border = Color("efc86d")
	var sb := VesperUITheme.panel(bg, border, 8)
	sb.set_border_width_all(2 if selected else 1)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	add_theme_stylebox_override("panel", sb)
