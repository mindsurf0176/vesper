extends Node
## 전장 비주얼 계약 회귀 테스트. 플레이스홀더도 캐릭터/적별 표시 계약을 가져야 한다.

func _ready() -> void:
	GameState.test_mode_no_save = true
	GameState.new_game()

	for c in GameState.all_chars_list():
		assert(c.has("visual"), "%s 전장 비주얼 계약 누락" % str(c.get("name", "")))
		var v: Dictionary = c.get("visual", {})
		assert(v.has("shape") and v.has("primary") and v.has("accent"), "%s visual 필수 필드 누락" % str(c.get("name", "")))

	for enemy_id in GameState.ENEMY_DEFS.keys():
		var e: Dictionary = GameState.ENEMY_DEFS[enemy_id]
		var ev := GameState.battle_visual_for(str(e.get("name", "")), int(e.get("type", GameState.STRIKER)), true)
		assert(ev.has("shape") and bool(ev.get("enemy", false)), "%s 적 비주얼 계약 누락" % enemy_id)

	var battle = load("res://battle3d.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	battle.simulation_mode = true
	battle._spawn(battle.EDEF["rusher"], battle.ENEMY)
	var enemy = battle.units[-1]
	assert(enemy.visual_contract_applied, "스폰된 적은 비주얼 계약 레이어가 적용되어야 함")
	assert(enemy.hp_fill != null and enemy.hp_back != null, "스폰된 유닛은 HP바를 가져야 함")
	enemy.take_damage(10.0, 1.0)
	assert(enemy.hp_fill.visible, "피해를 입은 유닛은 HP바가 보여야 함")
	battle.queue_free()

	GameState.test_mode_no_save = false
	print("PASS battlefield_visual contracts layers")
	get_tree().quit()
