class_name UnitDB
extends RefCounted

## VESPER 12인 계약자 정본.
## dictionary key와 motif는 save·pool·deterministic sim용 제작 metadata이며 UI에 노출하지 않는다.
## 모든 스탯은 ★1 기준이며 합성 시 STAR_SCALE만큼 곱해진다.

const STAR_SCALE := 1.8
const MAX_STAR := 3

const POOL_SIZE := {1: 22, 2: 16, 3: 12, 4: 8}
const DEPLOY_BY_TIER := {1: 2, 2: 4, 3: 7, 4: 11}

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
const XP_TO_NEXT := {3: 4, 4: 8, 5: 14, 6: 22, 7: 34, 8: 50}


## ability의 수치 effect key는 gameplay 계약이다. 이름·설명만 캐릭터 정체성에 맞춘다.
static func table() -> Dictionary:
	var R := Defs.Role
	var E := Defs.Element
	return {
		"aries": {
			"name": "모아", "true_name": "모아 린", "gender": "female",
			"epithet": "잔상의 무희", "motif": "쌍의 리듬과 바람의 잔상을 겹쳐 세 번째 박자에 전선을 찢는다",
			"faction": "청람 유격대", "personality": "전술 드론과 혼잣말처럼 대화하며 리듬이 깨지는 것을 싫어한다",
			"silhouette": "비대칭 단발과 낮게 기운 몸, 두 개의 잔상 드론과 교차하는 쌍도",
			"weapon": "분절 쌍도", "tier": 1, "role": R.STRIKER, "element": E.AIR,
			"hp": 450.0, "atk": 47.0, "armor": 12.0, "atk_speed": 1.1,
			"atk_range": 6.0, "move_speed": 17.5,
			"ability": {"name": "겹빛 연격", "description": "매 3번째 공격이 60% 추가 피해",
				"every_n_attack": 3, "bonus_damage": 0.60},
			"flavor": "한 번의 빈틈에 두 개의 궤적을 겹쳐 넣는다",
		},
		"sagittarius": {
			"name": "비질", "true_name": "비질 크로스", "gender": "male",
			"epithet": "원거리 감시자", "motif": "장거리 조준선과 어깨 거리계로 회랑의 빈틈을 읽는다",
			"faction": "초점 감시국", "personality": "말보다 좌표를 믿고 한 번 정한 표적을 놓치지 않는다",
			"silhouette": "긴 코트와 수평으로 뻗은 거대한 총궁, 한쪽 어깨의 거리계",
			"weapon": "관통 총궁", "tier": 2, "role": R.RANGER, "element": E.FIRE,
			"hp": 330.0, "atk": 76.0, "armor": 4.0, "atk_speed": 0.55,
			"atk_range": 42.0, "move_speed": 10.0,
			"ability": {"name": "적층 관통", "description": "공격할 때 상대 방어의 45%를 무시",
				"armor_pierce": 0.45},
			"flavor": "보이지 않는 거리까지 이미 사선으로 바꾸어 두었다",
		},
		"leo": {
			"name": "솔렌", "true_name": "솔렌 베이", "gender": "female",
			"epithet": "황혼 기수", "motif": "금빛 망토와 장창으로 무너지는 전선을 되세우는 기수",
			"faction": "황혼 기병대", "personality": "화려하지만 허세가 없고 승리의 책임을 혼자 짊어진다",
			"silhouette": "갈기처럼 퍼지는 금빛 망토와 높이 든 기창, 넓은 삼각 자세",
			"weapon": "점화 기창", "tier": 3, "role": R.STRIKER, "element": E.FIRE,
			"hp": 810.0, "atk": 98.0, "armor": 22.0, "atk_speed": 0.85,
			"atk_range": 6.0, "move_speed": 13.5,
			"ability": {"name": "승전의 잔광", "description": "상대를 쓰러뜨릴 때 공격력 +15% (최대 3회)",
				"kill_atk_mult": 0.15, "max_stacks": 3},
			"flavor": "한 번 밝아진 선두의 빛은 승리할수록 더 커진다",
		},
		"virgo": {
			"name": "멘더", "true_name": "미라 멘더", "gender": "female",
			"epithet": "생환 기술자", "motif": "부상과 장비 손상을 동시에 봉합하는 부유 실타래 드론",
			"faction": "생환 공방", "personality": "작은 고장도 지나치지 않으며 다정함을 정확한 절차로 표현한다",
			"silhouette": "민트색 반망토와 떠다니는 실타래 드론, 손바닥의 작은 등불",
			"weapon": "봉합사 드론", "tier": 1, "role": R.SUPPORT, "element": E.EARTH,
			"hp": 440.0, "atk": 24.0, "armor": 12.0, "atk_speed": 0.6,
			"atk_range": 22.0, "move_speed": 11.0,
			"ability": {"name": "생명 봉합", "description": "강림해 있는 동안 아군 최대 체력의 1.4%를 매초 회복",
				"active_team_regen": 0.014},
			"flavor": "꺼져 가는 기억도 한 올씩 다시 이어 붙인다",
		},
		"taurus": {
			"name": "앵커", "true_name": "브램 앵커", "gender": "male",
			"epithet": "중력 방벽", "motif": "거대한 닻방패와 고정 말뚝으로 전선을 붙드는 중장갑",
			"faction": "중력 방벽대", "personality": "느리게 판단하지만 결정한 뒤에는 함대조차 밀지 못한다",
			"silhouette": "거대한 사각 닻방패와 짧고 넓은 중장갑, 뒤로 박힌 고정 말뚝",
			"weapon": "중력 닻방패", "tier": 2, "role": R.DEFENDER, "element": E.EARTH,
			"hp": 1120.0, "atk": 33.0, "armor": 48.0, "atk_speed": 0.7,
			"atk_range": 6.0, "move_speed": 9.5,
			"ability": {"name": "질량 한계", "description": "한 번에 받는 피해가 최대 체력의 16%를 넘지 않음",
				"damage_cap_ratio": 0.16},
			"flavor": "그가 닻을 내린 자리가 곧 전선의 끝이다",
		},
		"capricorn": {
			"name": "워든", "true_name": "네라 워든", "gender": "female",
			"epithet": "회랑 수문장", "motif": "긴 탑방패와 갈고리로 붕괴 구간의 마지막 문을 지킨다",
			"faction": "수문 감시단", "personality": "높은 곳에서 전체를 보고 가장 위험한 책임을 조용히 맡는다",
			"silhouette": "세로로 긴 백청색 탑방패와 등반 갈고리, 절벽 같은 직립 자세",
			"weapon": "능선 탑방패", "tier": 4, "role": R.DEFENDER, "element": E.EARTH,
			"hp": 1920.0, "atk": 60.0, "armor": 70.0, "atk_speed": 0.65,
			"atk_range": 6.0, "move_speed": 9.0,
			"ability": {"name": "수문 장막", "description": "출격해 있는 동안 아군 코어가 받는 피해 -20%",
				"active_core_reduction": 0.20},
			"flavor": "가장 늦게 도착해 마지막 관문이 된다",
		},
		"gemini": {
			"name": "미러", "true_name": "미레이 보스", "gender": "female",
			"epithet": "잔상 유격수", "motif": "두 대의 잔상 드론과 분절 쌍도로 빈틈을 겹쳐 베는 유격수",
			"faction": "청람 유격대", "personality": "혼잣말처럼 전술 드론과 대화하며 리듬이 깨지는 것을 싫어한다",
			"silhouette": "좌우 비대칭 단발과 두 개의 사람형 잔상 드론, 교차하는 곡선 검광",
			"weapon": "잔상 분할도", "tier": 1, "role": R.STRIKER, "element": E.AIR,
			"hp": 450.0, "atk": 47.0, "armor": 12.0, "atk_speed": 1.1,
			"atk_range": 6.0, "move_speed": 17.5,
			"ability": {"name": "잔상 동조", "description": "매 4번째 공격이 45% 추가 피해",
				"every_n_attack": 4, "bonus_damage": 0.45},
			"flavor": "한 번의 빈틈에 두 개의 궤적을 겹쳐 넣는다",
		},
		"libra": {
			"name": "게이지", "true_name": "게일런 룩", "gender": "male",
			"epithet": "거리 집행관", "motif": "쌍권총과 부유 추로 전장의 거리를 재단하는 사수",
			"faction": "거리 판결국", "personality": "감정보다 수치를 앞세우지만 약자를 향한 불균형에는 냉정하게 분노한다",
			"silhouette": "허리 양옆의 거울 권총과 부유 저울추, 수평으로 열린 긴 팔선",
			"weapon": "거리계 권총", "tier": 2, "role": R.RANGER, "element": E.AIR,
			"hp": 490.0, "atk": 55.0, "armor": 10.0, "atk_speed": 0.9,
			"atk_range": 24.0, "move_speed": 12.5,
			"ability": {"name": "우세 보정", "description": "자신보다 체력 비율이 높은 상대에게 피해 +25%",
				"healthier_target_bonus": 0.25},
			"flavor": "기울어진 싸움일수록 그의 판결은 더 무거워진다",
		},
		"aquarius": {
			"name": "코일", "true_name": "시라 코일", "gender": "female",
			"epithet": "유량 조율사", "motif": "리본 안테나와 중계륜으로 부대 에너지 흐름을 되돌리는 관제사",
			"faction": "순환 관제소", "personality": "늘 한 수 뒤를 양보해 전체 흐름을 살리고 혼잡한 상황에서 오히려 차분하다",
			"silhouette": "긴 청록 리본 안테나와 원형 중계륜, 바람에 뜬 발끝",
			"weapon": "회류 지휘륜", "tier": 3, "role": R.SUPPORT, "element": E.AIR,
			"hp": 720.0, "atk": 48.0, "armor": 18.0, "atk_speed": 0.65,
			"atk_range": 22.0, "move_speed": 11.0,
			"ability": {"name": "에너지 재순환", "description": "출격할 때 에너지 2를 되돌려줌",
				"deploy_cost_refund": 2.0},
			"flavor": "막힌 흐름을 돌려 다음 사람의 길을 먼저 연다",
		},
		"cancer": {
			"name": "셸", "true_name": "세이블 오린", "gender": "female",
			"epithet": "심층 방벽", "motif": "접이식 외피 방패를 펼쳐 동료를 통째로 가리는 잠수 장비",
			"faction": "심층 구조대", "personality": "경계심이 강하지만 자신의 방벽 안에 든 사람은 끝까지 지킨다",
			"silhouette": "양옆으로 펼쳐지는 진남색 접이 방패와 둥근 잠수복, 낮은 중심",
			"weapon": "접이식 외피 방패", "tier": 1, "role": R.DEFENDER, "element": E.WATER,
			"hp": 880.0, "atk": 24.0, "armor": 38.0, "atk_speed": 0.7,
			"atk_range": 6.0, "move_speed": 10.0,
			"ability": {"name": "외피 전개", "description": "출격할 때 최대 체력의 25%만큼 보호막 획득",
				"deploy_shield_ratio": 0.25},
			"flavor": "먼저 마음을 닫고 그 안에 모두를 숨긴다",
		},
		"pisces": {
			"name": "다우스", "true_name": "다우스 매로우", "gender": "female",
			"epithet": "등화 저격수", "motif": "어번 코트와 장거리 소총으로 회랑의 유도등과 표적을 동시에 끊는 저격수",
			"faction": "소등 감시국", "personality": "가벼운 농담으로 긴장을 풀지만 누구보다 주변의 움직임을 세밀하게 읽는다",
			"silhouette": "어번 코트와 틸 조준광, 긴 소총을 낮게 겨눈 저격 자세",
			"weapon": "소광 장총", "tier": 1, "role": R.RANGER, "element": E.WATER,
			"hp": 270.0, "atk": 54.0, "armor": 3.0, "atk_speed": 0.85,
			"atk_range": 36.0, "move_speed": 11.0,
			"ability": {"name": "소광 위상", "description": "매 4번째 피격을 완전히 회피",
				"dodge_every_n_hit": 4},
			"flavor": "불이 꺼지는 순간에만, 그녀의 조준선이 선명해진다",
		},
		"scorpio": {
			"name": "벡스", "true_name": "벡스 콜더", "gender": "male",
			"epithet": "종결 추적자", "motif": "사슬침 도검으로 약해진 표적의 퇴로를 끊는 추적자",
			"faction": "흑점 집행부", "personality": "불필요한 고통을 싫어해 끝내야 할 순간을 절대 놓치지 않는다",
			"silhouette": "뒤로 길게 휘는 사슬 칼날과 검푸른 장갑, 표적 옆으로 파고든 측면 자세",
			"weapon": "사슬침 도검", "tier": 2, "role": R.STRIKER, "element": E.WATER,
			"hp": 630.0, "atk": 66.0, "armor": 16.0, "atk_speed": 1.0,
			"atk_range": 6.0, "move_speed": 16.0,
			"ability": {"name": "임계 절단", "description": "체력이 40% 이하인 상대에게 피해 +35%",
				"execute_threshold": 0.40, "execute_bonus": 0.35},
			"flavor": "끝나야 할 싸움에는 한 번의 정확한 마침표만 남긴다",
		},
	}


static func get_def(def_id: String) -> Dictionary:
	var t := table()
	assert(t.has(def_id), "unknown unit: %s" % def_id)
	return t[def_id]


static func ability(def_id: String) -> Dictionary:
	return get_def(def_id)["ability"]


static func ability_text(def_id: String) -> String:
	var a := ability(def_id)
	return "%s — %s" % [a["name"], a["description"]]


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


static func star_mult(star: int) -> float:
	return pow(STAR_SCALE, float(star - 1))
