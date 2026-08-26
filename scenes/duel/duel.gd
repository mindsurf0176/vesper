extends Node2D

## Vesper DuelSpec v1
## 플레이어가 한 명을 골라 이동/점프/약공격/강공격/필살기로 상대를 쓰러뜨린다.
## 전투 판정은 좌표, 쿨다운, 히트 프레임으로 결정되며 픽셀 렌더러와 독립적이다.

const Actor = preload("res://scenes/duel/duel_actor.gd")
const W := 1280.0
const H := 720.0
const GROUND_Y := 558.0
const LEFT_LIMIT := 110.0
const RIGHT_LIMIT := 1170.0

var player_def: Dictionary = {}
var enemy_def: Dictionary = {}
var player: Node2D
var enemy: Node2D
var player_hp := 100.0
var enemy_hp := 100.0
var player_meter := 0.0
var enemy_meter := 0.0
var player_cooldown := 0.0
var enemy_cooldown := 0.0
var player_attack_lock := 0.0
var enemy_attack_lock := 0.0
var player_y_velocity := 0.0
var enemy_y_velocity := 0.0
var ended := false
var winner := -1
var elapsed := 0.0
var message := "READY"
var message_timer := 1.0
var controls: CanvasLayer
var player_bar: ColorRect
var enemy_bar: ColorRect
var player_label: Label
var enemy_label: Label
var timer_label: Label

func _ready() -> void:
	if player_def.is_empty():
		player_def = {"name":"진혼병", "dmg":13, "hp":78, "sprite":"res://assets/sprites/jinhonbyeong_pl", "visual":{"primary":Color("bd684f"),"accent":Color("f4ad52")}}
	if enemy_def.is_empty():
		enemy_def = {"name":"급조 항체", "dmg":12, "hp":70, "visual":{"primary":Color("708891"),"accent":Color("62d9dc")}}
	_build_actors()
	_build_hud()
	queue_redraw()

func _build_actors() -> void:
	player = Actor.new()
	player.setup(player_def, 0)
	player.position = Vector2(340.0, GROUND_Y)
	add_child(player)
	enemy = Actor.new()
	enemy.setup(enemy_def, 1)
	enemy.position = Vector2(940.0, GROUND_Y)
	add_child(enemy)

func _build_hud() -> void:
	controls = CanvasLayer.new()
	add_child(controls)
	var font := load("res://assets/Galmuri11.ttf")
	player_label = _label(str(player_def.get("name", "PLAYER")), Vector2(54, 28), 22, Color("f4ad52"))
	enemy_label = _label(str(enemy_def.get("name", "RIVAL")), Vector2(1000, 28), 22, Color("62d9dc"))
	timer_label = _label("99", Vector2(610, 34), 30, Color("f6e8be"))
	controls.add_child(player_label); controls.add_child(enemy_label); controls.add_child(timer_label)
	var player_bg := _rect(Color("251d22"), Rect2(54, 64, 480, 24))
	var enemy_bg := _rect(Color("17282c"), Rect2(746, 64, 480, 24))
	controls.add_child(player_bg); controls.add_child(enemy_bg)
	player_bar = _rect(Color("f4ad52"), Rect2(58, 68, 472, 16))
	enemy_bar = _rect(Color("62d9dc"), Rect2(750, 68, 472, 16))
	controls.add_child(player_bar); controls.add_child(enemy_bar)
	var hint := _label("A / D 이동    W 점프    J 약공격    K 강공격    L 필살기", Vector2(360, 670), 16, Color("c0d6d2"))
	controls.add_child(hint)
	var tag := _label("1P", Vector2(54, 96), 14, Color("e7c18a"))
	var tag2 := _label("CPU", Vector2(1176, 96), 14, Color("89dadd"))
	controls.add_child(tag); controls.add_child(tag2)

func _label(text_value: String, pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.add_theme_font_override("font", load("res://assets/Galmuri11.ttf"))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _rect(color: Color, rect: Rect2) -> ColorRect:
	var node := ColorRect.new()
	node.color = color
	node.position = rect.position
	node.size = rect.size
	return node

func _process(delta: float) -> void:
	if ended:
		return
	elapsed += delta
	message_timer = maxf(0.0, message_timer - delta)
	player_cooldown = maxf(0.0, player_cooldown - delta)
	enemy_cooldown = maxf(0.0, enemy_cooldown - delta)
	player_attack_lock = maxf(0.0, player_attack_lock - delta)
	enemy_attack_lock = maxf(0.0, enemy_attack_lock - delta)
	_update_player(delta)
	_update_enemy(delta)
	_update_actor_vertical(player, true, delta)
	_update_actor_vertical(enemy, false, delta)
	_update_hud()
	if message_timer <= 0.0:
		message = ""
	queue_redraw()

func _update_player(delta: float) -> void:
	if player_attack_lock > 0.0:
		return
	var axis := Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A): axis -= 1.0
	if Input.is_key_pressed(KEY_D): axis += 1.0
	axis = clampf(axis, -1.0, 1.0)
	if absf(axis) > 0.1:
		player.position.x = clampf(player.position.x + axis * 260.0 * delta, LEFT_LIMIT, RIGHT_LIMIT)
		player.facing = 1 if axis > 0.0 else -1
		player.set_action("walk")
	else:
		player.set_action("idle")
	if Input.is_key_pressed(KEY_J):
		_try_attack(player, true, false)
	if Input.is_key_pressed(KEY_K):
		_try_attack(player, false, false)
	if Input.is_key_pressed(KEY_L):
		_try_attack(player, false, true)

func _update_enemy(delta: float) -> void:
	if enemy_attack_lock > 0.0:
		return
	var distance := player.position.x - enemy.position.x
	if absf(distance) > 175.0:
		var axis := signf(distance)
		enemy.position.x = clampf(enemy.position.x + axis * 150.0 * delta, LEFT_LIMIT, RIGHT_LIMIT)
		enemy.facing = 1 if axis > 0.0 else -1
		enemy.set_action("walk")
	elif enemy_cooldown <= 0.0:
		_try_attack(enemy, false, false)
	else:
		enemy.set_action("idle")

func _update_actor_vertical(actor: Node2D, is_player: bool, delta: float) -> void:
	var velocity := player_y_velocity if is_player else enemy_y_velocity
	if (is_player and Input.is_key_pressed(KEY_W) and is_zero_approx(velocity)) or (not is_player and is_zero_approx(velocity) and randf() < delta * 0.08):
		velocity = -520.0
	velocity += 1250.0 * delta
	actor.position.y += velocity * delta
	if actor.position.y >= GROUND_Y:
		actor.position.y = GROUND_Y
		velocity = 0.0
	if is_player:
		player_y_velocity = velocity
	else:
		enemy_y_velocity = velocity

func _try_attack(attacker: Node2D, light: bool, special: bool) -> void:
	var is_player := attacker == player
	var cooldown := player_cooldown if is_player else enemy_cooldown
	if cooldown > 0.0 or (special and (player_meter if is_player else enemy_meter) < 100.0):
		return
	var distance := absf(player.position.x - enemy.position.x)
	var reach := 155.0 if light else 205.0
	if special: reach = 240.0
	var defender := enemy if is_player else player
	var toward := signf(defender.position.x - attacker.position.x)
	attacker.facing = 1 if toward >= 0.0 else -1
	attacker.set_action("attack", 0.34 if light else 0.46)
	if is_player: player_attack_lock = 0.34 if light else 0.46
	else: enemy_attack_lock = 0.34 if light else 0.46
	if distance <= reach:
		var damage := 8.0 + float(attacker.definition.get("dmg", 10.0)) * 0.32
		if not light: damage *= 1.55
		if special:
			damage *= 2.0
			if is_player: player_meter = 0.0
			else: enemy_meter = 0.0
		defender.receive_hit()
		if is_player:
			enemy_hp = maxf(0.0, enemy_hp - damage)
			enemy.position.x = clampf(enemy.position.x + attacker.facing * 24.0, LEFT_LIMIT, RIGHT_LIMIT)
		else:
			player_hp = maxf(0.0, player_hp - damage)
			player.position.x = clampf(player.position.x + attacker.facing * 24.0, LEFT_LIMIT, RIGHT_LIMIT)
		if is_player: player_meter = minf(100.0, player_meter + 18.0)
		else: enemy_meter = minf(100.0, enemy_meter + 15.0)
		message = "CRITICAL" if special else ("HIT" if light else "BREAK")
		message_timer = 0.22
	if is_player: player_cooldown = 0.26 if light else 0.52
	else: enemy_cooldown = 0.72
	_check_end()

func _check_end() -> void:
	if player_hp <= 0.0 or enemy_hp <= 0.0:
		ended = true
		winner = 0 if enemy_hp <= 0.0 else 1
		message = "YOU WIN" if winner == 0 else "YOU LOSE"
		message_timer = 99.0
		if winner == 0: player.set_action("idle")

func _update_hud() -> void:
	player_bar.size.x = 472.0 * clampf(player_hp / 100.0, 0.0, 1.0)
	enemy_bar.position.x = 750.0 + 472.0 * (1.0 - clampf(enemy_hp / 100.0, 0.0, 1.0))
	enemy_bar.size.x = 472.0 * clampf(enemy_hp / 100.0, 0.0, 1.0)
	timer_label.text = "%02d" % max(0, 99 - int(elapsed))

func _draw() -> void:
	# 격투장 배경: 캐릭터가 읽히는 큰 명암 덩어리와 두 색의 링 라이트.
	draw_rect(Rect2(0, 0, W, H), Color("080f16"))
	draw_rect(Rect2(0, 116, W, 350), Color("0d1e27"))
	draw_rect(Rect2(0, 466, W, 254), Color("101921"))
	draw_polygon(PackedVector2Array([Vector2(0,466),Vector2(1280,466),Vector2(1090,720),Vector2(190,720)]), PackedColorArray([Color("182b31")]))
	for x in range(0, 1281, 80):
		draw_line(Vector2(640, 466), Vector2(x, 720), Color(0.24, 0.50, 0.50, 0.16), 2.0)
	for y in range(500, 721, 44):
		draw_line(Vector2(0, y), Vector2(W, y), Color(0.17, 0.34, 0.37, 0.20), 2.0)
	# 중앙 링과 양쪽 캐릭터 스폰 스탬프.
	draw_line(Vector2(64, GROUND_Y + 6), Vector2(1216, GROUND_Y + 6), Color("d99c50"), 4.0)
	draw_line(Vector2(64, GROUND_Y + 12), Vector2(1216, GROUND_Y + 12), Color(0.22, 0.65, 0.63, 0.50), 2.0)
	draw_circle(Vector2(640, GROUND_Y), 104.0, Color(0.19, 0.51, 0.52, 0.08))
	draw_arc(Vector2(640, GROUND_Y), 104.0, PI, TAU, 32, Color("62d9dc"), 3.0)
	draw_arc(Vector2(640, GROUND_Y), 104.0, 0, PI, 32, Color("f4ad52"), 3.0)
	for pos in [Vector2(90, 170), Vector2(1190, 170), Vector2(640, 170)]:
		draw_rect(Rect2(pos - Vector2(3, 3), Vector2(6, 6)), Color("e7a653"))
		draw_rect(Rect2(pos + Vector2(12, 0), Vector2(28, 3)), Color(0.50, 0.78, 0.72, 0.45))
	if message != "":
		draw_string(load("res://assets/Galmuri11.ttf"), Vector2(0, 290), message, HORIZONTAL_ALIGNMENT_CENTER, W, 52, Color("f6e8be"))
