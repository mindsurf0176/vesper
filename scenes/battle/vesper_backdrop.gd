extends Control

## 전투 배경은 2D로 고정한다. 캐릭터 Node3D는 유지하되, 배경에 3D 메시와
## 조명을 쌓지 않아 웹/저사양 기기에서 드로우콜과 픽셀 비용을 줄인다.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
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
	draw_line(Vector2(0.0, horizon), Vector2(s.x, horizon), Color("274548"), 2.0)
	draw_line(Vector2(0.0, s.y * 0.78), Vector2(s.x, s.y * 0.78), Color(0.10, 0.25, 0.25, 0.8), 2.0)
	for x in [0.08, 0.25, 0.75, 0.92]:
		var px: float = s.x * float(x)
		draw_rect(Rect2(px - 3.0, horizon - 58.0, 6.0, 58.0), Color("173536"))
		draw_circle(Vector2(px, horizon - 63.0), 8.0, Color(0.35, 0.82, 0.78, 0.16))
		draw_circle(Vector2(px, horizon - 63.0), 3.0, Color("80e0c6"))
	for i in range(1, 8):
		var x := s.x * float(i) / 8.0
		draw_line(Vector2(x, horizon + 14.0), Vector2(x, s.y), Color(0.22, 0.45, 0.43, 0.20), 1.0)
