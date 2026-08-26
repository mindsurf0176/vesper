extends SceneTree

## 캐릭터 선택 → 1대1 대전 → 결과 전환의 실제 진입 테스트.

var passed := 0
var failed := 0
var flow

func _initialize() -> void:
	flow = preload("res://scenes/main_flow_new.gd").new()
	root.add_child(flow)
	call_deferred("_run")

func _run() -> void:
	await process_frame
	ok(flow.phase == flow.Phase.TITLE, "베스퍼 진입점은 타이틀에서 시작한다")
	flow._on_start_pressed()
	ok(flow.phase == flow.Phase.SELECT and flow._select_layer.visible, "타이틀에서 캐릭터 선택으로 이동한다")
	var roster: Array = root.get_node("/root/GameState").all_chars_list()
	ok(roster.size() >= 2, "대전 가능한 캐릭터 목록이 있다")
	flow._select_fighter(roster[0])
	flow._select_fighter(roster[1])
	ok(not flow._select_start.disabled, "플레이어와 상대를 모두 고르면 시작 버튼이 열린다")
	flow._launch_battle()
	await process_frame
	await process_frame
	var duel = flow._battle_node
	ok(duel != null and is_instance_valid(duel), "선택한 캐릭터로 격투 씬을 생성한다")
	ok(duel != null and duel.player.fighter_name == str(roster[0]["name"]), "플레이어 캐릭터 선택이 대전에 반영된다")
	ok(duel != null and duel.enemy.fighter_name == str(roster[1]["name"]), "상대 캐릭터 선택이 대전에 반영된다")
	if duel != null and is_instance_valid(duel):
		var before: float = duel.enemy_hp
		duel.player.position.x = duel.enemy.position.x - 90.0
		duel._try_attack(duel.player, true, false)
		ok(duel.enemy_hp < before, "약공격이 상대 HP를 감소시킨다")
		duel.enemy_hp = 100.0
		duel.player_cooldown = 0.0
		duel.enemy.set_guarding(true)
		duel.enemy_perfect_timer = 0.18
		duel._try_attack(duel.player, true, false)
		ok(duel.enemy_hp == 100.0 and duel.player.stagger_timer > 0.0, "퍼펙트 가드가 피해를 무효화하고 공격자를 경직시킨다")
		duel.player_cooldown = 0.0
		duel.enemy.set_guarding(true)
		duel.enemy_perfect_timer = 0.0
		duel._try_attack(duel.player, true, false)
		ok(duel.enemy_hp < 100.0 and duel.enemy_hp > 96.0, "일반 가드가 피해를 크게 줄인다")
		ok(float(duel._special_profile({"visual":{"shape":"rifle"}}).get("reach", 0.0)) == 360.0, "소총수 필살기가 장거리 판정을 가진다")
		duel.enemy.set_guarding(false)
		duel.enemy_hp = 0.0
		duel._check_end()
		ok(duel.round_over and duel.player_round_wins == 1, "첫 라운드 승리가 기록된다")
		duel.round_timer = 0.0
		duel._process(0.0)
		ok(duel.round_number == 2 and duel.enemy_hp == 100.0, "다음 라운드가 초기화된다")
		duel.enemy_hp = 0.0
		duel._check_end()
		duel.round_timer = 0.0
		duel._process(0.0)
		flow._process(0.0)
		ok(flow.phase == flow.Phase.RESULT and flow._result_layer.visible and duel.winner == 0, "2선승 결과가 결과 화면으로 라우팅된다")

	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	flow.queue_free()
	quit(1 if failed > 0 else 0)

func ok(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("  [OK] %s" % label)
	else:
		failed += 1
		print("  [FAIL] %s" % label)
