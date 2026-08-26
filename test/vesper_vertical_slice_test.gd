extends SceneTree

## 회랑 탐험 → 라인배틀러 준비 흐름의 실제 진입 테스트.

func _initialize() -> void:
	var flow = preload("res://scenes/main_flow.gd").new()
	root.add_child(flow)
	await process_frame
	assert(flow.phase == flow.Phase.MAP, "게임이 회랑 지도에서 시작하지 않음")
	assert(flow.corridor.current().get("kind", "") == "전투", "첫 회랑 노드가 전투가 아님")
	flow._choose_corridor()
	await process_frame
	assert(flow.phase == flow.Phase.PREP, "전투 노드가 준비 페이즈로 연결되지 않음")
	assert(flow.game.seats[1].name == flow.corridor.route[0].get("name", ""), "조우 이름이 적 전투에 반영되지 않음")
	assert(flow.game.seats[1].player.roster.size() >= 2, "조우별 적 편성이 생성되지 않음")
	print("PASS corridor line battler flow")
	flow.queue_free()
	quit(0)
