extends SceneTree

const Run = preload("res://core/corridor_run.gd")

func _init() -> void:
	var a = Run.new(777)
	var b = Run.new(777)
	assert(a.route == b.route, "같은 시드의 회랑 경로가 달라짐")
	assert(a.current_mutator() == b.current_mutator(), "같은 시드의 런 변칙이 달라짐")
	assert(["overclock", "thin_lantern", "red_tide"].has(a.current_mutator().get("id", "")), "허용되지 않은 런 변칙이 선택됨")
	assert(a.current_mutator().has("description"), "런 변칙 설명이 누락됨")
	assert(a.current().get("kind", "") == "전투", "첫 노드가 라인 전투가 아님")
	assert(["철벽", "돌격", "증식"].has(a.current().get("variant", "")), "전투 변종이 생성되지 않음")
	assert(a.distance == 0 and a.best_distance == 0, "새 런의 거리가 0에서 시작하지 않음")
	a.complete_current()
	assert(a.route_index == 1 and a.distance == 1 and not a.is_finished(), "전투 후 다음 탐험 구간으로 이동하지 않음")
	assert(a.available_options().size() == 3, "다음 구간 선택지가 3개가 아님")
	assert(a.choose_option(2), "2층 엘리트 경로를 선택하지 못함")
	assert(a.current().get("floor", 0) == 2, "선택한 다음 구간이 현재 노드에 반영되지 않음")
	var reward_relic_count := 0
	for _i in 12:
		a.complete_current()
		reward_relic_count += a.rewards.back().get("relic_choices", []).size()
		if not a.available_options().is_empty():
			a.choose_option(0)
	assert(a.distance == 13 and a.best_distance == 13, "무한 회랑 거리 기록이 누적되지 않음")
	assert(not a.is_finished() and a.current().get("floor", 0) == 14, "보스 이후에도 회랑이 계속되지 않음")
	assert(reward_relic_count >= 36, "전투 보상에 충분한 유물 선택지가 없음")
	var loss := Run.new(31337)
	loss.complete_current(false)
	assert(loss.distance == 1 and loss.rewards.is_empty(), "패배 구간이 유물 보상을 지급함")
	var failed := Run.new(4242)
	failed.fail()
	assert(failed.is_finished() and failed.failed, "패배한 런이 종료 상태가 아님")
	failed.complete_current()
	assert(failed.distance == 0, "종료된 런이 패배 후에도 다음 구간으로 진행함")
	var special := Run.new(1717)
	var saw_special := false
	for _i in 20:
		if special.current().get("kind", "") == "보급" or special.current().get("kind", "") == "이벤트":
			var special_options := special.special_options()
			assert(special_options.size() == 2, "특수 노드의 선택지가 2개가 아님")
			var outcome := special.choose_special(str(special_options[0]["id"]))
			assert(not outcome.is_empty(), "특수 노드 선택 결과가 비어 있음")
			saw_special = true
			break
		special.complete_current()
		if not special.available_options().is_empty():
			special.choose_option(0)
	assert(saw_special, "결정론 테스트 시 특수 노드를 찾지 못함")
	print("PASS endless corridor run")
	quit(0)
