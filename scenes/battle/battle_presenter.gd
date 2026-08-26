class_name BattlePresenter
extends SubViewportContainer

## CombatSim의 snapshot/event만 소비하는 Vesper HD-2D presentation bridge.

const STAGE_SCRIPT := preload("res://scenes/battle/battle_stage_3d.gd")
const ACTOR_SCRIPT := preload("res://scenes/battle/battle_actor_3d.gd")
const WORLD_LEFT := BattleStage3D.ALLY_X + 0.85
const WORLD_RIGHT := BattleStage3D.ENEMY_X - 0.85
const LANE_STEP := 0.12
const EDGE_SCROLL_ZONE := 110.0
const EDGE_SCROLL_SPEED := 0.36

var sim: CombatSim = null
var label_left := "아군"
var label_right := "상대"
var playback_speed := 1.0
var field_scroll := 0.5
var font: Font

var _viewport: SubViewport
var _stage: BattleStage3D
var _actors: Dictionary = {}
var _retiring: Dictionary = {}
var _event_sim: CombatSim = null
var _ability_calls: Array = []
var _hud_layer: Control


func _ready() -> void:
	stretch = false
	_build_viewport()
	_build_hud()
	_sync_viewport_size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_viewport_size()


func _sync_viewport_size() -> void:
	if _viewport == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_viewport.size = Vector2i(ceili(size.x), ceili(size.y))


func bind_sim(value: CombatSim) -> void:
	reset_presentation()
	sim = value
	_event_sim = value
	if sim != null:
		_sync_actors(sim.snapshot(), true)
	queue_redraw()


func reset_presentation() -> void:
	for actor in _actors.values():
		(actor as BattleActor3D).queue_free()
	for actor in _retiring.values():
		(actor as BattleActor3D).queue_free()
	_actors.clear()
	_retiring.clear()
	_ability_calls.clear()
	sim = null
	_event_sim = null


func set_playback_speed(value: float) -> void:
	playback_speed = maxf(value, 0.1)
	if _stage != null:
		_stage.set_playback_speed(playback_speed)
	for actor in _actors.values():
		(actor as BattleActor3D).set_playback_speed(playback_speed)


func set_field_scroll(value: float) -> void:
	field_scroll = clampf(value, 0.0, 1.0)
	if _stage != null:
		_stage.set_field_scroll(field_scroll)
	for actor in _retiring.values():
		(actor as BattleActor3D).set_playback_speed(playback_speed)


func show_victory(winner: int) -> void:
	for actor in _actors.values():
		var battle_actor := actor as BattleActor3D
		if battle_actor.team == winner:
			battle_actor.play_victory()


func actor_for_test(uid: int) -> BattleActor3D:
	return _actor_for(uid)


func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "BattleViewport"
	_viewport.size = Vector2i(1, 1)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	add_child(_viewport)
	_stage = STAGE_SCRIPT.new() as BattleStage3D
	_stage.name = "Stage"
	_viewport.add_child(_stage)
	set_playback_speed(playback_speed)
	_stage.set_field_scroll(field_scroll)


func _build_hud() -> void:
	_hud_layer = Control.new()
	_hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_hud_layer)


func _process(delta: float) -> void:
	_update_edge_scroll(delta)
	if sim == null:
		_stage.set_core_state([Defs.CORE_HP, Defs.CORE_HP], Defs.CORE_HP)
		queue_redraw()
		return
	if sim != _event_sim:
		bind_sim(sim)
	var states := sim.snapshot()
	_sync_actors(states, false)
	_consume_events()
	_reconcile_actor_lifetimes(states)
	_cleanup_retiring()
	_stage.set_core_state(sim.core_hp, Defs.CORE_HP)
	var now := Time.get_ticks_msec() / 1000.0
	_ability_calls = _ability_calls.filter(func(call): return float(call["until"]) >= now)
	queue_redraw()


func _update_edge_scroll(delta: float) -> void:
	if sim == null or size.x <= 0.0:
		return
	var pointer := get_local_mouse_position()
	if pointer.y < 0.0 or pointer.y > size.y or pointer.x < 0.0 or pointer.x > size.x:
		return
	var direction := 0.0
	if pointer.x <= EDGE_SCROLL_ZONE:
		direction = -1.0
	elif pointer.x >= size.x - EDGE_SCROLL_ZONE:
		direction = 1.0
	if is_zero_approx(direction):
		return
	set_field_scroll(field_scroll + direction * EDGE_SCROLL_SPEED * delta)


func _sync_actors(states: Array, snap: bool) -> void:
	for state in states:
		var uid := int(state["uid"])
		if not bool(state["deployed"]) and not _actors.has(uid):
			continue
		if not _actors.has(uid) and not _retiring.has(uid) and bool(state["alive"]):
			_spawn_actor(state)
		var actor := _actors.get(uid) as BattleActor3D
		if actor != null:
			actor.apply_snapshot(state, _actor_position(state), snap)


func _reconcile_actor_lifetimes(states: Array) -> void:
	for state in states:
		if bool(state["deployed"]) and not bool(state["alive"]):
			_begin_retirement(int(state["uid"]))


func _begin_retirement(uid: int) -> BattleActor3D:
	if _retiring.has(uid):
		return _retiring[uid] as BattleActor3D
	var actor := _actors.get(uid) as BattleActor3D
	if actor == null:
		return null
	_actors.erase(uid)
	_retiring[uid] = actor
	actor.play_death()
	return actor


func _spawn_actor(state: Dictionary) -> void:
	var actor := ACTOR_SCRIPT.new() as BattleActor3D
	_stage.actors_root.add_child(actor)
	actor.setup(state, _actor_position(state))
	actor.set_playback_speed(playback_speed)
	_actors[int(state["uid"])] = actor


func _consume_events() -> void:
	for event in sim.consume_events():
		var kind := String(event.get("t", ""))
		match kind:
			"command_hit":
				var target := _active_actor(int(event["to"]))
				if target != null:
					target.play_hit()
					_stage.impact_fx(target.hit_socket_global(), Color("f4ad52"), true)
			"deploy":
				var deployed := _active_actor(int(event["uid"]))
				if deployed != null:
					deployed.play_deploy()
					_stage.deploy_fx(deployed.position, _element_color(deployed.element))
			"hit":
				var attacker := _active_actor(int(event["from"]))
				var target := _active_actor(int(event["to"]))
				if attacker != null:
					attacker.play_attack()
				if target != null:
					target.play_hit()
				if attacker != null and target != null:
					var color := _element_color(attacker.element)
					_stage.attack_fx(attacker.attack_socket_global(), target.hit_socket_global(), color,
						attacker.role == Defs.Role.RANGER or attacker.role == Defs.Role.SUPPORT)
					_stage.impact_fx(target.hit_socket_global(), color, float(event.get("dmg", 0.0)) >= 80.0)
			"ability":
				var caster := _active_actor(int(event["uid"]))
				if caster != null:
					caster.play_skill(String(event.get("name", "")))
					_stage.ability_fx(caster.position, _element_color(caster.element))
					_ability_calls.append({
						"name": String(event.get("name", "")),
						"def_id": caster.def_id,
						"until": Time.get_ticks_msec() / 1000.0 + 0.9 / maxf(playback_speed, 1.0),
					})
			"death":
				var uid := int(event["uid"])
				var was_active := _actors.has(uid)
				var dying := _begin_retirement(uid)
				if dying != null and was_active:
					_stage.death_fx(dying.hit_socket_global(), _element_color(dying.element))
			"core":
				_stage.core_impact(int(event["team"]))


func _cleanup_retiring() -> void:
	for uid in _retiring.keys():
		var actor := _retiring[uid] as BattleActor3D
		if actor == null or actor.can_remove():
			if actor != null:
				actor.queue_free()
			_retiring.erase(uid)


func _active_actor(uid: int) -> BattleActor3D:
	return _actors.get(uid) as BattleActor3D


func _actor_for(uid: int) -> BattleActor3D:
	var actor := _active_actor(uid)
	if actor != null:
		return actor
	return _retiring.get(uid) as BattleActor3D


func active_actor_count_for_test() -> int:
	return _actors.size()


func retiring_actor_count_for_test() -> int:
	return _retiring.size()


func _actor_position(state: Dictionary) -> Vector3:
	var world_x := lerpf(WORLD_LEFT, WORLD_RIGHT, clampf(float(state["x"]) / Defs.FIELD_LEN, 0.0, 1.0))
	var lane := int(state["order"]) % 5
	var lane_z := float(lane - 2) * LANE_STEP + (0.035 if int(state["team"]) == 1 else 0.0)
	return Vector3(world_x, 0, lane_z)


func _draw() -> void:
	if sim == null:
		return
	_draw_battle_hud()
	_draw_ability_banner()


func _draw_battle_hud() -> void:
	var width := size.x
	var height := size.y
	for team in 2:
		var ratio := clampf(float(sim.cost[team]) / Defs.MAX_COST, 0.0, 1.0)
		var bar_width := 220.0
		var x := 24.0 if team == 0 else width - bar_width - 24.0
		var y := height - 38.0
		draw_rect(Rect2(x, y, bar_width, 16), Color(0.02, 0.04, 0.05, 0.84))
		draw_rect(Rect2(x, y, bar_width * ratio, 16), BattleStage3D.TEAM_COLOR[team] * Color(1, 1, 1, 0.75))
		draw_rect(Rect2(x, y, bar_width, 16), Color("71868c"), false, 1.0)
		var name := label_left if team == 0 else label_right
		_text(Vector2(x, y - 7), "%s  항성 기운 %.1f" % [name, sim.cost[team]], Color("e8efeb"), 12)
	var panel := Rect2(width * 0.5 - 90, 14, 180, 28)
	draw_rect(panel, Color(0.02, 0.04, 0.05, 0.80))
	draw_rect(panel, Color("597177"), false, 1.0)
	_text(panel.position + Vector2(22, 20), "%.1fs / %ds" % [sim.time, int(Defs.MAX_BATTLE_TIME)], Color("e8efeb"), 13)
	var danger := 1.0 - clampf(float(sim.core_hp[0]) / float(Defs.CORE_HP), 0.0, 1.0)
	if danger >= 0.70:
		var danger_panel := Rect2(width * 0.5 - 118, height - 78, 236, 28)
		draw_rect(danger_panel, Color(0.38, 0.08, 0.10, 0.92))
		draw_rect(danger_panel, Color("ef8354"), false, 2.0)
		_text(danger_panel.position + Vector2(42, 19), "등불함 위험 — 소신을 고려하세요", Color("fff2d2"), 12)
	elif sim.core_hp[1] <= Defs.CORE_HP * 0.25:
		var finish_panel := Rect2(width * 0.5 - 104, height - 78, 208, 28)
		draw_rect(finish_panel, Color(0.10, 0.28, 0.26, 0.92))
		draw_rect(finish_panel, Color("7cc5cf"), false, 2.0)
		_text(finish_panel.position + Vector2(35, 19), "적 매듭이 무너지고 있습니다", Color("d9fff1"), 12)


func _draw_ability_banner() -> void:
	if _ability_calls.is_empty():
		return
	var call: Dictionary = _ability_calls[_ability_calls.size() - 1]
	var unit := UnitDB.get_def(String(call["def_id"]))
	var color := _element_color(int(unit["element"]))
	var rect := Rect2(size.x * 0.5 - 160, 50, 320, 42)
	draw_rect(rect, Color(0.02, 0.04, 0.05, 0.88))
	draw_rect(rect, color, false, 2.0)
	_text(rect.position + Vector2(18, 27), "%s  ·  %s" % [unit["name"], call["name"]], Color("fff2d2"), 15)


func _element_color(element: int) -> Color:
	return [Color("ef8354"), Color("b8a56b"), Color("7cc5cf"), Color("5d8db7")][element]


func _text(position: Vector2, text: String, color: Color, size_px: int) -> void:
	var used_font := font if font != null else ThemeDB.fallback_font
	draw_string(used_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
