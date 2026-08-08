# 베스퍼 회랑 — 출시 후보 기준

## 플레이 가능한 핵심 동사

플레이어는 8인 스쿼드를 편성하고, 4장 순환 손패·오브 커맨드·배치 위치·소신·등불함 지휘기를 사용해 좌측 등불함을 지키며 우측 매듭을 파괴한다. 더 좋은 플레이는 망자 소모와 후퇴를 줄이고, 스테이지 규칙 태그에 맞춰 손패/오브/배치를 읽는 것이다.

## 출시 후보에 포함된 루프

- 타이틀에서 새 게임/이어하기 진입
- 메인화면에서 전투, 편성, 모집, 상점, 채팅, 도감, 미션, 우편, 성장, 설정, 공지, 가이드, 크레딧 진입
- 회랑 맵에서 스테이지 선택
- 편성 화면에서 8인 스쿼드와 각인 선택
- 전투에서 손패, 배치, 오브, 소신, 지휘기, 후퇴 사용
- 결과 화면에서 사인 진단, 보상, 다음 회랑 이동
- 5스테이지 완주 후 엔딩 문구와 변종 도전 진입
- 최근 결과 기록 저장과 회랑 맵 표시
- 출석 보상, 모집권/루멘, 뽑기 천장, 상점 목업, 로컬 채팅 저장
- 우편, 일일/업적 미션, 계정 레벨, 캐릭터 레벨업, 회랑 패스 무료 트랙
- 설정, 로컬 공지 읽음 상태, 튜토리얼 재진입, 약관 확인, 크레딧/법적 고지
- 공용 페이드 전환, 설정 연동 효과음 피드백, 전투 이벤트 사운드 매핑, 전투 결과 전술 평가/XP 표시
- 캐릭터/적별 전장 비주얼 계약, 절차적 실루엣, HP바, 공격/사망 피드백
- 8명 캐릭터 본명/이명/소속/대사/인연 대사/일러스트 브리프/최종 에셋 또는 PixelLab 전투상태 파이프라인 큐/도감 상세 계약

## 런타임 계약

- 캐릭터/스킬/각인/스테이지/함선 규칙은 `game_state.gd` 데이터 계약이 원본이다.
- 캐릭터 서사와 아트 생산 계약은 `game_state.gd`의 캐릭터 필드와 `CHARACTER-BIBLE.md`가 맞물려야 한다.
- 전투 씬은 계약을 읽어 UI, 해금, 손패, 오브, 지휘기, 최후 신호를 구성한다.
- QA 봇은 `balance_sim.gd`에서 실제 해금 상태, 배치 우선순위, 오브 사용을 재현한다.
- 테스트는 저장 파일을 오염시키지 않도록 `GameState.test_mode_no_save`를 사용한다.

## 필수 회귀 게이트

```bash
godot --headless --path . res://combat_rules_test.tscn
godot --headless --path . res://imprint_rules_test.tscn
godot --headless --path . res://campaign_flow_test.tscn
godot --headless --path . res://meta_systems_test.tscn
godot --headless --path . res://ops_systems_test.tscn
godot --headless --path . res://system_shell_test.tscn
godot --headless --path . res://presentation_system_test.tscn
godot --headless --path . res://combat_audio_test.tscn
godot --headless --path . res://battlefield_visual_test.tscn
godot --headless --path . res://character_identity_test.tscn
godot --headless --path . res://scene_smoke_test.tscn
for stage in 0 1 2 3 4; do
  godot --headless --fixed-fps 240 --path . res://balance_sim.tscn -- --stage "$stage"
done
```

## 출시 후보 밖으로 남긴 것

- 적과 일부 아군의 플레이스홀더 스프라이트 교체
- 새 6인 최종 카드 원화/전장 스프라이트 생산과 컷아웃
- 오디오와 전환 연출
- 세부 수치 밸런스 반복
- 변종 도전 난이도/규칙 세트 확장
- 실제 결제/광고 SDK, 영수증 검증, 채팅 서버/신고/차단, 서버 우편/미션 운영툴
- 웹/앱 패키징과 플랫폼별 입력 QA
