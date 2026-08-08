# 베스퍼 회랑 — 프레젠테이션/피드백 계약

## 목적

전투 코어와 모바일 메타를 “게임처럼” 느끼게 하는 공용 피드백 레이어다. 실제 상용 오디오 리소스와 컷신 제작 전에도, 런타임 계약·저장·테스트를 먼저 닫는다.

## 공용 피드백

- 원본 계약: `GameState.FEEDBACK_EVENTS`
- 이벤트: 화면 전환, 확인, 보상, 전투 승리, 전투 패배, 배치, 근접/원거리/방패 타격, 치유, 강타, 코어 피격, 유닛 소멸, 오브 발동, 소신, 지휘기, 최후 신호, 후퇴, 오류
- 각 이벤트는 라벨, 피치, 길이, 플래시 색을 가진다.
- `GameState.emit_feedback(id, payload)`는 피드백 로그를 남기고 설정의 마스터/SFX 볼륨이 0보다 크면 짧은 절차적 톤을 재생한다.

## 화면 전환

- `GameState.goto(scene_path)`는 직접 `change_scene_to_file`을 호출하지 않고 공용 페이드 전환을 거친다.
- `reduced_motion` 설정이 켜져 있으면 즉시 전환한다.

## 전투 결과 연출

- `GameState.compose_battle_feedback(win, metrics)`가 전투 평가 원본이다.
- 입력: 승패, 생존 시간, 소신 횟수, 소실 망자 수, 등불함 HP, 패인 문구
- 출력: 전술 등급, 등급 설명, 생존율, XP/패스 XP 표시 라인
- 결과 화면은 이 계약을 읽어 승패 제목, 전술 평가, 사인/패인, XP 라인, 보상 라인을 표시한다.

## 전투 이벤트 사운드

- `battle3d._combat_audio()`가 전투 중 사운드 이벤트를 라우팅한다.
- 이벤트별 쿨다운으로 공격음이 과도하게 겹치지 않게 한다.
- 자동 시뮬레이션 모드에서는 사운드 이벤트를 발생시키지 않는다.
- 공격 형태 매핑:
  - `heal` → `combat_heal`
  - `rifle`/`sniper`/`core` → `attack_ranged`
  - `shield`/`ossuary`/`tank` → `attack_guard`
  - 그 외 → `attack_melee`

## 테스트

```bash
godot --headless --path . res://presentation_system_test.tscn
godot --headless --path . res://combat_audio_test.tscn
godot --headless --path . res://scene_smoke_test.tscn
```
