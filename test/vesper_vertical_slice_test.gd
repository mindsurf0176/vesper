extends SceneTree

## 베스퍼 실제 진입점의 최소 수용 테스트.
## 타이틀 → 브리핑 → 전투 → 배치 → 결과 전환을 화면 루프 기준으로 검증한다.

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
	ok(flow.phase == flow.Phase.BRIEFING and flow._briefing_layer.visible, "타이틀에서 작전 브리핑으로 이동한다")
	flow._launch_battle()
	await process_frame
	await process_frame
	var battle = flow._battle_node
	ok(battle != null and is_instance_valid(battle), "브리핑에서 실제 전투 씬을 생성한다")
	ok(battle != null and battle.line_core_mode, "전투 씬은 정식 라인 코어를 사용한다")
	ok(battle is Node2D and battle.find_children("*", "Node3D", true, false).is_empty(), "활성 전투 렌더 트리는 2D만 사용한다")
	if battle != null and is_instance_valid(battle):
		battle.cost = 10.0
		battle._deploy_card_slot(0, battle.deployment_max_x())
		ok(battle.ally_count() == 1, "전투 중 손패 카드가 실제 아군을 배치한다")
		battle._end(true)
		await process_frame
		flow._process(0.0)
		ok(flow.phase == flow.Phase.RESULT and flow._result_layer.visible, "전투 종료가 결과 화면으로 라우팅된다")

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
