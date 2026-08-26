class_name Defs
extends RefCounted

## 전역 열거형과 상수. 다른 모든 코어 스크립트가 참조한다.

## 역할은 상성만 담당한다. 시너지는 원소가 맡는다 — 둘이 같은 일을 하면 규칙만 늘고
## 플레이어가 기억할 것이 두 배가 된다.
enum Role { STRIKER, RANGER, DEFENDER, SUPPORT }

## 4원소. 관측체 12종이 원소마다 정확히 셋씩 나뉜다.
enum Element { FIRE, EARTH, AIR, WATER }

const ROLE_NAMES := {
	Role.STRIKER: "근접",
	Role.RANGER: "원거리",
	Role.DEFENDER: "방어",
	Role.SUPPORT: "지원",
}

const ELEMENT_NAMES := {
	Element.FIRE: "불",
	Element.EARTH: "흙",
	Element.AIR: "바람",
	Element.WATER: "물",
}

## 원소가 무엇을 해 주는지 한 줄로. 툴팁에 그대로 쓴다.
const ELEMENT_HINTS := {
	Element.FIRE: "타오른다 — 공격력",
	Element.EARTH: "단단하다 — 체력과 방어",
	Element.AIR: "빠르다 — 공격 속도",
	Element.WATER: "흐른다 — 회복",
}

# 전장 좌표계 --------------------------------------------------------------
## 단일 라인. 아군 코어(x=0) ~ 적 코어(x=FIELD_LEN).
const FIELD_LEN := 100.0
const SPAWN_OFFSET := 15.0   ## 코어에서 출격 지점까지의 거리

## 승리조건은 상대 관측 코어를 꺼뜨리는 것. 사도가 모두 쓰러지는 것은 그 자체로 패배가 아니라
## "코어가 무방비가 된 상태"다.
const CORE_HP := 520.0
const TICK := 1.0 / 30.0
const MAX_BATTLE_TIME := 55.0

## 교착 방지. 이 시각 이후 모든 피해가 초당 RAMPUP_PER_SEC 만큼 증폭된다.
const RAMPUP_START := 20.0
const RAMPUP_PER_SEC := 0.18

# 출격 코스트 --------------------------------------------------------------
## 시작 코스트를 낮게, 상한도 낮게 잡아야 "비싼 유닛부터"가 지배 전략이 되지 않는다.
## 대기 시간 동안 적이 먼저 전장을 점거하는 것이 그 선택의 대가다.
const START_COST := 3.0
const COST_REGEN := 0.9      ## LEVEL_BASE 레벨 기준 초당 충전량
const MAX_COST := 14.0       ## 모아뒀다 한 번에 쏟아내기를 제한한다

## 레벨이 오르면 큐 정원만 늘고 충전 속도가 그대로면, 뒤쪽 유닛이 전투 시간 안에
## 아예 못 나온다. 정원과 충전을 함께 올려야 레벨업이 끝까지 의미를 갖는다.
const LEVEL_BASE := 3
const COST_REGEN_PER_LEVEL := 0.09

static func cost_regen_for(level: int) -> float:
	return COST_REGEN + float(maxi(level - LEVEL_BASE, 0)) * COST_REGEN_PER_LEVEL

# 병종 순환 상성 ----------------------------------------------------------
## STRIKER ▶ RANGER ▶ DEFENDER ▶ STRIKER, SUPPORT는 중립.
const COUNTER_BONUS := 1.3
const COUNTER_PENALTY := 0.8

static func counter_mult(attacker_role: int, target_role: int) -> float:
	if attacker_role == Role.SUPPORT or target_role == Role.SUPPORT:
		return 1.0
	if attacker_role == target_role:
		return 1.0
	var beats := {
		Role.STRIKER: Role.RANGER,
		Role.RANGER: Role.DEFENDER,
		Role.DEFENDER: Role.STRIKER,
	}
	if beats.get(attacker_role, -1) == target_role:
		return COUNTER_BONUS
	return COUNTER_PENALTY

## 방어 수치를 데미지 배율로 환산. armor 100이면 딱 절반.
static func armor_mult(armor: float) -> float:
	return 100.0 / (100.0 + maxf(armor, 0.0))

## 아군은 x가 커지는 방향, 적은 작아지는 방향으로 전진한다.
static func team_dir(team: int) -> float:
	return 1.0 if team == 0 else -1.0

## 출격 지점.
static func spawn_x(team: int) -> float:
	return SPAWN_OFFSET if team == 0 else FIELD_LEN - SPAWN_OFFSET

## 팀의 코어 x 좌표.
static func core_x(team: int) -> float:
	return 0.0 if team == 0 else FIELD_LEN
