class_name UnitCard
extends PanelContainer

## 상점·대기석·강림판에서 인물과 호출 비용을 우선해 보여 주는 사도 카드.

signal activated(card: UnitCard)

var roster_index := -1
var source := ""
var order := -1
var selectable := true
var draggable := true
var selected := false:
	set(value):
		selected = value
		_apply_style()

var _unit: Dictionary = {}
var _art: TextureRect
var _gradient: TextureRect
var _line_tex: TextureRect
var _node_tex: TextureRect
var _name: Label
var _meta: Label
var _time: Label
var _blocked_badge: Label


func _init() -> void:
	custom_minimum_size = Vector2(92, 108)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build()


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	add_child(box)

	var portrait_frame := Control.new()
	portrait_frame.custom_minimum_size = Vector2(78, 72)
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.clip_contents = true
	box.add_child(portrait_frame)
	_art = TextureRect.new()
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(_art)
	_line_tex = TextureRect.new()
	_line_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_line_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_line_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_line_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(_line_tex)
	_node_tex = TextureRect.new()
	_node_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_node_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_node_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_node_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(_node_tex)
	_gradient = TextureRect.new()
	_gradient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gradient.texture = preload("res://assets/ui/card_gradient.png")
	_gradient.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gradient.stretch_mode = TextureRect.STRETCH_SCALE
	_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(_gradient)
	_blocked_badge = Label.new()
	_blocked_badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blocked_badge.text = "VISUAL\nPENDING"
	_blocked_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blocked_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_blocked_badge.add_theme_font_size_override("font_size", 10)
	_blocked_badge.add_theme_color_override("font_color", Color("83aea9"))
	_blocked_badge.add_theme_color_override("font_shadow_color", Color("061113"))
	_blocked_badge.add_theme_constant_override("shadow_offset_x", 1)
	_blocked_badge.add_theme_constant_override("shadow_offset_y", 1)
	_blocked_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(_blocked_badge)

	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 12)
	_name.add_theme_color_override("font_color", Color("eef4f1"))
	box.add_child(_name)

	_meta = Label.new()
	_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meta.add_theme_font_size_override("font_size", 9)
	_meta.add_theme_color_override("font_color", Color("91aaa7"))
	box.add_child(_meta)

	_time = Label.new()
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.add_theme_font_size_override("font_size", 9)
	_time.add_theme_color_override("font_color", Color("efc86d"))
	box.add_child(_time)
	_apply_style()


func setup(unit: Dictionary, index: int, from: String, tooltip: String = "",
		time_text: String = "") -> void:
	_unit = unit
	roster_index = index
	source = from
	order = int(unit.get("order", -1))
	var d := UnitDB.get_def(String(unit["def_id"]))
	var star := int(unit.get("star", 1))
	_name.text = "%s  %s" % [d["name"], "★".repeat(star)]
	_meta.text = "%dG  ·  기운 %d" % [int(d["tier"]), UnitDB.deploy_cost(unit["def_id"])]
	_time.text = time_text
	tooltip_text = tooltip
	var def_id := String(unit["def_id"])
	var portrait := CharacterVisuals.texture(def_id, "portrait")
	_art.texture = portrait
	_art.visible = portrait != null
	_gradient.visible = portrait != null
	_blocked_badge.visible = portrait == null
	_line_tex.texture = null
	_line_tex.visible = false
	_node_tex.texture = null
	_node_tex.visible = false
	if portrait == null:
		_art.texture = null
		_art.visible = false
		_gradient.visible = false
		tooltip_text += "\n\n[신규 STARLINE 비주얼 제작 대기 — gameplay 사용 가능]"
	_apply_style()


func unit_data() -> Dictionary:
	return _unit


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and selectable:
		modulate = Color(1.05, 1.05, 1.08, 1.0)
	if not selectable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		activated.emit(self)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		modulate = Color.WHITE


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not selectable or not draggable or roster_index < 0:
		return null
	var preview := duplicate()
	preview.modulate = Color(1, 1, 1, 0.88)
	set_drag_preview(preview)
	return {"kind": "unit", "roster_index": roster_index, "source": source, "order": order}


func _apply_style() -> void:
	if _unit.is_empty():
		add_theme_stylebox_override("panel", _style(Color("0c191b"), Color("29464a"), 1))
		return
	var d := UnitDB.get_def(String(_unit["def_id"]))
	var border := Color("efc86d") if selected else StarVisuals.tier_color(int(d["tier"]))
	add_theme_stylebox_override("panel", _style(Color("102124"), border, 3 if selected else 2))


static func _style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	return sb
