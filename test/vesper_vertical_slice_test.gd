extends SceneTree

## 로그라이크 3대3 진입점 세로 슬라이스 테스트.

var passed := 0
var failed := 0

func _initialize() -> void:
	var flow = preload("res://scenes/roguelite/roguelite_view.gd").new()
	root.add_child(flow)
	await process_frame
	ok(flow.phase == flow.Phase.SELECT, "게임은 3인 편성 화면에서 시작한다")
	var roster: Array = root.get_node("/root/GameState").all_chars_list()
	ok(roster.size() >= 3, "편성 가능한 캐릭터가 세 명 이상이다")
	for i in 3:
		flow._toggle_fighter(roster[i], flow.selected_buttons[i])
	ok(flow.selected_team.size() == 3, "세 명을 편성할 수 있다")
	flow._start_run()
	await process_frame
	ok(flow.phase == flow.Phase.MAP and flow.run.nodes.size() == 5, "편성 후 5노드 런이 생성된다")
	var node: Dictionary = flow.run.choose_next(0)
	flow._start_battle(node)
	await process_frame
	ok(flow.phase == flow.Phase.BATTLE and flow.enemy_team.size() == 3, "노드에서 3대3 전투가 시작된다")
	var before: float = flow.enemy_hp[flow.enemy_active]
	flow._player_action("공격")
	ok(flow.enemy_hp[flow.enemy_active] < before, "공격 명령이 적 HP를 감소시킨다")
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
