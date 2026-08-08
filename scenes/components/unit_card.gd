class_name UnitCard
extends PanelContainer

## 상점·벤치·강림판에서 같은 정보를 보여 주는 성좌 카드.

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


func _init() -> void:
	custom_minimum_size = Vector2(78, 92)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build()


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	add_child(box)

	var glyph := Control.new()
	glyph.custom_minimum_size = Vector2(62, 58)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.clip_contents = true
	box.add_child(glyph)
	_art = TextureRect.new()
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.add_child(_art)
	_line_tex = TextureRect.new()
	_line_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_line_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_line_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_line_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.add_child(_line_tex)
	_node_tex = TextureRect.new()
	_node_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_node_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_node_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_node_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.add_child(_node_tex)
	_gradient = TextureRect.new()
	_gradient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gradient.texture = preload("res://assets/ui/card_gradient.png")
	_gradient.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gradient.stretch_mode = TextureRect.STRETCH_SCALE
	_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.add_child(_gradient)

	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 11)
	_name.add_theme_color_override("font_color", Color("f0f2ff"))
	box.add_child(_name)

	_meta = Label.new()
	_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meta.add_theme_font_size_override("font_size", 9)
	_meta.add_theme_color_override("font_color", Color("aeb6df"))
	box.add_child(_meta)

	_time = Label.new()
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.add_theme_font_size_override("font_size", 9)
	_time.add_theme_color_override("font_color", Color("ffd98a"))
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
	_name.text = "%s%s" % [d["name"], "★".repeat(star)]
	_meta.text = "%d골드 · 기운 %d" % [int(d["tier"]), UnitDB.deploy_cost(unit["def_id"])]
	_time.text = time_text
	tooltip_text = tooltip
	var def_id := String(unit["def_id"])
	var portrait := CharacterVisuals.texture(def_id, "portrait")
	_art.texture = portrait
	_art.visible = portrait != null
	_gradient.visible = portrait != null
	_line_tex.texture = StarVisuals.STAR_LINE[def_id]
	_line_tex.modulate = Color("dfe3ff")
	_line_tex.visible = portrait == null
	_node_tex.texture = StarVisuals.STAR_NODE[def_id]
	_node_tex.modulate = StarVisuals.ELEMENT_COLOR[d["element"]]
	_node_tex.visible = portrait == null
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
		add_theme_stylebox_override("panel", _style(Color("222846"), Color("3d4775"), 1))
		return
	var d := UnitDB.get_def(String(_unit["def_id"]))
	var border := Color("ffd98a") if selected else StarVisuals.tier_color(int(d["tier"]))
	add_theme_stylebox_override("panel", _style(Color("202643"), border, 3 if selected else 2))


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
