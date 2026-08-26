# 베스퍼 회랑 (THE VESPER CORRIDOR)

다크 SF 사이드뷰 **단일 라인 실시간 전략 RPG** (Godot 4.6). 카운터사이드식 라인 전투에 스도리카식 오브 커맨드를 결합한 PvE 라인 배틀러.

- 기획: [DESIGN.md](DESIGN.md) · 세계관: [WORLD.md](WORLD.md) · 캐릭터 바이블: [CHARACTER-BIBLE.md](CHARACTER-BIBLE.md) · 에셋 큐: [ASSET-PIPELINE-QUEUE.md](ASSET-PIPELINE-QUEUE.md) · 출시 후보 기준: [RELEASE-CANDIDATE.md](RELEASE-CANDIDATE.md) · 모바일 메타: [MOBILE-META-SPEC.md](MOBILE-META-SPEC.md) · 피드백 연출: [PRESENTATION-SPEC.md](PRESENTATION-SPEC.md) · 전장 비주얼: [BATTLEFIELD-VISUAL-SPEC.md](BATTLEFIELD-VISUAL-SPEC.md)
- 현재 시스템 전환 계약: [LINE-BATTLER-SPEC.md](docs/LINE-BATTLER-SPEC.md) · 오토배틀러 메타보다 실시간 소환·전선·오브 판단을 우선한다.
- 현재 빌드: **타이틀 → 메인화면 → 회랑 맵 → 8인 편성·각인 → 전투 → 결과/보상/엔딩 → 변종 도전**과 **모집/상점/채팅/미션/우편/성장/패스/설정/공지/가이드/크레딧**까지 연결.
- 시그니처 메커닉 **소신(燒身)** = 등불함 HP(=망자의 영혼)를 태워 코스트를 즉시 충전하는 도박.

## 실행
```
godot --path .
```
- **메인 씬 = `scenes/main_flow.tscn`** — 타이틀·브리핑에서 `legacy/vesper/battle3d.tscn` HD-2D 전투로 진입한다.
- 전투 씬은 픽셀 빌보드 유닛 + 디오라마 회랑 + 블룸/볼류메트릭 안개/피사계심도/실시간 그림자를 사용한다.
- 렌더러: **Forward+**(네이티브, 풀 HD-2D). **웹빌드는 Compatibility로 자동 다운그레이드**(블룸·그림자·안개는 나오고 피사계심도/볼류메트릭만 생략 = HD-2D 라이트).
- 2D 원형(MVP1)은 `main.tscn`(`main.gd`/`unit.gd`)에 **레퍼런스로 보존**. HD-2D 룩 테스트 씬은 `hdtest.tscn`.
- 처음 한 번은 임포트: `godot --headless --path . --import`

## 현재 구현
- 단일 라인: 좌 **등불함** vs 우 **매듭**. 한쪽 HP 0이면 결판.
- **코스트** 자동 리젠 + **백투더월**(열세 시 충전 가속).
- **소신** 버튼: 등불함 HP 일부를 태워 코스트 +3. **각명 명단에서 이름이 지워짐**. 과하면(<22%) **재의 사도**가 아군에게 등을 돌림.
- **최후 신호**: 등불함 HP 25% 이하에서 1회 해금. 2.5초 반응 유예 후 버튼을 누르면 적 전선을 밀어내고 등불함을 4초간 보호.
- **★각인**: 최초 클리어 보상으로 캐릭터 슬롯을 열고, 상성·위기·편성 조건이 다른 두 효과 중 하나를 선택. 해금 후 교체는 무료.
- **병종 상성**: 스트라이커▶레인저▶디펜더▶스나이퍼▶스트라이커(+서포터 힐).
- **8인 스쿼드 + 4장 순환 손패**: 쓴 카드는 뒤로 빠지고 다음 계약이 들어온다.
- **배치 위치 지정**: 전선이 밀릴수록 배치 가능 영역이 앞으로 확장된다.
- **2행 오브 보드**: 같은 역할 인접 오브를 1/2/4개 골라 캐릭터별 스킬을 발동한다.
- **함선/지휘부 계약**: 등불함 포격, 리더 비용 감소, 최후 신호가 데이터 계약으로 분리돼 있다.
- **5스테이지 회랑 + 완주 후 변종 도전**: 스테이지 규칙 태그와 최근 결과 기록을 저장한다.
- **캐릭터 계약**: 8명 전원이 본명, 이명, 등급, 소속, 대사, 인연 대사, 일러스트 브리프, 전장 비주얼 마크를 가진다.
- **모바일 메타**: 메인화면, 출석 보상, 루멘/골드/모집권, 모집/천장, 상점 수익구조 목업, 로컬 채팅, 우편, 일일/업적 미션, 계정 레벨, 캐릭터 성장, 회랑 패스, 설정, 공지, 가이드, 크레딧/법적 고지.
- **일러스트 기준**: 신규 캐릭터는 전투 스프라이트보다 소등사(`assets/art/anchor_sniper.png`, `card_sodeungsa.png`, `face_sodeungsa.png`)급 히어로 일러스트를 먼저 잠근다. 정본 큐는 `assets/pipeline/illustration/manifest.json`.
- **프레젠테이션 피드백**: 공용 페이드 전환, 설정 연동 절차적 효과음, 보상/확인/전투 승패/배치/공격/오브/소신/지휘기 피드백 로그, 전투 결과 전술 등급/XP 라인.
- **전장 비주얼 계약**: 스프라이트가 없는 유닛도 캐릭터/적별 절차적 실루엣, 무기선, 배지, HP바, 공격/사망 피드백을 가진다.
- **승/패 + 사인(死因) 진단**: 끝나면 한 줄로 패인 진단(코스트 미사용/디펜더 부재/과한 소신 등).

## 조작
- 하단 **덱 버튼** 클릭 → ST4 이후에는 전장 왼쪽 빛 영역을 클릭해 배치 위치 지정.
- **오브** → 같은 색 인접 칸을 1/2/4개 선택 후 발동.
- **소신** → 등불함 HP를 태워 코스트 확보(불리할 때 역전 카드).
- **등불함 포격** → 적 광역 포격(쿨 18초). 위기 시 같은 버튼이 1회성 **최후 신호**로 전환.

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
