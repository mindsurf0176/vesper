class_name VesperUI
extends RefCounted

## VESPER 전용 UI 재질. 월드의 픽셀 아트와 분리되는 전술 콘솔 계층.

const INK := Color("070d16")
const SURFACE := Color("101b29")
const SURFACE_RAISED := Color("17283a")
const LINE := Color("2b4960")
const CYAN := Color("72d7d0")
const AMBER := Color("f2b95f")
const TEXT := Color("edf4f2")
const MUTED := Color("91a9b2")

static func panel(bg: Color = SURFACE, border: Color = LINE, radius: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	sb.shadow_size = 8
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb

static func button(bg: Color, border: Color, radius: int = 6) -> StyleBoxFlat:
	var sb := panel(bg, border, radius)
	sb.shadow_size = 3
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	return sb

static func title_label(text: String, size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT)
	return label

static func apply_button(button: Button, primary: bool = false) -> void:
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_pressed_color", AMBER)
	button.add_theme_color_override("font_disabled_color", MUTED)
	var normal_bg := Color("1b3145") if primary else Color("142331")
	button.add_theme_stylebox_override("normal", button(normal_bg, CYAN if primary else LINE))
	button.add_theme_stylebox_override("hover", button(Color("24465d"), AMBER))
	button.add_theme_stylebox_override("pressed", button(Color("0c1723"), AMBER))
	button.add_theme_stylebox_override("disabled", button(Color("0e1822"), Color("263644")))
	button.add_theme_stylebox_override("focus", button(Color("24465d"), AMBER))
	button.focus_mode = Control.FOCUS_ALL
