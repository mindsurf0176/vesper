extends Node
## 시스템 셸 회귀 테스트. 설정/공지/가이드/약관/크레딧 계약이 저장 상태를 일관되게 바꾸는지 검증한다.

func _ready() -> void:
	GameState.test_mode_no_save = true
	GameState.new_game()

	assert(GameState.terms_needed(), "새 게임은 로컬 테스트 약관 확인이 필요해야 함")
	var terms := GameState.accept_terms()
	assert(bool(terms.get("ok", false)), "약관 확인은 성공해야 함")
	assert(not GameState.terms_needed(), "약관 확인 후에는 재확인이 필요 없어야 함")

	var settings := GameState.settings_copy()
	assert(float(settings.get("master_volume", 0.0)) == 1.0, "기본 마스터 볼륨은 100%여야 함")
	var vol := GameState.cycle_volume_setting("master_volume")
	assert(bool(vol.get("ok", false)), "볼륨 순환은 성공해야 함")
	assert(float(GameState.settings_copy().get("master_volume", 1.0)) < 1.0, "볼륨 순환은 값을 바꿔야 함")
	var vibration_before := bool(GameState.settings_copy().get("vibration", true))
	var vib := GameState.toggle_setting("vibration")
	assert(bool(vib.get("ok", false)), "불리언 설정 토글은 성공해야 함")
	assert(bool(GameState.settings_copy().get("vibration", true)) != vibration_before, "진동 설정은 반전되어야 함")
	var bad := GameState.set_setting("missing_setting", true)
	assert(not bool(bad.get("ok", true)), "없는 설정은 거부해야 함")
	GameState.reset_settings()
	assert(float(GameState.settings_copy().get("master_volume", 0.0)) == 1.0, "설정 초기화는 기본값을 복원해야 함")

	assert(GameState.unread_notice_count() == GameState.NOTICE_FEED.size(), "새 게임은 모든 공지가 읽지 않음이어야 함")
	var first_notice := str(GameState.NOTICE_FEED[0].get("id", ""))
	var read_one := GameState.mark_notice_read(first_notice)
	assert(bool(read_one.get("ok", false)), "공지 읽음 처리는 성공해야 함")
	assert(GameState.unread_notice_count() == GameState.NOTICE_FEED.size() - 1, "공지 읽음 수가 감소해야 함")
	GameState.mark_all_notices_read()
	assert(GameState.unread_notice_count() == 0, "전체 읽음 후 읽지 않은 공지가 없어야 함")

	var topics := GameState.tutorial_topics()
	assert(not topics.is_empty(), "가이드 항목이 있어야 함")
	var first_topic := str(topics[0].get("id", ""))
	var viewed := GameState.mark_tutorial_viewed(first_topic)
	assert(bool(viewed.get("ok", false)), "가이드 확인 처리는 성공해야 함")
	assert(GameState.tutorial_viewed(first_topic), "가이드 확인 상태가 저장되어야 함")
	assert(GameState.credits_list().size() >= 3, "크레딧 항목이 있어야 함")

	GameState.test_mode_no_save = false
	print("PASS system_shell settings notice guide terms credits")
	get_tree().quit()
