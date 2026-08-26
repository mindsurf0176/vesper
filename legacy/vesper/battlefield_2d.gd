extends Node2D

## 월드 좌표(-10..10)를 사용하는 저비용 픽셀 회랑. 모든 선/기둥/코어는
## CanvasItem으로 그려져 3D 메시, 조명, 파티클을 사용하지 않는다.

var pulse := 0.0

func _ready() -> void:
	set_process(false)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2(-13.5, -0.1), Vector2(27.0, 2.9)), Color("102021"))
	draw_rect(Rect2(Vector2(-13.5, 1.6), Vector2(27.0, 1.2)), Color("183133"))
	draw_line(Vector2(-13.5, 0.0), Vector2(13.5, 0.0), Color("65c7b4"), 0.035)
	draw_line(Vector2(-13.5, 1.2), Vector2(13.5, 1.2), Color(0.28, 0.60, 0.56, 0.38), 0.025)
	for x in [-11.5, -7.0, -2.5, 2.5, 7.0, 11.5]:
		draw_rect(Rect2(Vector2(x - 0.08, -2.0), Vector2(0.16, 2.0)), Color("1c3a3b"))
		draw_rect(Rect2(Vector2(x - 0.18, -2.12), Vector2(0.36, 0.10)), Color("65c7b4"))
		draw_circle(Vector2(x, -2.16), 0.22, Color(0.30, 0.82, 0.72, 0.12))
	_draw_core(Vector2(-8.5, -0.02), Color("f4ad52"), true)
	_draw_core(Vector2(8.5, -0.02), Color("62d9dc"), false)

func _draw_core(pos: Vector2, color: Color, ally: bool) -> void:
	var body := PackedVector2Array([pos + Vector2(-0.55, 0.0), pos + Vector2(0.55, 0.0), pos + Vector2(0.38, -1.25), pos + Vector2(-0.38, -1.25)])
	draw_colored_polygon(body, Color("1d2528"))
	draw_polyline(body, color, 0.07, true)
	if ally:
		draw_line(pos + Vector2(-0.25, -0.25), pos + Vector2(0.25, -0.95), color, 0.08)
	else:
		draw_circle(pos + Vector2(0, -0.66), 0.38, Color(color, 0.25))
		draw_circle(pos + Vector2(0, -0.66), 0.18, color)
