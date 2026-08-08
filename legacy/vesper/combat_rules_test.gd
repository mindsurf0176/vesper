extends Node
## 핵심 전투 규칙 회귀 테스트. 사용: godot --headless --path . res://combat_rules_test.tscn

func _ready() -> void:
	GameState.squad = []
	GameState.current_stage = 0
	var battle = load("res://battle3d.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame

	assert(GameState.SQUAD_MAX == 8, "스쿼드 편성 상한은 8명이어야 함")
	assert(battle.DECK.size() >= 8, "전체 전투 덱은 최소 8명 계약을 만족해야 함")
	assert(battle.type_mult(battle.STRIKER, battle.RANGER) > 1.0, "스트라이커는 레인저에게 유리해야 함")
	assert(battle.type_mult(battle.RANGER, battle.DEFENDER) > 1.0, "레인저는 디펜더에게 유리해야 함")
	assert(battle.type_mult(battle.DEFENDER, battle.SNIPER) > 1.0, "디펜더는 스나이퍼에게 유리해야 함")
	assert(battle.type_mult(battle.SNIPER, battle.STRIKER) > 1.0, "스나이퍼는 스트라이커에게 유리해야 함")
	assert(battle.card_btns.size() == battle.HAND_SIZE, "전투 UI는 4장 손패만 노출해야 함")
	assert(battle.hand_indices == [0, 1, 2, 3], "초기 손패는 덱 앞 4장이어야 함")
	assert(bool(battle.DECK[0].get("leader", false)), "첫 편성 캐릭터는 리더로 지정되어야 함")
	assert(is_equal_approx(battle._card_cost(battle.DECK[0]), max(1.0, float(battle.DECK[0]["cost"]) - battle.leader_cost_discount)), "리더는 함선 계약의 비용 감소를 받아야 함")
	assert(battle.deployment_max_x() > battle.deployment_min_x(), "초기 배치 영역은 코어 앞에 열려 있어야 함")
	var first_card_idx: int = int(battle.hand_indices[0])
	var first_deploy_x: float = battle.deployment_max_x()
	battle.cost = 10.0
	var cost_before_leader: float = battle.cost
	var first_cost: float = battle._card_cost(battle.DECK[first_card_idx])
	battle._on_card(0)
	assert(battle.pending_card_slot == 0, "카드 클릭은 즉시 소환이 아니라 배치 위치 선택 상태로 들어가야 함")
	assert(battle.ally_count() == 0, "위치를 찍기 전에는 유닛이 소환되면 안 됨")
	assert(battle._deploy_card_slot(0, first_deploy_x), "선택한 손패 카드를 지정 좌표에 배치할 수 있어야 함")
	assert(is_equal_approx(battle.cost, cost_before_leader - first_cost), "배치 코스트 차감은 리더 비용 감소를 반영해야 함")
	assert(battle.hand_indices[0] == 4, "카드를 쓰면 해당 손패 슬롯에 다음 덱 카드가 들어와야 함")
	assert(battle.card_cd[first_card_idx] > 0.0, "사용한 덱 카드의 재배치 쿨다운이 기록되어야 함")
	var first_unit = battle.units[0]
	assert(is_equal_approx(first_unit.position.x, first_deploy_x), "배치한 유닛은 지정한 배치 x좌표에 생성되어야 함")
	assert(first_unit.orb_skills.has("1") and first_unit.orb_skills.has("4"), "소환된 유닛은 캐릭터별 1/2/4오브 스킬 계약을 가져야 함")
	var expanded_max: float = battle.deployment_max_x()
	assert(expanded_max > first_deploy_x, "아군 최전선이 생기면 배치 가능 영역이 앞으로 확장되어야 함")
	assert(battle.command_orbs.size() == battle.ORB_COUNT, "오브 보드는 계약한 수만큼 생성되어야 함")
	assert(battle.orb_btns.size() == battle.ORB_COUNT, "오브 버튼은 오브 보드와 같은 수여야 함")

	battle._spawn(battle.EDEF["rusher"], battle.ENEMY)
	var enemy = battle.units[1]
	var enemy_hp_before: float = enemy.hp
	battle.command_orbs[0] = battle._make_orb(0, battle.STRIKER, battle.ORB_ENHANCED)
	battle._refresh_orb_buttons()
	battle._on_orb_button(0)
	assert(battle.selected_orbs == [0], "오브 클릭은 즉시 발동이 아니라 선택 상태를 만들어야 함")
	assert(is_equal_approx(enemy.hp, enemy_hp_before), "발동 전에는 오브 스킬 피해가 들어가면 안 됨")
	battle._on_orb_cast()
	assert(enemy.hp < enemy_hp_before, "전장에 같은 역할 아군이 있으면 1오브 스킬이 발동되어야 함")
	assert(battle.selected_orbs.is_empty(), "발동 후 오브 선택은 비워져야 함")

	battle.command_orbs[0] = battle._make_orb(0, battle.STRIKER, battle.ORB_NORMAL)
	battle.command_orbs[2] = battle._make_orb(2, battle.STRIKER, battle.ORB_NORMAL)
	battle._refresh_orb_buttons()
	battle._on_orb_button(0)
	battle._on_orb_button(2)
	assert(battle.selected_orbs == [0], "같은 색이어도 비인접 오브는 이어서 선택되면 안 됨")
	battle.command_orbs[1] = battle._make_orb(1, battle.STRIKER, battle.ORB_CORRUPTED)
	battle._refresh_orb_buttons()
	var ally_hp_before_orb: float = battle.ally_hp
	battle._on_orb_button(1)
	assert(battle.selected_orbs == [0, 1], "같은 색 인접 오브는 2오브 패턴으로 선택되어야 함")
	battle._on_orb_cast()
	assert(battle.ally_hp < ally_hp_before_orb, "오염 오브는 발동 시 아군 코어에 반동 피해를 줘야 함")

	battle.damage_core(battle.ENEMY, 760.0)
	assert(battle.last_stand_ready, "등불 25% 이하에서 최후 신호가 해금되어야 함")
	assert(battle.core_invuln > 0.0, "해금 직후 반응 시간을 위한 보호막이 필요함")
	assert(battle.ally_hp >= battle.ally_hp_max * 0.20, "해금 순간 코어 HP는 20% 아래로 내려가면 안 됨")
	if "--preview" in OS.get_cmdline_user_args():
		battle._update_buttons()
		battle.overlay.queue_redraw()
		await get_tree().process_frame
		battle.set_process(false)
		print("PREVIEW combat_rules last_stand_ready")
		return

	battle._on_skill()
	assert(battle.last_stand_used, "최후 신호 사용 상태가 기록되어야 함")
	assert(not battle.last_stand_ready, "사용한 최후 신호는 다시 준비 상태면 안 됨")
	assert(battle.core_invuln >= float(battle.last_stand_contract.get("barrier", 4.0)) - 0.1, "등불 방벽은 함선 계약의 지속 시간을 보장해야 함")

	var hp_before: float = battle.ally_hp
	battle.damage_core(battle.ENEMY, 999.0)
	assert(is_equal_approx(battle.ally_hp, hp_before), "방벽 지속 중에는 코어 피해를 무시해야 함")

	battle.queue_free()
	GameState.squad = ["진혼병", "운구 소총수", "관지기", "집전 의무관"]
	GameState.current_stage = 0
	var tutorial_battle = load("res://battle3d.tscn").instantiate()
	add_child(tutorial_battle)
	await get_tree().process_frame
	assert(not tutorial_battle._tutorial_enabled("orbs"), "ST1 실제 런은 오브를 잠가야 함")
	assert(not tutorial_battle._tutorial_enabled("deploy_position"), "ST1 실제 런은 위치 지정 배치를 잠가야 함")
	assert(not tutorial_battle._tutorial_enabled("soshin"), "ST1 실제 런은 소신을 잠가야 함")
	tutorial_battle.cost = 10.0
	tutorial_battle._on_card(0)
	assert(tutorial_battle.ally_count() == 1, "ST1 카드 클릭은 위치 지정 없이 즉시 자동 배치되어야 함")
	assert(tutorial_battle.pending_card_slot == -1, "ST1 자동 배치는 배치 대기 상태를 남기면 안 됨")
	tutorial_battle._on_soshin()
	assert(tutorial_battle.soshin_count == 0, "잠긴 ST1 소신은 실행되면 안 됨")
	tutorial_battle.queue_free()

	GameState.squad = []
	GameState.current_stage = 0
	var retreat_battle = load("res://battle3d.tscn").instantiate()
	add_child(retreat_battle)
	await get_tree().process_frame
	retreat_battle._on_retreat()
	assert(retreat_battle.ended and not retreat_battle.running, "후퇴는 즉시 전투를 종료해야 함")
	assert(retreat_battle.retreat_cause != "", "후퇴 종료는 별도 사인 진단 문구를 남겨야 함")
	retreat_battle.queue_free()

	var pause_battle = load("res://battle3d.tscn").instantiate()
	add_child(pause_battle)
	await get_tree().process_frame
	pause_battle._toggle_pause()
	assert(pause_battle.paused_by_player and not pause_battle.running, "일시정지는 전투 진행을 멈춰야 함")
	var elapsed_before_pause: float = pause_battle.elapsed
	pause_battle._process(1.0)
	assert(is_equal_approx(pause_battle.elapsed, elapsed_before_pause), "일시정지 중에는 전투 시간이 흐르면 안 됨")
	pause_battle._toggle_pause()
	assert(not pause_battle.paused_by_player and pause_battle.running, "일시정지 해제는 전투 진행을 복구해야 함")
	pause_battle.queue_free()

	for st in GameState.STAGES:
		assert(st.has("rule_tags") and not st["rule_tags"].is_empty(), "모든 스테이지는 규칙 태그를 가져야 함")
	GameState.cleared = []
	for st in GameState.STAGES:
		GameState.cleared.append(st["id"])
	GameState.current_stage = GameState.STAGES.size()
	var challenge: Dictionary = GameState.current_stage_def()
	assert(str(challenge.get("id", "")).begins_with("loop_"), "완주 후에는 시드 기반 변종 스테이지를 생성해야 함")
	assert(GameState.stage_open(GameState.STAGES.size()), "완주 후 변종 도전 노드가 열려야 함")
	var map = load("res://stagemap.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame
	map.queue_free()

	print("PASS combat_rules last_stand")
	get_tree().quit()
