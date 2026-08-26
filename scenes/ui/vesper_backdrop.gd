class_name VesperBackdrop
extends Control

## 픽셀 월드와 UI를 분리하는 비트맵 없는 전술 콘솔 배경.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("070d16"))
	for i in 7:
		var y := size.y * float(i) / 7.0
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.12, 0.24, 0.32, 0.16), 1.0)
	for x in range(32, int(size.x), 64):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.15, 0.36, 0.43, 0.12), 1.0)
	for y in range(28, int(size.y), 64):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.15, 0.36, 0.43, 0.10), 1.0)
	var glow := Color(0.25, 0.72, 0.76, 0.07)
	draw_circle(Vector2(size.x * 0.82, size.y * 0.18), minf(size.x, size.y) * 0.28, glow)
	draw_circle(Vector2(size.x * 0.18, size.y * 0.82), minf(size.x, size.y) * 0.22, Color(0.75, 0.48, 0.18, 0.045))
	var bracket := Color(0.45, 0.84, 0.82, 0.38)
	var m := 20.0
	var l := 42.0
	draw_line(Vector2(m, m), Vector2(m + l, m), bracket, 2.0)
	draw_line(Vector2(m, m), Vector2(m, m + l), bracket, 2.0)
	draw_line(Vector2(size.x - m, size.y - m), Vector2(size.x - m - l, size.y - m), bracket, 2.0)
	draw_line(Vector2(size.x - m, size.y - m), Vector2(size.x - m, size.y - m - l), bracket, 2.0)
