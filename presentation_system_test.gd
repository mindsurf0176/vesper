extends Node
## 전환/효과음/전투 결과 연출 계약 회귀 테스트.

func _ready() -> void:
	GameState.test_mode_no_save = true
	GameState.new_game()
	GameState.set_setting("sfx_volume", 0.0)

	var direct := GameState.emit_feedback("ui_confirm", { "test": true })
	assert(bool(direct.get("ok", false)), "피드백 이벤트는 성공해야 함")
	assert(not GameState.feedback_log.is_empty(), "피드백 로그가 남아야 함")
	assert(str(GameState.feedback_log[-1].get("id", "")) == "ui_confirm", "피드백 id가 기록되어야 함")

	var summary := GameState.compose_battle_feedback(true, {
		"elapsed": 32.0,
		"soshin": 0,
		"burned": 0,
		"ally_hp": 1000.0,
		"ally_hp_max": 1000.0,
		"cause": "테스트 승리",
	})
	assert(str(summary.get("grade", "")) == "S", "무소신 고생존 빠른 승리는 S 평가여야 함")
	assert(str(summary.get("xp_line", "")).contains("계정 XP"), "결과 요약은 XP 라인을 포함해야 함")

	GameState.on_battle_end(true, {
		"elapsed": 50.0,
		"soshin": 1,
		"burned": 1,
		"ally_hp": 850.0,
		"ally_hp_max": 1000.0,
		"cause": "회랑 돌파",
	})
	assert(not GameState.last_battle_feedback.is_empty(), "전투 종료는 마지막 결과 피드백을 저장해야 함")
	assert(GameState.run_records[-1].has("grade"), "전투 기록은 평가 등급을 포함해야 함")
	assert(str(GameState.feedback_log[-1].get("id", "")) == "battle_win", "전투 종료는 승리 피드백을 발생시켜야 함")

	var loss_summary := GameState.compose_battle_feedback(false, {
		"elapsed": 80.0,
		"soshin": 5,
		"burned": 5,
		"ally_hp": 0.0,
		"ally_hp_max": 1000.0,
		"cause": "과한 소신",
	})
	assert(str(loss_summary.get("grade", "")) == "D", "패배는 D 평가여야 함")
	assert(str(loss_summary.get("lines", [])[1]).contains("과한 소신"), "패배 요약은 패인을 포함해야 함")

	GameState.test_mode_no_save = false
	print("PASS presentation_system feedback transition result")
	get_tree().quit()
