extends Node2D

## 월드 좌표(-10..10)를 사용하는 저비용 픽셀 회랑. 모든 선/기둥/코어는
## CanvasItem으로 그려져 3D 메시, 조명, 파티클을 사용하지 않는다.

var pulse := 0.0

func _ready() -> void:
	set_process(false)
	queue_redraw()

func _draw() -> void:
	# 제한된 16-bit 팔레트: 먼 벽 → 구조물 → 바닥 순서로 깊이를 만든다.
	draw_rect(Rect2(Vector2(-13.5, -4.6), Vector2(27.0, 4.6)), Color("091516"))
	draw_rect(Rect2(Vector2(-13.5, -3.65), Vector2(27.0, 1.35)), Color("0d2022"))
	draw_rect(Rect2(Vector2(-13.5, -2.3), Vector2(27.0, 1.35)), Color("112a2c"))
	for i in 9:
		var x := -13.0 + float(i) * 3.25
		var w := 1.7 if i % 2 == 0 else 0.9
		draw_rect(Rect2(Vector2(x, -3.48), Vector2(w, 0.12)), Color("285456"))
		draw_rect(Rect2(Vector2(x + 0.18, -3.30), Vector2(w * 0.55, 0.06)), Color(0.25, 0.58, 0.55, 0.38))
	# 후면 격벽과 중앙의 거대한 회랑 문.
	for x in [-12.6, -9.4, -6.2, -3.0, 3.0, 6.2, 9.4, 12.6]:
		draw_rect(Rect2(Vector2(x - 0.11, -3.0), Vector2(0.22, 3.0)), Color("1b3b3d"))
		draw_rect(Rect2(Vector2(x - 0.16, -2.84), Vector2(0.32, 0.08)), Color("326467"))
	draw_rect(Rect2(Vector2(-1.55, -3.15), Vector2(3.1, 2.6)), Color("071011"))
	draw_rect(Rect2(Vector2(-1.43, -3.03), Vector2(2.86, 2.36)), Color("173538"), false, 0.08)
	for y in [-2.75, -2.18, -1.61]:
		draw_line(Vector2(-1.15, y), Vector2(1.15, y), Color(0.27, 0.60, 0.58, 0.35), 0.035)
	# 바닥 플레이트와 중앙 전선.
	draw_rect(Rect2(Vector2(-13.5, -0.02), Vector2(27.0, 2.65)), Color("101f20"))
	draw_rect(Rect2(Vector2(-13.5, 0.10), Vector2(27.0, 0.14)), Color("2d5655"))
	draw_line(Vector2(-13.5, 0.0), Vector2(13.5, 0.0), Color("78d2ba"), 0.05)
	draw_line(Vector2(-13.5, 1.18), Vector2(13.5, 1.18), Color(0.35, 0.70, 0.62, 0.42), 0.035)
	for x in range(-13, 14, 2):
		draw_line(Vector2(x, 0.28), Vector2(x + 0.65, 1.04), Color(0.20, 0.43, 0.43, 0.42), 0.025)
		draw_line(Vector2(x + 0.65, 1.04), Vector2(x + 1.85, 1.04), Color(0.20, 0.43, 0.43, 0.26), 0.025)
	# 양쪽 신호탑: 아군은 amber, 적은 cyan. 대칭을 깨서 화면에 방향성을 준다.
	for x in [-11.7, -7.4, 7.1, 11.3]:
		var signal_color := Color("e7a653") if x < 0.0 else Color("62d9dc")
		draw_rect(Rect2(Vector2(x - 0.10, -2.0), Vector2(0.20, 2.0)), Color("1c3a3b"))
		draw_rect(Rect2(Vector2(x - 0.26, -2.13), Vector2(0.52, 0.12)), signal_color.darkened(0.28))
		draw_rect(Rect2(Vector2(x - 0.11, -2.25), Vector2(0.22, 0.14)), signal_color)
		draw_circle(Vector2(x, -2.27), 0.34, Color(signal_color, 0.10))
	# 작은 픽셀 노이즈/표지판은 고정 좌표로만 그려 결정성을 유지한다.
	for p in [Vector2(-10.2, -1.55), Vector2(-5.5, -2.0), Vector2(4.4, -1.72), Vector2(9.0, -2.26), Vector2(1.8, -2.72)]:
		draw_rect(Rect2(p, Vector2(0.10, 0.10)), Color("74b9ad"))
		draw_rect(Rect2(p + Vector2(0.18, 0.04), Vector2(0.34, 0.04)), Color(0.39, 0.67, 0.62, 0.55))
	_draw_core(Vector2(-8.5, -0.02), Color("f4ad52"), true)
	_draw_core(Vector2(8.5, -0.02), Color("62d9dc"), false)

func _draw_core(pos: Vector2, color: Color, ally: bool) -> void:
	var body := PackedVector2Array([pos + Vector2(-0.55, 0.0), pos + Vector2(0.55, 0.0), pos + Vector2(0.38, -1.25), pos + Vector2(-0.38, -1.25)])
	draw_colored_polygon(body, Color("111b1e"))
	draw_polyline(body, Color("315254"), 0.11, true)
	draw_polyline(body, color, 0.055, true)
	if ally:
		draw_line(pos + Vector2(-0.25, -0.25), pos + Vector2(0.25, -0.95), color, 0.10)
		draw_rect(Rect2(pos + Vector2(-0.20, -0.94), Vector2(0.40, 0.10)), Color("ffe0a1"))
	else:
		draw_circle(pos + Vector2(0, -0.66), 0.48, Color(color, 0.11))
		draw_circle(pos + Vector2(0, -0.66), 0.29, Color("173b3f"))
		draw_circle(pos + Vector2(0, -0.66), 0.17, color)
