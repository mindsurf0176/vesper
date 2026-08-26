extends Node2D

var points := PackedVector2Array()
var color := Color.WHITE
var radius := 0.12
var lifetime := 0.16
var age := 0.0

func configure(new_points: PackedVector2Array, new_color: Color, new_lifetime: float) -> void:
	points = new_points
	color = new_color
	lifetime = new_lifetime
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	modulate.a = 1.0 - clampf(age / lifetime, 0.0, 1.0)
	queue_redraw()
	if age >= lifetime:
		queue_free()

func _draw() -> void:
	if points.size() >= 2:
		draw_polyline(points, color, 0.075, true)
	for i in points.size():
		draw_circle(points[i], radius * (1.0 - float(i) / maxf(points.size(), 1)), color)
