extends Node
## ★각인 데이터·선택·전투효과 회귀 테스트. 실제 세이브에는 기록하지 않는다.

const Unit3D = preload("res://legacy/vesper/unit3d.gd")

func _ready() -> void:
	GameState.unlocked = ["소등사"]
	GameState.squad = ["소등사"]
	GameState.brand_points = 1
	GameState.imprint_unlocked = []
	GameState.imprint_choices = {}

	assert(GameState.cycle_imprint("소등사", false), "각인재로 슬롯을 해금할 수 있어야 함")
	assert(GameState.brand_points == 0, "슬롯 첫 해금은 각인재 1개를 소비해야 함")
	var first := GameState.selected_imprint("소등사")
	assert(first["id"] == "last_round", "첫 선택은 캐릭터의 첫 각인이어야 함")
	assert(GameState.cycle_imprint("소등사", false), "해금한 슬롯은 무료로 선택 전환 가능해야 함")
	var second := GameState.selected_imprint("소등사")
	assert(second["id"] == "extinguished_sight", "두 번째 각인으로 순환해야 함")
	assert(GameState.brand_points == 0, "선택 전환은 각인재를 추가 소비하면 안 됨")
	var deck := GameState.squad_defs()
	assert(deck.size() == 1 and deck[0]["imprint"]["id"] == second["id"], "편성 덱에 선택한 각인이 주입되어야 함")

	var battle = load("res://legacy/vesper/battle3d.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame

	var attacker := Unit3D.new()
	attacker.main = battle; attacker.team = battle.ALLY
	attacker.imprint = { "kind":"execute", "threshold":0.35, "mult":1.50 }
	attacker.dead = true
	battle.add_child(attacker)
	var target := Unit3D.new()
	target.max_hp = 100.0; target.hp = 30.0; target.utype = battle.DEFENDER
	target.dead = true
	battle.add_child(target)
	assert(is_equal_approx(attacker._damage_imprint_mult(target), 1.5), "처형 각인은 저체력 적에게 적용되어야 함")

	var guard := Unit3D.new()
	guard.main = battle; guard.team = battle.ALLY; guard.hp = 100.0; guard.max_hp = 100.0
	guard.position.x = -5.0
	guard.imprint = { "kind":"near_core_guard", "max_x":-3.5, "mult":0.65 }
	battle.add_child(guard)
	guard.take_damage(20.0, 1.0)
	assert(is_equal_approx(guard.hp, 87.0), "봉문 각인은 코어 근처 피해를 35% 줄여야 함")
	guard.dead = true

	print("PASS imprint_rules selection injection effects")
	get_tree().quit()
