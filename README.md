# 베스퍼 회랑 (THE VESPER CORRIDOR)

다크 SF 사이드뷰 **단일 라인 실시간 전략 RPG** (Godot 4.6). 카운터사이드식 라인 전투에 스도리카식 오브 커맨드를 결합한 PvE 라인 배틀러.

- 기획: [DESIGN.md](DESIGN.md) · 세계관: [WORLD.md](WORLD.md) · 캐릭터 바이블: [CHARACTER-BIBLE.md](CHARACTER-BIBLE.md) · 에셋 큐: [ASSET-PIPELINE-QUEUE.md](ASSET-PIPELINE-QUEUE.md) · 출시 후보 기준: [RELEASE-CANDIDATE.md](RELEASE-CANDIDATE.md) · 모바일 메타: [MOBILE-META-SPEC.md](MOBILE-META-SPEC.md) · 피드백 연출: [PRESENTATION-SPEC.md](PRESENTATION-SPEC.md) · 전장 비주얼: [BATTLEFIELD-VISUAL-SPEC.md](BATTLEFIELD-VISUAL-SPEC.md)
- 현재 시스템 계약: [CORRIDOR_GAME_SPEC.md](CORRIDOR_GAME_SPEC.md) · [LINE-BATTLER-SPEC.md](docs/LINE-BATTLER-SPEC.md) · 단일 원정대와 실시간 사도 출격을 우선한다.
- 현재 빌드: **원정 브리핑 → 3명 후보 드래프트로 4인 스쿼드 구성 → 회랑 분기 → 실시간 출격 카드 전투 → 유물/휴식 → 5층 보스**가 실제 실행된다. 이전 8인 매치와 메타 화면은 레거시 보존용으로 비활성화되어 있다.
- 시그니처 메커닉 **실시간 출격** = 0에서 차오르는 코스트를 어디에 먼저 쓸지 결정하는 도박.

## 실행
```
godot --path .
```
- **메인 씬 = `scenes/main_flow.tscn`** — 회랑 지도와 기존 라인배틀러 준비/전투가 한 런으로 연결된다.
- 전투는 Godot `CombatSim`이 결정론적으로 처리하고, `BattlePresenter`가 이동·공격·피격·사망을 표현한다.
- 렌더러는 **Compatibility**를 사용해 웹에서 가볍게 실행되며, 픽셀 아트/절차적 전장 표현을 유지한다.
- 처음 한 번은 임포트: `godot --headless --path . --import`

## 현재 구현
- 단일 라인: 좌 **등불함** vs 우 **매듭**. 한쪽 HP 0이면 결판.
- **코스트**는 전투 시작 시 0이며 자동으로 차오른다. 충전된 순간 하단 카드를 눌러 직접 출격한다.
- **긴 단일 전선**: 논리 거리 280의 전장을 카메라로 좌우 스크롤하며 전선과 적 증원을 읽는다.
- **엘리트/보스 패턴**: 검은 파동과 매듭 재생의 예고를 보고 출격 코스트를 남겨 둔다.
- **유물**: 전투 보상에서 하나를 선택해 이번 런의 체력·공격 속도·공격력을 강화한다.
- **병종 상성**: 스트라이커▶레인저▶디펜더▶스나이퍼▶스트라이커(+서포터 힐).
- **4인 드래프트 원정대 + 실시간 출격 카드**: 매번 제시되는 3명 중 1명을 네 번 고른 뒤 전투 중 하단 카드로 코스트가 찬 사도를 직접 출격한다.
- **긴 단일 전선**: 코어 간 논리 거리를 늘려 초반 이동·출격·교전 시간을 확보한다.
- **지휘기**: 전투 중 한 번 적 전선을 직접 타격하는 보조 개입 수단이다.
- **5층 회랑**: 분기·보급·이벤트·휴식·엘리트 노드를 지나 보스에 도달한다.
- **캐릭터 계약**: 8명 전원이 본명, 이명, 등급, 소속, 대사, 인연 대사, 일러스트 브리프, 전장 비주얼 마크를 가진다.
- **이번 제출 범위**: 현재 런 안에서만 유지되는 4인 원정대와 유물 성장. 상점·가챠·계정 메타는 비활성 레거시다.
- **일러스트 기준**: 신규 캐릭터는 전투 스프라이트보다 소등사(`assets/art/anchor_sniper.png`, `card_sodeungsa.png`, `face_sodeungsa.png`)급 히어로 일러스트를 먼저 잠근다. 정본 큐는 `assets/pipeline/illustration/manifest.json`.
- **프레젠테이션 피드백**: 공용 페이드 전환, 설정 연동 절차적 효과음, 보상/확인/전투 승패/배치/공격/오브/소신/지휘기 피드백 로그, 전투 결과 전술 등급/XP 라인.
- **전장 비주얼 계약**: 스프라이트가 없는 유닛도 캐릭터/적별 절차적 실루엣, 무기선, 배지, HP바, 공격/사망 피드백을 가진다.
- **승/패 + 사인(死因) 진단**: 끝나면 한 줄로 패인 진단(코스트 미사용/디펜더 부재/과한 소신 등).

## 조작
- 회랑 지도에서 노드 또는 분기 버튼을 선택한다.
- 첫 전투 전에 후보 3명 중 1명씩 네 번 골라 원정대 4명을 만들고 `전투 시작`을 누른다.
- 전투 중 커서를 화면 좌우 끝으로 가져가 전장을 살피고, 하단 사도 카드를 눌러 코스트를 소비해 실시간으로 출격한다. `지휘기`와 배속 버튼도 사용할 수 있다.
- 전투 결과 후 유물 하나를 선택하거나, 휴식처에서 체력 회복/선봉 교대를 선택한다.

## 검증
```bash
godot --headless --path . res://legacy/vesper/combat_rules_test.tscn
godot --headless --path . res://legacy/vesper/imprint_rules_test.tscn
godot --headless --path . res://legacy/vesper/campaign_flow_test.tscn
godot --headless --path . res://legacy/vesper/meta_systems_test.tscn
godot --headless --path . res://legacy/vesper/ops_systems_test.tscn
godot --headless --path . res://legacy/vesper/system_shell_test.tscn
godot --headless --path . res://legacy/vesper/presentation_system_test.tscn
godot --headless --path . res://legacy/vesper/combat_audio_test.tscn
godot --headless --path . res://legacy/vesper/battlefield_visual_test.tscn
godot --headless --path . res://legacy/vesper/character_identity_test.tscn
godot --headless --path . res://legacy/vesper/scene_smoke_test.tscn
godot --headless --path . --script res://test/vesper_vertical_slice_test.gd
for stage in 0 1 2 3 4; do
  godot --headless --fixed-fps 240 --path . res://legacy/vesper/balance_sim.tscn -- --stage "$stage"
done
```

## 일러스트 연동 (하이브리드 — 일러는 메타, 전장은 픽셀)
캐릭터 일러스트는 전장(픽셀 유닛) 밖 + 배치 순간에 나옴. 현재 연결된 곳:
- **배틀 덱 카드 초상화** — 하단 소환 카드에 캐릭터 얼굴 크롭(`assets/art/face_*.png`). 전투 중에도 일러가 보임.
- **도감/수집** — 배틀 상단 `도감` 버튼 → 캐릭터 카드 화면([roster.tscn](roster.tscn)). `GameState.ALL_CHARS`를 읽어 8명 전체를 표시하고, 최종 카드가 있는 캐릭터는 카드 에셋, 아직 생산 대기인 캐릭터는 시그니처 색·마크 플레이스홀더와 잠금 슬롯·"수집 N/M"을 보여준다.
- **캐릭터 상세** — 도감 카드 탭 → 카드 일러 또는 시그니처 플레이스홀더 + 본명·전투명·이명·등급·소속·병종·코스트·역할·기록·오브 스킬·일러스트 브리프.
- 에셋: 풀 일러 `assets/art/sodeungsa_sniper.png`·`gwanjigi_defender.png`(원본), 카드 `card_*.png`, 얼굴 `face_*.png`. 신규 캐릭터는 `assets/pipeline/illustration/manifest.json`의 소등사급 품질 게이트를 먼저 통과한 뒤 PixelLab 전투상태 파이프라인(`create_character → create_character_state → animate_character`)으로 내려간다. 전장 발주 큐는 `assets/pipeline/pixellab/manifest.json`, 실행 순서는 `PIXELLAB-RUNBOOK.md`. 스타일 앵커 `anchor_sniper.png`.
- 캐릭터 정본: [CHARACTER-BIBLE.md](CHARACTER-BIBLE.md). 화풍/파이프라인 정본: [ART-illustration-style.md](ART-illustration-style.md), [ART-illustration-tells.md](ART-illustration-tells.md).

## 전장 스프라이트 (PixelLab — 실제 게임에서 보이는 것)
전장 유닛 = **PixelLab 전투상태 파이프라인으로 만든 애니 도트 스프라이트**(일러와 같은 캐릭터·색). HD-2D 조명 받는 빌보드.
- 에셋: `assets/sprites/<slug>_pl/walk_*.png`, `aim_*.png`, `attack_*.png`, `idle_0.png` (PixelLab, side/east 기준). 반대 방향은 엔진 flip.
- 연동: `unit3d.gd`가 `def`에 `sprite` 폴더 있으면 **AnimatedSprite3D**(walk=이동/idle=정지/aim=교전 대기/attack=공격, billboard FIXED_Y, nearest, alpha-scissor, shaded) 사용, 없으면 QuadMesh 플레이스홀더.
- 현재 스프라이트: 소등사(어번/틸 레인저), 집전 의무관(세이지 숄/등유 성물 힐러), 진혼병(검은 장송 코트/번트오렌지 근접 선봉), 관지기(은발/방패 디펜더). 적·나머지 아군은 아직 플레이스홀더 도형.
- 생성 노하우: `create_character`로 원본 승인 → `create_character_state`로 저자세 조준/저자세 러닝 베이스 생성 → `animate_character(mode=v3, directions=["east"])`로 run/aim/attack 생성 → `pixellab_assemble.py`로 `<slug>_pl` 조립. PixelLab backblaze URL은 `curl -A "Mozilla/5.0"`로 받아야 함(기본 UA 403).
- `unit3d.gd`: 동적 프레임 수 자동 감지 + **attack 애니**(교전 시 0.55초 재생) 지원. 이동=walk / 정지=idle / 공격=attack.
- 시도했으나 실패: AutoSprite(일러→애니, 입력 무관 실패), 일러 컷아웃 스켈레탈 리깅(= "일러 변형"이라 부적합). 진짜 애니-Spine은 애니메이터 외주 영역.

## 남은 완성 폴리시
- 적·나머지 아군 플레이스홀더 스프라이트 교체.
- 새 6인 카드 일러스트/얼굴/스프라이트 생산.
- 오디오, 전환 연출, UI 세부 폴리시.
- 수치 밸런스 반복 조정과 변종 도전 난이도 확장.
