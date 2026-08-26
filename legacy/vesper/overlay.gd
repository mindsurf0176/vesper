extends Node2D
## HD-2D 위에 얹는 2D HUD. 코스트/코어HP/각명 + 각 유닛 HP바(3D→화면 투영).

var main = null

func _draw() -> void:
	if main == null:
		return
	_deploy_zone()
	_unit_bars()
	_top_hud()
	_roster()

func _deploy_zone() -> void:
	if not main.has_method("deployment_min_x") or not main.has_method("world_to_screen"):
		return
	if main.has_method("_tutorial_enabled") and not main._tutorial_enabled("deploy_position"):
		return
	var min_x: float = main.deployment_min_x()
	var max_x: float = main.deployment_max_x()
	var pts: Array[Vector2] = []
	for wp in [
		Vector3(min_x, 0.03, -1.65),
		Vector3(max_x, 0.03, -1.65),
		Vector3(max_x, 0.03, 1.65),
		Vector3(min_x, 0.03, 1.65),
	]:
		pts.append(main.world_to_screen(wp))
	var fill := Color(main.AMBER.r, main.AMBER.g, main.AMBER.b, 0.10)
	var line := Color(main.AMBER.r, main.AMBER.g, main.AMBER.b, 0.55)
	if main.pending_card_slot >= 0:
		fill.a = 0.20
		line.a = 0.95
	draw_colored_polygon(PackedVector2Array(pts), fill)
	for i in pts.size():
		draw_line(pts[i], pts[(i + 1) % pts.size()], line, 2.0)
	if main.pending_card_slot >= 0:
		var mid: Vector2 = (pts[0] + pts[1]) * 0.5
		draw_string(main.font, mid + Vector2(-90, -10), "배치 가능 영역", HORIZONTAL_ALIGNMENT_CENTER, 180, 14, Color(1.0, 0.86, 0.55, 0.92))

func _unit_bars() -> void:
	if not main.has_method("world_to_screen"):
		return
	for u in main.units:
		if u.dead:
			continue
		var wp: Vector3 = u.top_world()
		var sp: Vector2 = main.world_to_screen(wp)
		var w := 30.0
		var p := sp - Vector2(w * 0.5, 0)
		draw_rect(Rect2(p, Vector2(w, 4)), Color(0, 0, 0, 0.55))
		var frac: float = clamp(u.hp / u.max_hp, 0.0, 1.0)
		var hc: Color = Color(0.45, 0.9, 0.6) if u.team == main.ALLY else Color(0.92, 0.45, 0.55)
		draw_rect(Rect2(p, Vector2(w * frac, 4)), hc)

func _bar(p: Vector2, sz: Vector2, frac: float, fill: Color, label: String) -> void:
	draw_rect(Rect2(p, sz), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(p, Vector2(sz.x * clamp(frac, 0, 1), sz.y)), fill)
	draw_rect(Rect2(p, sz), Color(1, 1, 1, 0.12), false, 1.0)
	draw_string(main.font, p + Vector2(8, sz.y - 6), label, HORIZONTAL_ALIGNMENT_LEFT, sz.x - 12, 14, Color(1, 1, 1, 0.93))

func _top_hud() -> void:
	var W: float = main.W
	var ship_name: String = str(main.ship_contract.get("name", "등불함"))
	var ally_label := "%s  %d / %d" % [ship_name, int(main.ally_hp), int(main.ally_hp_max)]
	if main.core_invuln > 0.0:
		ally_label += "  ·  방벽 %.1f초" % main.core_invuln
	_bar(Vector2(28, 20), Vector2(360, 24), main.ally_hp / main.ally_hp_max, main.AMBER,
		ally_label)
	_bar(Vector2(W - 28 - 360, 20), Vector2(360, 24), main.enemy_hp / main.enemy_hp_max, Color(main.CYAN.r * 0.85, main.CYAN.g, main.CYAN.b),
		"매듭  %d / %d" % [int(main.enemy_hp), int(main.enemy_hp_max)])
	var cp := Vector2(W * 0.5 - 170, 22)
	draw_rect(Rect2(cp, Vector2(340, 20)), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(cp, Vector2(340 * clamp(main.cost / main.COST_MAX, 0, 1), 20)), Color(0.55, 0.82, 0.95, 0.92))
	for k in range(1, 10):
		var x := cp.x + 340.0 * (k / 10.0)
		draw_line(Vector2(x, cp.y), Vector2(x, cp.y + 20), Color(0, 0, 0, 0.35), 1.0)
	draw_string(main.font, Vector2(cp.x, cp.y + 38), "코스트  %.1f / %d" % [main.cost, int(main.COST_MAX)],
		HORIZONTAL_ALIGNMENT_CENTER, 340, 15, Color(0.82, 0.93, 1.0))
	var field_full: bool = main.ally_count() >= main.CAP
	var field_color := Color(1.0, 0.55, 0.42) if field_full else Color(0.72, 0.82, 0.84)
	var field_text := "전선  %d / %d" % [main.ally_count(), main.CAP]
	if field_full:
		field_text += "  ·  포화"
	draw_string(main.font, Vector2(cp.x, cp.y + 60), field_text,
		HORIZONTAL_ALIGNMENT_CENTER, 340, 14, field_color)
	if main.deploy_feedback_time > 0.0:
		var fp := Vector2(W * 0.5 - 260, 590)
		draw_rect(Rect2(fp, Vector2(520, 38)), Color(0.025, 0.045, 0.05, 0.88))
		draw_rect(Rect2(fp, Vector2(520, 38)), Color(1.0, 0.72, 0.4, 0.38), false, 1.0)
		draw_string(main.font, fp + Vector2(0, 25), main.deploy_feedback,
			HORIZONTAL_ALIGNMENT_CENTER, 520, 15, Color(0.95, 0.91, 0.82))

func _roster() -> void:
	var x := 28.0; var y := 58.0
	draw_string(main.font, Vector2(x, y), "각명  남은 망자 %d" % (main.roster_names.size() - main.roster_struck),
		HORIZONTAL_ALIGNMENT_LEFT, 220, 13, Color(0.7, 0.78, 0.8))
	for i in main.roster_names.size():
		var yy: float = y + 18.0 + i * 15.0
		var struck: bool = i < main.roster_struck
		var c := Color(0.35, 0.35, 0.38) if struck else Color(0.85, 0.8, 0.7)
		draw_string(main.font, Vector2(x + 6, yy), main.roster_names[i], HORIZONTAL_ALIGNMENT_LEFT, 120, 12, c)
		if struck:
			draw_line(Vector2(x + 4, yy - 4), Vector2(x + 70, yy - 4), Color(0.9, 0.4, 0.35, 0.7), 1.5)
