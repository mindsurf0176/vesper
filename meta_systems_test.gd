extends Node
## 모바일 메타 시스템 회귀 테스트. 뽑기/상점/출석/채팅이 저장 상태를 일관되게 바꾸는지 검증한다.

func _ready() -> void:
	GameState.test_mode_no_save = true
	GameState.new_game()
	seed(4242)

	assert(GameState.lumen == 600, "새 게임은 기본 루멘을 지급해야 함")
	assert(GameState.recruit_tickets == 3, "새 게임은 기본 모집권을 지급해야 함")
	assert(not GameState.gacha_rates_text().is_empty(), "모집 확률 안내가 있어야 함")

	var daily := GameState.claim_daily_reward()
	assert(bool(daily.get("ok", false)), "첫 출석 보상은 수령되어야 함")
	var daily_again := GameState.claim_daily_reward()
	assert(not bool(daily_again.get("ok", true)), "같은 날 출석 보상은 중복 수령되면 안 됨")

	GameState.recruit_tickets = 10
	var ten := GameState.draw_gacha(10)
	assert(bool(ten.get("ok", false)), "10회 모집은 성공해야 함")
	assert(ten.get("results", []).size() == 10, "10회 모집 결과는 10개여야 함")
	var has_sr := false
	for item in ten.get("results", []):
		if GameState._rarity_rank(str(item.get("rarity", "R"))) >= GameState._rarity_rank("SR"):
			has_sr = true
	assert(has_sr, "10회 모집은 SR 이상을 보장해야 함")
	assert(GameState.gacha_history.size() >= 10, "모집 기록이 남아야 함")

	GameState.recruit_tickets = 0
	GameState.lumen = 200
	GameState.gacha_pity = GameState.GACHA_PITY_LIMIT - 1
	var pity := GameState.draw_gacha(1)
	assert(bool(pity.get("ok", false)), "천장 직전 1회 모집은 성공해야 함")
	assert(str(pity["results"][0].get("rarity", "")) == "SSR", "천장은 SSR을 보장해야 함")
	assert(GameState.gacha_pity == 0, "SSR 획득 후 천장 카운트는 초기화되어야 함")

	var before_lumen: int = GameState.lumen
	var starter := GameState.buy_shop_pack("starter")
	assert(bool(starter.get("ok", false)), "초회 등불 보급은 1회 구매 가능해야 함")
	assert(GameState.lumen > before_lumen, "상점 구매는 재화를 지급해야 함")
	var starter_again := GameState.buy_shop_pack("starter")
	assert(not bool(starter_again.get("ok", true)), "초회 상품은 중복 구매되면 안 됨")
	var ad := GameState.buy_shop_pack("ad_supply")
	assert(bool(ad.get("ok", false)), "광고 보급 목업은 구매 가능해야 함")
	assert(not GameState.monetization_events.is_empty(), "수익 이벤트 로그가 남아야 함")

	var empty_chat := GameState.send_chat_message("")
	assert(not bool(empty_chat.get("ok", true)), "빈 채팅은 막아야 함")
	var chat := GameState.send_chat_message("회랑 진입 준비 완료")
	assert(bool(chat.get("ok", false)), "정상 채팅은 전송되어야 함")
	assert(str(GameState.chat_list()[-1].get("text", "")) == "회랑 진입 준비 완료", "채팅 로그가 저장되어야 함")

	GameState.test_mode_no_save = false
	print("PASS meta_systems gacha shop chat")
	get_tree().quit()
