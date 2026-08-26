extends SceneTree

const Run = preload("res://core/corridor_run.gd")

func _init() -> void:
	var a = Run.new(777)
	var b = Run.new(777)
	assert(a.route == b.route, "같은 시드의 회랑 경로가 달라짐")
	assert(a.route.size() == 4, "회랑 길이가 4개가 아님")
	assert(a.current().get("kind", "") == "전투", "첫 노드가 라인 전투가 아님")
	a.complete_current()
	assert(a.route_index == 1 and not a.is_finished(), "전투 후 다음 탐험 노드로 이동하지 않음")
	assert(a.available_options().size() == 3, "2층 분기 선택지가 3개가 아님")
	assert(a.choose_option(2), "2층 엘리트 경로를 선택하지 못함")
	assert(a.current().get("kind", "") == "엘리트", "선택한 2층 경로가 현재 노드에 반영되지 않음")
	a.complete_current()
	assert(a.rewards.back().get("relic_choices", []).size() == 3, "엘리트 보상 유물 선택지가 없음")
	a.complete_current()
	assert(a.current().get("kind", "") == "보스", "마지막 노드가 보스가 아님")
	a.complete_current()
	assert(a.cleared and a.is_finished(), "보스 클리어가 런 종료로 이어지지 않음")
	print("PASS corridor run")
	quit(0)
