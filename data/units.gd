class_name UnitDB
extends RefCounted

## 열두 별자리. 원소마다 정확히 셋씩.
## 모든 스탯은 ★1 기준이며 합성 시 STAR_SCALE만큼 곱해진다.

const STAR_SCALE := 1.8
const MAX_STAR := 3

## 등급별 상점 풀 크기. 같은 별을 여러 명이 노리면 서로 마른다.
const POOL_SIZE := {1: 22, 2: 16, 3: 12, 4: 8}

## 강림 비용은 등급에서 그대로 나온다. 플레이어가 외울 숫자를 하나로 줄이기 위한
## 규칙이다 — "비싼 별은 사기도 비싸고 내려오는 것도 늦다"로 끝난다.
const DEPLOY_BY_TIER := {1: 2, 2: 4, 3: 7, 4: 11}

## 별지기 레벨별 등급 등장 확률(%). 합은 100.
const SHOP_ODDS := {
	3: [75, 25, 0, 0],
	4: [60, 32, 8, 0],
	5: [45, 40, 14, 1],
	6: [30, 42, 25, 3],
	7: [22, 38, 32, 8],
	8: [16, 32, 38, 14],
	9: [10, 24, 42, 24],
}

const MIN_LEVEL := 3
const MAX_LEVEL := 9

## 다음 레벨까지 필요한 경험치.
const XP_TO_NEXT := {3: 4, 4: 8, 5: 14, 6: 22, 7: 34, 8: 50}

## 별자리 정의.
##   role: 상성 판정에만 쓴다 (근접 ▶ 원거리 ▶ 방어 ▶ 근접)
##   element: 시너지 판정에만 쓴다 (같은 원소를 모으면 세진다)
##   atk_range: 6이면 근접, 20 이상이면 뒤에서 지원 사격
##   ability: 자동 발동하는 고유 능력. sim은 별자리 ID가 아니라 효과 키를 해석한다.
static func table() -> Dictionary:
	var R := Defs.Role
	var E := Defs.Element
	return {
		# --- 불: 타오른다 ---
		"aries": {
			"name": "양", "tier": 1, "role": R.STRIKER, "element": E.FIRE,
			"hp": 495.0, "atk": 52.0, "armor": 15.0, "atk_speed": 0.9,
			"atk_range": 6.0, "move_speed": 12.0,
			"ability": {"name": "선봉", "description": "강림 후 4초간 이동·공격 속도 +35%",
				"deploy_haste": 1.35, "duration": 4.0},
			"flavor": "앞뒤 안 재고 먼저 뛰어든다",
		},
		"sagittarius": {
			"name": "사수", "tier": 2, "role": R.RANGER, "element": E.FIRE,
			"hp": 490.0, "atk": 62.0, "armor": 8.0, "atk_speed": 0.55,
			"atk_range": 32.0, "move_speed": 8.0,
			"ability": {"name": "꿰뚫는 화살", "description": "공격할 때 상대 방어의 45%를 무시",
				"armor_pierce": 0.45},
			"flavor": "멀리서 정확히 쏜다",
		},
		"leo": {
			"name": "사자", "tier": 3, "role": R.STRIKER, "element": E.FIRE,
			"hp": 810.0, "atk": 98.0, "armor": 22.0, "atk_speed": 0.85,
			"atk_range": 6.0, "move_speed": 11.0,
			"ability": {"name": "왕의 불꽃", "description": "상대를 잠재울 때 공격력 +15% (최대 3회)",
				"kill_atk_mult": 0.15, "max_stacks": 3},
			"flavor": "늦게 오지만 판을 뒤집는다",
		},
		# --- 흙: 단단하다 ---
		"virgo": {
			"name": "처녀", "tier": 1, "role": R.SUPPORT, "element": E.EARTH,
			"hp": 440.0, "atk": 24.0, "armor": 12.0, "atk_speed": 0.6,
			"atk_range": 22.0, "move_speed": 9.0,
			"ability": {"name": "별의 손길", "description": "강림해 있는 동안 아군 최대 체력의 1.4%를 매초 회복",
				"active_team_regen": 0.014},
			"flavor": "조용히 뒤를 돌본다",
		},
		"taurus": {
			"name": "황소", "tier": 2, "role": R.DEFENDER, "element": E.EARTH,
			"hp": 1120.0, "atk": 33.0, "armor": 48.0, "atk_speed": 0.7,
			"atk_range": 6.0, "move_speed": 7.5,
			"ability": {"name": "우직함", "description": "한 번에 받는 피해가 최대 체력의 16%를 넘지 않음",
				"damage_cap_ratio": 0.16},
			"flavor": "밀리지 않는다",
		},
		"capricorn": {
			"name": "염소", "tier": 4, "role": R.DEFENDER, "element": E.EARTH,
			"hp": 1920.0, "atk": 60.0, "armor": 70.0, "atk_speed": 0.65,
			"atk_range": 6.0, "move_speed": 7.0,
			"ability": {"name": "산의 수호", "description": "강림해 있는 동안 내 성좌가 받는 피해 -20%",
				"active_core_reduction": 0.20},
			"flavor": "가장 늦게, 가장 굳건하게",
		},
		# --- 바람: 빠르다 ---
		"gemini": {
			"name": "쌍둥이", "tier": 1, "role": R.STRIKER, "element": E.AIR,
			"hp": 450.0, "atk": 47.0, "armor": 12.0, "atk_speed": 1.1,
			"atk_range": 6.0, "move_speed": 14.0,
			"ability": {"name": "쌍성", "description": "매 3번째 공격이 60% 추가 피해",
				"every_n_attack": 3, "bonus_damage": 0.60},
			"flavor": "둘이 함께 재빠르게",
		},
		"libra": {
			"name": "천칭", "tier": 2, "role": R.RANGER, "element": E.AIR,
			"hp": 490.0, "atk": 55.0, "armor": 10.0, "atk_speed": 0.9,
			"atk_range": 24.0, "move_speed": 10.0,
			"ability": {"name": "균형의 심판", "description": "자신보다 체력 비율이 높은 상대에게 피해 +25%",
				"healthier_target_bonus": 0.25},
			"flavor": "거리를 재며 균형을 잡는다",
		},
		"aquarius": {
			"name": "물병", "tier": 3, "role": R.SUPPORT, "element": E.AIR,
			"hp": 720.0, "atk": 48.0, "armor": 18.0, "atk_speed": 0.65,
			"atk_range": 22.0, "move_speed": 9.0,
			"ability": {"name": "순풍", "description": "강림할 때 별의 기운 2를 되돌려줌",
				"deploy_cost_refund": 2.0},
			"flavor": "흐름을 바꾼다",
		},
		# --- 물: 흐른다 ---
		"cancer": {
			"name": "게", "tier": 1, "role": R.DEFENDER, "element": E.WATER,
			"hp": 880.0, "atk": 24.0, "armor": 38.0, "atk_speed": 0.7,
			"atk_range": 6.0, "move_speed": 8.0,
			"ability": {"name": "별껍질", "description": "강림할 때 최대 체력의 25%만큼 보호막 획득",
				"deploy_shield_ratio": 0.25},
			"flavor": "껍질로 버틴다",
		},
		"pisces": {
			"name": "물고기", "tier": 1, "role": R.RANGER, "element": E.WATER,
			"hp": 385.0, "atk": 43.0, "armor": 8.0, "atk_speed": 0.85,
			"atk_range": 26.0, "move_speed": 9.0,
			"ability": {"name": "유영", "description": "매 4번째 피격을 완전히 회피",
				"dodge_every_n_hit": 4},
			"flavor": "미끄러지듯 피하며 쏜다",
		},
		"scorpio": {
			"name": "전갈", "tier": 2, "role": R.STRIKER, "element": E.WATER,
			"hp": 630.0, "atk": 66.0, "armor": 16.0, "atk_speed": 1.0,
			"atk_range": 6.0, "move_speed": 13.0,
			"ability": {"name": "독침", "description": "체력이 40% 이하인 상대에게 피해 +35%",
				"execute_threshold": 0.40, "execute_bonus": 0.35},
			"flavor": "한 방이 깊다",
		},
	}

static func get_def(def_id: String) -> Dictionary:
	var t := table()
	assert(t.has(def_id), "unknown star: %s" % def_id)
	return t[def_id]


static func ability(def_id: String) -> Dictionary:
	return get_def(def_id)["ability"]


static func ability_text(def_id: String) -> String:
	var a := ability(def_id)
	return "%s — %s" % [a["name"], a["description"]]


## 강림 비용. 등급에서 유도하므로 데이터에 따로 적지 않는다.
static func deploy_cost(def_id: String) -> int:
	return int(DEPLOY_BY_TIER[get_def(def_id)["tier"]])

static func ids_by_tier(tier: int) -> Array[String]:
	var out: Array[String] = []
	var t := table()
	for id in t:
		if int(t[id]["tier"]) == tier:
			out.append(id)
	out.sort()
	return out

## ★ 배율. ★1=1.0, ★2=1.8, ★3=3.24
static func star_mult(star: int) -> float:
	return pow(STAR_SCALE, float(star - 1))
