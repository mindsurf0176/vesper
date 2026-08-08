extends Node
## 캠페인 진행 회귀 테스트. 저장 파일을 건드리지 않고 해금/기록/엔딩 후 변종 루프를 검증한다.

func _ready() -> void:
	GameState.test_mode_no_save = true
	GameState.new_game()

	assert(GameState.current_stage == 0, "새 게임은 첫 스테이지에서 시작해야 함")
	assert(GameState.unlocked == GameState.START_UNLOCKED, "새 게임 기본 해금 명단이 일치해야 함")
	assert(GameState.run_records.is_empty(), "새 게임 기록은 비어 있어야 함")

	for i in GameState.STAGES.size():
		GameState.current_stage = i
		var st: Dictionary = GameState.current_stage_def()
		GameState.on_battle_end(true)
		assert(GameState.cleared.has(st["id"]), "승리한 스테이지는 클리어 목록에 기록되어야 함")
		var reward: String = st.get("unlock", "")
		if reward != "":
			assert(GameState.unlocked.has(reward), "스테이지 보상 캐릭터가 해금되어야 함")
		assert(not GameState.run_records.is_empty(), "전투 결과 기록이 남아야 함")
		var rec: Dictionary = GameState.run_records[GameState.run_records.size() - 1]
		assert(rec.get("stage_id", "") == st["id"], "최근 결과 기록은 방금 끝난 스테이지여야 함")

	assert(GameState.all_cleared(), "5개 스테이지를 모두 깨면 완주 상태여야 함")
	assert(GameState.stage_open(GameState.STAGES.size()), "완주 뒤 변종 도전이 열려야 함")

	GameState.current_stage = GameState.STAGES.size()
	var loop0: Dictionary = GameState.current_stage_def()
	assert(str(loop0.get("id", "")).begins_with("loop_"), "완주 뒤 현재 스테이지는 변종 회랑이어야 함")
	var seed_before: int = GameState.challenge_seed
	GameState.on_battle_end(true)
	assert(GameState.challenge_seed == seed_before + 1, "변종 승리는 다음 변종 시드를 열어야 함")
	assert(GameState.run_records.size() <= 20, "최근 결과 기록은 최대 20개로 제한되어야 함")

	GameState.test_mode_no_save = false
	print("PASS campaign_flow progression")
	get_tree().quit()
