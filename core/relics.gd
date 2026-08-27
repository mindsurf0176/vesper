class_name RelicDB
extends RefCounted

## 회랑 런의 유물 정본.
## id는 세이브/결정론용이고, 이름·설명은 UI와 보상 선택에 사용한다.
## 유물은 CombatSim이 소비하는 placement modifier로만 전투에 연결한다.

const TABLE := [

	{"id":"ember_cache", "name":"잔불 보관함", "tag":"생존", "desc":"아군 최대 HP +10%"},
	{"id":"signal_lens", "name":"신호 렌즈", "tag":"속도", "desc":"아군 공격 속도 +12%"},
	{"id":"hollow_crown", "name":"공허 왕관", "tag":"공격", "desc":"아군 공격력 +15%"},
	{"id":"anchor_shard", "name":"닻의 파편", "tag":"방어", "desc":"출격할 때 최대 HP의 18% 보호막"},
	{"id":"relay_beacon", "name":"중계 비콘", "tag":"돌입", "desc":"각 전투 첫 공격 피해 +25%"},
	{"id":"iron_echo", "name":"철의 잔향", "tag":"방어", "desc":"아군 방어력 +14"},
	{"id":"last_lantern", "name":"마지막 등불", "tag":"역전", "desc":"HP 35% 이하일 때 공격력 +28%"},
	{"id":"longwatch", "name":"긴 감시선", "tag":"사격", "desc":"아군 사거리 +8"},
	{"id":"breach_round", "name":"관통 탄두", "tag":"관통", "desc":"방어 관통 효과 +18%p"},
	{"id":"quickstep", "name":"잔상 보폭", "tag":"기동", "desc":"아군 이동 속도 +14%"},
	{"id":"ward_sigil", "name":"수호 각인", "tag":"보호", "desc":"받는 피해 -10%"},
	{"id":"tide_core", "name":"조류 핵", "tag":"회복", "desc":"전투 중 아군 초당 HP 회복 +0.6%"},
	{"id":"overdrive", "name":"과부하 심지", "tag":"초반", "desc":"전투 시작 후 10초간 공격력 +15%"},
	{"id":"glass_edge", "name":"유리 칼날", "tag":"위험", "desc":"공격력 +22%, 받는 피해 +15%"},
	{"id":"core_lens", "name":"매듭 렌즈", "tag":"돌파", "desc":"적 코어에 주는 피해 +25%"},
]

const COMBOS := [
	{"id":"lantern_fortress", "required":["ember_cache", "anchor_shard"],
		"name":"등불 요새", "desc":"최대 HP +8%, 출격 보호막 +10%p",
		"effects":{"relic_hp_mult":1.08, "relic_shield_ratio":0.10}},
	{"id":"sightline_link", "required":["signal_lens", "longwatch"],
		"name":"조준 링크", "desc":"공격 속도 +8%, 사거리 +4",
		"effects":{"relic_as_mult":1.08, "relic_range_add":4.0}},
	{"id":"breach_doctrine", "required":["hollow_crown", "breach_round"],
		"name":"관통 교리", "desc":"공격력 +7%, 방어 관통 +10%p",
		"effects":{"relic_atk_mult":1.07, "relic_armor_pierce_add":0.10}},
	{"id":"first_breach", "required":["quickstep", "relay_beacon"],
		"name":"선행 돌입", "desc":"이동 속도 +8%, 첫 공격 피해 +10%",
		"effects":{"relic_move_mult":1.08, "relic_opening_atk_mult":0.10}},
	{"id":"recovery_shell", "required":["ward_sigil", "tide_core"],
		"name":"회복 장갑", "desc":"받는 피해 -5%, 전투 회복 +0.4%/초",
		"effects":{"relic_damage_taken_mult":0.95, "relic_team_regen":0.004}},
]


static func all() -> Array:
	return TABLE.duplicate(true)


static func get_def(relic_id: String) -> Dictionary:
	for relic in TABLE:
		if str(relic["id"]) == relic_id:
			return relic.duplicate(true)
	return {}


static func name(relic_id: String) -> String:
	var relic := get_def(relic_id)
	return str(relic.get("name", relic_id))


static func description(relic_id: String) -> String:
	var relic := get_def(relic_id)
	return str(relic.get("desc", "알 수 없는 효과"))


static func active_combos(relics: Array[String]) -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for combo in COMBOS:
		var complete := true
		for required in combo["required"]:
			if not relics.has(str(required)):
				complete = false
				break
		if complete:
			active.append(combo.duplicate(true))
	return active


static func apply_to_placement(placement: Dictionary, relics: Array[String]) -> void:
	for relic_id in relics:
		match relic_id:
			"ember_cache":
				placement["relic_hp_mult"] = float(placement.get("relic_hp_mult", 1.0)) * 1.10
			"signal_lens":
				placement["relic_as_mult"] = float(placement.get("relic_as_mult", 1.0)) * 1.12
			"hollow_crown":
				placement["relic_atk_mult"] = float(placement.get("relic_atk_mult", 1.0)) * 1.15
			"anchor_shard":
				placement["relic_shield_ratio"] = float(placement.get("relic_shield_ratio", 0.0)) + 0.18
			"relay_beacon":
				placement["relic_opening_atk_mult"] = float(placement.get("relic_opening_atk_mult", 0.0)) + 0.25
			"iron_echo":
				placement["relic_armor_add"] = float(placement.get("relic_armor_add", 0.0)) + 14.0
			"last_lantern":
				placement["relic_low_hp_atk_mult"] = float(placement.get("relic_low_hp_atk_mult", 0.0)) + 0.28
			"longwatch":
				placement["relic_range_add"] = float(placement.get("relic_range_add", 0.0)) + 8.0
			"breach_round":
				placement["relic_armor_pierce_add"] = float(placement.get("relic_armor_pierce_add", 0.0)) + 0.18
			"quickstep":
				placement["relic_move_mult"] = float(placement.get("relic_move_mult", 1.0)) * 1.14
			"ward_sigil":
				placement["relic_damage_taken_mult"] = float(placement.get("relic_damage_taken_mult", 1.0)) * 0.90
			"tide_core":
				placement["relic_team_regen"] = maxf(float(placement.get("relic_team_regen", 0.0)), 0.006)
			"overdrive":
				placement["relic_early_atk_mult"] = float(placement.get("relic_early_atk_mult", 0.0)) + 0.15
			"glass_edge":
				placement["relic_atk_mult"] = float(placement.get("relic_atk_mult", 1.0)) * 1.22
				placement["relic_damage_taken_mult"] = float(placement.get("relic_damage_taken_mult", 1.0)) * 1.15
			"core_lens":
				placement["relic_core_damage_mult"] = float(placement.get("relic_core_damage_mult", 1.0)) * 1.25
	for combo in active_combos(relics):
		_apply_combo_effects(placement, combo.get("effects", {}))


static func _apply_combo_effects(placement: Dictionary, effects: Dictionary) -> void:
	for key in effects:
		var value := float(effects[key])
		match str(key):
			"relic_hp_mult", "relic_as_mult", "relic_atk_mult", "relic_move_mult", "relic_damage_taken_mult":
				placement[key] = float(placement.get(key, 1.0)) * value
			"relic_team_regen":
				placement[key] = maxf(float(placement.get(key, 0.0)), value)
			_:
				placement[key] = float(placement.get(key, 0.0)) + value
