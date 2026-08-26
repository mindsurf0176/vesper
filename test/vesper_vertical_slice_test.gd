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
	assert(flow.game.human_seat().player.queued_units().size() == 4, "고정 원정대가 4명으로 구성되지 않음")
	var selected_ids := {}
	for unit in flow.game.human_seat().player.queued_units():
		selected_ids[str(unit.get("def_id", ""))] = true
	assert(selected_ids == {"aries": true, "sagittarius": true, "capricorn": true, "pisces": true}, "준비된 4명 외 계약자가 원정대에 포함됨")
	flow.game.human_seat().player.roster[0]["order"] = -1
	flow._start_battle(true)
	assert(flow.phase == flow.Phase.PREP, "4명 미만 편성이 전투 시작을 우회함")
	flow.game.human_seat().player.roster[0]["order"] = 0
	assert(flow.game.seats[1].name == flow.corridor.route[0].get("name", ""), "조우 이름이 적 전투에 반영되지 않음")
	assert(flow.game.seats[1].player.roster.size() >= 2, "조우별 적 편성이 생성되지 않음")
	flow.corridor.route_index = 1
	assert(flow.corridor.choose_option(2), "엘리트 분기 선택 실패")
	flow._configure_corridor_encounter()
	assert(flow.game.seats[1].player.level > 3, "위협 배율이 적 레벨에 반영되지 않음")
	assert(int(flow.game.seats[1].player.roster[0].get("star", 1)) == 2, "엘리트 적 별 등급이 반영되지 않음")
	print("PASS corridor line battler flow")
	flow.queue_free()
	quit(0)
