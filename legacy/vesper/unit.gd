extends Node2D
## 회랑의 한 전사 = 코어 속 망자의 되살아난 전투 기억(플레이스홀더 도형).
## (타입은 main.gd가 preload 상수 VUnit으로 참조)

var main: Node = null
var team := 0          # main.ALLY / main.ENEMY
var utype := 0         # STRIKER/RANGER/DEFENDER/SNIPER/SUPPORT
var uname := ""
var col := Color.WHITE
var max_hp := 10.0
var hp := 10.0
var dmg := 1.0
var atk_range := 40.0
var atk_interval := 1.0
var move_speed := 60.0
var heal := 0.0
var radius := 13.0
var ashen := false      # 재의 사도(아군이 적이 된 유령)

var dir := 1
var atk_timer := 0.0
var dead := false
var hitflash := 0.0

func setup(_main: Node, _team: int, def: Dictionary) -> void:
	main = _main
	team = _team
	utype = def["type"]
	uname = def["name"]
	col = def["col"]
	max_hp = def["hp"]; hp = max_hp
	dmg = def["dmg"]
	atk_range = def["range"]
	atk_interval = 1.0 / float(def["aspd"])
	move_speed = def["move"]
	heal = def.get("heal", 0.0)
	radius = def.get("radius", 13.0)
	dir = 1 if team == main.ALLY else -1

func _physics_process(delta: float) -> void:
	if dead or not main.running:
		return
	atk_timer = max(0.0, atk_timer - delta)
	if hitflash > 0.0:
		hitflash = max(0.0, hitflash - delta)
		queue_redraw()

	# 서포터: 가장 다친 아군을 재점화(힐)
	if utype == main.SUPPORT and heal > 0.0:
		var ally = _wounded_ally()
		if ally != null:
			if atk_timer <= 0.0:
				ally.receive_heal(heal)
				main.float_text("+%d" % int(heal), ally.position + Vector2(0, -radius - 12), Color(0.6, 1.0, 0.7))
				atk_timer = atk_interval
		else:
			_advance(delta)
		return

	# 전투병: 사거리 내 최근접 적 공격, 없으면 전진
	var tgt = _acquire()
	if tgt == null:
		_advance(delta)
	elif tgt is String:           # 적 코어 타격
		if atk_timer <= 0.0:
			main.damage_core(team, dmg)
			var cx: float = main.enemy_core_x() if team == main.ALLY else main.ally_core_x()
			main.spark(Vector2(cx, position.y), col)
			atk_timer = atk_interval
	else:
		if atk_timer <= 0.0:
			var mult: float = main.type_mult(utype, tgt.utype)
			tgt.take_damage(dmg * mult, mult)
			main.spark(tgt.position, col)
			atk_timer = atk_interval

func _acquire():
	var best = null
	var bd := atk_range + 1.0
	for u in main.units:
		if u == self or u.dead or u.team == team:
			continue
		var d: float = abs(u.position.x - position.x)
		if d <= atk_range and d < bd:
			bd = d; best = u
	if best != null:
		return best
	var cx: float = main.enemy_core_x() if team == main.ALLY else main.ally_core_x()
	if abs(cx - position.x) <= atk_range:
		return "CORE"
	return null

func _advance(delta: float) -> void:
	# 앞선 아군과 겹치지 않게(전열 뒤에 종대로 정렬)
	for u in main.units:
		if u == self or u.dead or u.team != team:
			continue
		var ahead: float = (u.position.x - position.x) * dir
		if ahead > 0.0 and ahead < radius * 2.0 + 4.0:
			return
	var nx: float = position.x + dir * move_speed * delta
	nx = clamp(nx, main.ally_core_x() + 26.0, main.enemy_core_x() - 26.0)
	position.x = nx

func _wounded_ally():
	var best = null
	var bd := atk_range + 1.0
	for u in main.units:
		if u == self or u.dead or u.team != team or u.utype == main.SUPPORT:
			continue
		if u.hp >= u.max_hp:
			continue
		var d: float = abs(u.position.x - position.x)
		if d <= atk_range and d < bd:
			bd = d; best = u
	return best

func take_damage(d: float, mult: float) -> void:
	if dead:
		return
	hp -= d
	hitflash = 0.12
	var c := Color(1, 1, 0.5) if mult > 1.05 else (Color(0.7, 0.7, 0.7) if mult < 0.95 else Color(1, 1, 1))
	main.float_text(str(int(round(d))), position + Vector2(0, -radius - 10), c)
	if hp <= 0.0:
		die(true)

func receive_heal(h: float) -> void:
	if dead:
		return
	hp = min(max_hp, hp + h)

func die(killed: bool) -> void:
	if dead:
		return
	dead = true
	main.on_unit_death(self, killed)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(0.1, 0.1), 0.18)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(queue_free)

func _draw() -> void:
	if dead:
		return
	var body := col
	if team == main.ENEMY:
		body = col.darkened(0.18).lerp(Color(0.4, 0.55, 0.6), 0.25)
	if ashen:
		body = Color(0.5, 0.5, 0.55)
	draw_circle(Vector2.ZERO, radius, body)
	if hitflash > 0.0:
		draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, 0.7))
	var rim: Color = main.AMBER if team == main.ALLY else main.COLD
	draw_arc(Vector2.ZERO, radius, 0, TAU, 22, rim, 2.0)
	# 병종 글리프
	draw_string(main.font, Vector2(-radius, radius - 7), main.TYPE_GLYPH[utype],
		HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 13, Color(1, 1, 1, 0.92))
	# HP 바
	var w := radius * 2.0
	var p := Vector2(-radius, -radius - 8.0)
	draw_rect(Rect2(p, Vector2(w, 4)), Color(0, 0, 0, 0.55))
	var frac: float = clamp(hp / max_hp, 0.0, 1.0)
	var hpcol: Color = Color(0.45, 0.9, 0.6) if team == main.ALLY else Color(0.9, 0.45, 0.55)
	draw_rect(Rect2(p, Vector2(w * frac, 4)), hpcol)
