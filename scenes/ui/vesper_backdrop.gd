class_name VesperBackdrop
extends Control

## 픽셀 월드와 UI를 분리하는 비트맵 없는 전술 콘솔 배경.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func _draw() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var top := Color("081516")
	var bottom := Color("101f20")
	draw_rect(Rect2(Vector2.ZERO, s), bottom)
	for i in 8:
		var t := float(i) / 8.0
		draw_rect(Rect2(0.0, s.y * t, s.x, s.y / 8.0 + 1.0), top.lerp(bottom, t * 0.72))
	var horizon := s.y * 0.57
	# 준비·지도 화면도 전투 회랑과 같은 단면으로 읽히도록 천장과 바닥을 분리한다.
	draw_rect(Rect2(0.0, horizon - 80.0, s.x, 80.0), Color(0.04, 0.13, 0.14, 0.30))
	draw_colored_polygon(PackedVector2Array([
		Vector2(s.x * 0.16, horizon), Vector2(s.x * 0.30, horizon),
		Vector2(s.x * 0.48, s.y), Vector2(s.x * 0.36, s.y),
	]), Color(0.16, 0.48, 0.46, 0.055))
	draw_colored_polygon(PackedVector2Array([
		Vector2(s.x * 0.70, horizon), Vector2(s.x * 0.84, horizon),
		Vector2(s.x * 0.64, s.y), Vector2(s.x * 0.52, s.y),
	]), Color(0.16, 0.48, 0.46, 0.035))
	draw_line(Vector2(0.0, horizon), Vector2(s.x, horizon), Color("274548"), 2.0)
	draw_line(Vector2(0.0, s.y * 0.78), Vector2(s.x, s.y * 0.78), Color(0.10, 0.25, 0.25, 0.8), 2.0)
	for y in [0.65, 0.70, 0.86, 0.93]:
		var floor_y := lerpf(horizon, s.y, float(y))
		draw_line(Vector2(0.0, floor_y), Vector2(s.x, floor_y), Color(0.18, 0.38, 0.38, 0.16), 1.0)
	for x in [0.08, 0.25, 0.75, 0.92]:
		var px: float = s.x * float(x)
		draw_rect(Rect2(px - 3.0, horizon - 58.0, 6.0, 58.0), Color("173536"))
		draw_circle(Vector2(px, horizon - 63.0), 8.0, Color(0.35, 0.82, 0.78, 0.16))
		draw_circle(Vector2(px, horizon - 63.0), 3.0, Color("80e0c6"))
		var panel := Rect2(px - s.x * 0.075, horizon - 43.0, s.x * 0.15, 20.0)
		draw_rect(panel, Color(0.03, 0.12, 0.13, 0.52))
		draw_rect(panel, Color(0.20, 0.48, 0.47, 0.22), false, 1.0)
	for i in range(1, 8):
		var x := s.x * float(i) / 8.0
		draw_line(Vector2(x, horizon + 14.0), Vector2(x, s.y), Color(0.22, 0.45, 0.43, 0.20), 1.0)
