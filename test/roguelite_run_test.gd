extends SceneTree

const Run = preload("res://core/roguelite_run.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	var run_a = Run.new(424242)
	var run_b = Run.new(424242)
	ok(run_a.nodes == run_b.nodes, "같은 seed는 같은 노드 맵을 만든다")
	ok(run_a.mutators == run_b.mutators, "같은 seed는 같은 변칙을 만든다")
	ok(run_a.nodes.size() == 5 and run_a.nodes[0]["type"] == "전투" and run_a.nodes[4]["type"] == "보스", "짧은 런의 시작과 보스가 보장된다")
	run_a.start_with_team([{"name":"A"},{"name":"B"},{"name":"C"},{"name":"D"}])
	ok(run_a.team.size() == 3 and run_a.team[0]["run_hp"] == 100.0, "런 편성은 세 명으로 제한된다")
	var relic := run_a.add_relic()
	ok(not relic.is_empty() and run_a.relics.size() == 1, "유물 보상은 중복 없이 추가된다")
	run_a.team[0]["run_hp"] = 55.0
	var before := float(run_a.team[0]["run_hp"])
	run_a.apply_rest(20.0)
	ok(float(run_a.team[0]["run_hp"]) > before, "회복 노드가 런 HP를 회복한다")
	print("\nRoguelite 결과: %d 통과 / %d 실패" % [passed, failed])
	quit(1 if failed > 0 else 0)

func ok(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("  [OK] %s" % label)
	else:
		failed += 1
		print("  [FAIL] %s" % label)
