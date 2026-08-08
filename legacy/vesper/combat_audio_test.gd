extends Node
## 전투 이벤트 사운드 매핑 회귀 테스트. 실제 출력 대신 로그/쿨다운/시뮬레이션 게이트를 검증한다.

func _ready() -> void:
	GameState.test_mode_no_save = true
	GameState.new_game()
	GameState.set_setting("sfx_volume", 0.0)
	GameState.feedback_log = []

	var battle = load("res://battle3d.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame

	assert(battle._combat_audio("deploy", { "unit": "테스트" }, 0.5), "첫 배치 사운드는 발생해야 함")
	assert(str(GameState.feedback_log[-1].get("id", "")) == "deploy", "배치 사운드 id가 기록되어야 함")
	var log_size := GameState.feedback_log.size()
	assert(not battle._combat_audio("deploy", { "unit": "테스트" }, 0.5), "쿨다운 중 같은 이벤트는 막아야 함")
	assert(GameState.feedback_log.size() == log_size, "쿨다운 차단 이벤트는 로그를 늘리면 안 됨")
	battle._tick_combat_audio(0.6)
	assert(battle._combat_audio("deploy", { "unit": "테스트" }, 0.5), "쿨다운 이후 같은 이벤트는 다시 발생해야 함")

	assert(battle._attack_audio_event("heal") == "combat_heal", "치유 공격은 치유 사운드로 매핑되어야 함")
	assert(battle._attack_audio_event("sniper") == "attack_ranged", "스나이퍼는 원거리 사운드로 매핑되어야 함")
	assert(battle._attack_audio_event("shield") == "attack_guard", "방패 계열은 방패 타격 사운드로 매핑되어야 함")
	assert(battle._attack_audio_event("blade") == "attack_melee", "검격 계열은 근접 타격 사운드로 매핑되어야 함")

	battle.simulation_mode = true
	log_size = GameState.feedback_log.size()
	assert(not battle._combat_audio("attack_melee", {}, 0.1), "시뮬레이션 모드는 전투 사운드를 발생시키면 안 됨")
	assert(GameState.feedback_log.size() == log_size, "시뮬레이션 모드 사운드는 로그를 남기면 안 됨")
	battle.queue_free()

	GameState.test_mode_no_save = false
	print("PASS combat_audio event mapping cooldown")
	get_tree().quit()
