# 베스퍼 회랑 — 전장 비주얼 계약

## 목적

전투에서 아직 전용 도트 스프라이트가 없는 유닛도 “임시 도형”이 아니라 캐릭터/적별 역할과 정체성이 읽히는 런타임 자산으로 보이게 한다.

## 원본 계약

- 아군: `GameState.CHARACTER_BATTLE_VISUALS`
- 적: `GameState.ENEMY_BATTLE_VISUALS`
- 역할 기본값: `GameState.TYPE_BATTLE_VISUALS`

각 계약은 다음 필드를 가진다.

- `shape`: blade, rifle, shield, sniper, relic, banner, ossuary, relay, claw, spore, tank, ash
- `primary`: 몸체 색
- `accent`: 무기선/배지/HP바 색
- `weapon`: 무기선 길이
- `height`: 전장 판정과 HP바 기준 높이
- `mark`: UI/후속 배지용 짧은 식별자

## 런타임 적용

- `GameState._with_imprint()`는 캐릭터 정의에 `visual`을 주입한다.
- `battle3d._with_unit_visual()`은 적 스폰 시에도 `visual`을 주입한다.
- `unit3d.gd`는 스프라이트가 없는 유닛을 계약 기반 절차적 텍스처로 그리고, 스프라이트가 있는 유닛에도 HP바/배지/무기선 레이어를 얹는다.

## 전투 피드백

- 공격 시 짧은 트레이서/베기 선을 생성한다.
- 사망 시 소형 파편 스파크를 생성한다.
- 자동 시뮬레이션 모드에서는 연출 생성을 생략해 밸런스 검증 성능을 보존한다.

## 테스트

```bash
godot --headless --path . res://battlefield_visual_test.tscn
godot --headless --path . res://scene_smoke_test.tscn
```
