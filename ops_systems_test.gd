extends Node
## 운영/성장 시스템 회귀 테스트. 우편/미션/계정/성장/패스가 서로 연결되는지 검증한다.

func _ready() -> void:
	GameState.test_mode_no_save = true
	GameState.new_game()
	seed(7331)

	assert(GameState.mail_list().size() >= 3, "새 게임은 기본 우편을 시드해야 함")
	var before_mail_lumen := GameState.lumen
	var mail := GameState.claim_all_mail()
	assert(bool(mail.get("ok", false)), "전체 우편 수령은 성공해야 함")
	assert(GameState.lumen > before_mail_lumen, "우편은 재화를 지급해야 함")
	var mail_again := GameState.claim_all_mail()
	assert(not bool(mail_again.get("ok", true)), "우편은 중복 수령되면 안 됨")

	var daily := GameState.claim_daily_reward()
	assert(bool(daily.get("ok", false)), "출석은 미션 진행도를 올리기 위해 성공해야 함")
	var daily_mission := GameState.claim_mission("daily_login")
	assert(bool(daily_mission.get("ok", false)), "출석 미션은 수령되어야 함")
	var daily_again := GameState.claim_mission("daily_login")
	assert(not bool(daily_again.get("ok", true)), "같은 일일 미션은 하루에 중복 수령되면 안 됨")

	GameState.recruit_tickets = 1
	var pull := GameState.draw_gacha(1)
	assert(bool(pull.get("ok", false)), "모집은 미션 진행도를 올려야 함")
	var recruit_mission := GameState.claim_mission("daily_recruit")
	assert(bool(recruit_mission.get("ok", false)), "모집 미션은 수령되어야 함")

	var chat := GameState.send_chat_message("운영 시스템 테스트")
	assert(bool(chat.get("ok", false)), "채팅은 미션 진행도를 올려야 함")
	var chat_mission := GameState.claim_mission("daily_chat")
	assert(bool(chat_mission.get("ok", false)), "채팅 미션은 수령되어야 함")

	var before_level := GameState.character_level("진혼병")
	GameState.account_xp = 0
	var before_gold := GameState.gold
	var upgrade := GameState.upgrade_character("진혼병")
	assert(bool(upgrade.get("ok", false)), "캐릭터 레벨업은 성공해야 함")
	assert(GameState.character_level("진혼병") == before_level + 1, "캐릭터 레벨이 올라야 함")
	assert(GameState.gold < before_gold, "레벨업은 골드를 소모해야 함")
	var growth_mission := GameState.claim_mission("achieve_growth")
	assert(bool(growth_mission.get("ok", false)), "성장 업적은 수령되어야 함")

	var shop := GameState.buy_shop_pack("ad_supply")
	assert(bool(shop.get("ok", false)), "상점/광고 목업은 미션 진행도를 올려야 함")
	var shop_mission := GameState.claim_mission("achieve_shop")
	assert(bool(shop_mission.get("ok", false)), "보급선 업적은 수령되어야 함")

	var before_pass_xp := GameState.battle_pass_xp
	GameState.on_battle_end(true)
	assert(GameState.battle_pass_xp > before_pass_xp, "전투 결과는 패스 XP를 지급해야 함")
	assert(GameState.account_level >= 1, "전투 결과는 계정 진행도를 유지/상승시켜야 함")
	var battle_mission := GameState.claim_mission("daily_battle")
	assert(bool(battle_mission.get("ok", false)), "출격 미션은 수령되어야 함")
	var first_clear := GameState.claim_mission("achieve_first_clear")
	assert(bool(first_clear.get("ok", false)), "첫 클리어 업적은 수령되어야 함")

	var pass_reward := GameState.claim_battle_pass(1)
	assert(bool(pass_reward.get("ok", false)), "도달한 패스 보상은 수령되어야 함")
	var pass_again := GameState.claim_battle_pass(1)
	assert(not bool(pass_again.get("ok", true)), "패스 보상은 중복 수령되면 안 됨")

	GameState.test_mode_no_save = false
	print("PASS ops_systems mail missions growth battlepass")
	get_tree().quit()
