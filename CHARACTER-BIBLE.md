# 베스퍼 회랑 — 캐릭터 바이블

캐릭터 정본은 `game_state.gd`의 `ALL_CHARS`다. 이 문서는 도감, 일러스트, 스프라이트, 대사, 모집 연출이 같은 캐릭터를 가리키도록 묶는 제작 계약이다.

## 제작 원칙

- 전투 규칙이 먼저다. 캐릭터는 `type`, `cost`, `role`, `ORB_SKILLS`, `IMPRINTS`, `visual`을 가진 런타임 유닛이어야 한다.
- 카운터사이드식 라인 전투와 스도리카식 오브 커맨드는 조작 구조로만 흡수한다. 캐릭터 디자인, 명칭, 세계관은 베스퍼 회랑 고유 계약으로 유지한다.
- 일러스트는 카드/도감/메뉴용, 전장 판독은 픽셀 스프라이트 또는 절차적 실루엣용이다. 둘은 같은 색·마크·병종을 공유하되 서로를 대체하지 않는다.
- 캐릭터별 고유 필드: `true_name`, `epithet`, `rarity`, `faction`, `quote`, `bond_lines`, `visual_brief`.
- 일러스트 화풍은 [ART-illustration-style.md](ART-illustration-style.md), [ART-illustration-tells.md](ART-illustration-tells.md), `assets/pipeline/illustration/manifest.json`를 따른다. 소등사 키비주얼 품질이 하한선이며, 승인된 히어로 일러스트에서 카드 컷아웃과 얼굴을 파생한다.

## 현재 캐스트 8인

| 전투명 | 본명 | 등급 | 병종 | 소속 | 역할 |
| --- | --- | --- | --- | --- | --- |
| 진혼병 | 유현 | R | 스트라이커 | 장송 선봉대 | 저비용 근접 돌파, 첫 배치 압박 |
| 운구 소총수 | 백이현 | R | 레인저 | 운구 소대 | 중거리 기본 사격, 약한 적 정리 |
| 관지기 | 문가온 | SR | 디펜더 | 봉문 기사단 | 전열 고정, 라인 붕괴 방지 |
| 소등사 | 서리안 | SSR | 스나이퍼 | 소등 의식반 | 고가치 표적 처형, 후열 캐리 |
| 집전 의무관 | 한세라 | R | 서포터 | 집전 의무대 | 약한 아군 치유, 초반 유지력 |
| 사열 돌격수 | 류단 | SR | 스트라이커 | 사열대 | 고비용 돌파, 밀어내기 |
| 납골 방패병 | 오서린 | SSR | 디펜더 | 납골 성벽대 | 중장 저지, 최후 방어선 |
| 망종 중계사 | 차미루 | SR | 서포터 | 망종 통신반 | 치유/보조 피해/코스트 보조 |

## 캐릭터별 디자인 계약

### 진혼병 — 유현

- 핵심 감정: 가장 먼저 들어가고 이름은 나중에 불리는 사람.
- 전장 판독: 번트오렌지 선봉 마크 `I`, 낮고 빠른 근접 실루엣.
- 일러스트 브리프: 그을린 장송 코트, 번트오렌지 완장, 짧은 검은 머리, 팔뚝에 관 끈을 감은 근접 선봉.
- 오브 정체성: 1/2/4오브가 모두 정면 피해와 돌파로 이어진다.
- 아트 우선순위: R 기본 캐릭터라 카드 일러는 후순위, 전장 스프라이트는 초반 손패 판독 때문에 중상위.

### 운구 소총수 — 백이현

- 핵심 감정: 관을 끝까지 옮기듯 탄을 끝까지 보낸다.
- 전장 판독: 카키/딥틸 소총 실루엣, 긴 무기선.
- 일러스트 브리프: 무광 올리브 운구복, 긴 소총, 관 손잡이를 닮은 슬링, 낮은 모자챙, 피로한 눈.
- 오브 정체성: 약한 적을 정리하고 4오브에서 처형 조건을 가진다.
- 아트 우선순위: 초반 레인저라 얼굴/카드보다 64~128px 사격 애니 우선.

### 관지기 — 문가온

- 핵심 감정: 문을 닫는 사람이 가장 많은 이름을 구한다.
- 전장 판독: 슬레이트블루 방패, 넓은 어깨, 낮은 자세.
- 일러스트 브리프: 실버 머리, 코어 결정 방패, 차갑고 무광인 얼음 금속.
- 오브 정체성: 가드와 밀어내기. 전선을 멈추는 스킬군.
- 아트 상태: 카드/얼굴/스프라이트 연결됨. 새 캐스트의 스타일 기준 2번.

### 소등사 — 서리안

- 핵심 감정: 가장 사람에 가까운 망자라서 조준할수록 기억이 돌아온다.
- 전장 판독: 어번 다크레드, 긴 저격총, 후열 처형자.
- 일러스트 브리프: 어번 다크레드 머리, 장거리 소총, 낮은 숨, 멜랑콜리한 눈.
- 오브 정체성: 약한 적 처형. 4오브는 보스/정예 마무리 체감용.
- 아트 상태: 카드/얼굴/스프라이트 연결됨. `anchor_sniper.png`가 화풍 기준.

### 집전 의무관 — 한세라

- 핵심 감정: 살리지 못해도 혼자 꺼지게 두지 않는다.
- 전장 판독: 세이지민트/본화이트, 작은 성물, 후열 치유 마크 `+`.
- 일러스트 브리프: 본화이트 의무복, 세이지민트 숄, 작은 등유 성물, 피 묻은 장갑.
- 오브 정체성: 약한 아군 치유, 4오브에서 가드와 코스트 보조.
- 아트 우선순위: 초반 기본 보유 캐릭터라 도감 카드와 idle 스프라이트 우선.

### 사열 돌격수 — 류단

- 핵심 감정: 무덤도 돌격도 줄을 맞춰야 한다.
- 전장 판독: 낡은 사열 깃발, 번트레드 장식끈, 삼각 전진 실루엣.
- 일러스트 브리프: 재색 장교 코트, 짧은 창검, 기울어진 깃발, 흐트러지지 않는 행렬감.
- 오브 정체성: 진혼병보다 무겁고 강한 돌파와 밀어내기.
- 아트 우선순위: ST2 해금 캐릭터라 캠페인 중반 보상 연출용 카드 우선.

### 납골 방패병 — 오서린

- 핵심 감정: 본인이 무거운 게 아니라 든 이름들이 무겁다.
- 전장 판독: 본화이트 대형 납골함 방패, 느린 거인형 실루엣.
- 일러스트 브리프: 방패 안쪽의 이름표들, 슬레이트 금속, 느린 성채 같은 자세.
- 오브 정체성: 관지기보다 더 무겁고 오래 버티는 고비용 저지.
- 아트 우선순위: SSR이므로 모집/도감 키비주얼 우선. 방패 면적이 카드에서 읽혀야 한다.

### 망종 중계사 — 차미루

- 핵심 감정: 한 박자 늦지만 가장 먼 구조 신호를 먼저 듣는다.
- 전장 판독: 종 모양 안테나, 중계기 백팩, 세이지/머스터드 케이블.
- 일러스트 브리프: 낡은 리시버, 작은 종 안테나, 잡음 속 목소리를 찾는 표정.
- 오브 정체성: 치유, 보조 피해, 코스트 보조가 섞인 유틸 서포터.
- 아트 우선순위: SR 서포터. 스킬 발동 UI와 통신 이펙트 아이콘 우선.

## 일러스트 생산 우선순위

2026-07-15 기준으로 신규 생산은 전장 스프라이트보다 **소등사급 히어로 일러스트**를 먼저 잠근다. 전투 스프라이트는 이미 연결된 것은 유지하되, 새 캐릭터는 히어로 일러스트 승인 후 PixelLab 전투상태 파이프라인으로 내려간다.

정본 큐: `assets/pipeline/illustration/manifest.json`

| 캐릭터 | 일러스트 상태 | 다음 액션 |
| --- | --- | --- |
| 소등사 | `reference_ready` | 품질 앵커 유지 |
| 진혼병 | `hero_ready` | 승인 원화에서 카드 컷아웃과 얼굴 파생 |
| 집전 의무관 | `hero_needed` | 진혼병 후 히어로 후보 생성 |
| 운구 소총수 | `hero_needed` | 스타터 3인 완성용 히어로 후보 생성 |
| 사열 돌격수 | `hero_needed` | 중반 보상 카드용 |
| 납골 방패병 | `hero_needed` | SSR 모집 키비주얼 우선 |
| 망종 중계사 | `hero_needed` | SR 서포터 키비주얼 |
| 관지기 | `legacy_connected_review_needed` | 소등사 기준으로 유지/리터치 재평가 |

## 전투 스프라이트 상태

나머지 6명은 임시 낙서 PNG를 쓰지 않고, 확정 에셋 파이프라인인 `pixellab_combat_state` 큐를 가진다. PixelLab에서 `create_character → create_character_state → animate_character(mode=v3)` 순서로 전투 스프라이트를 만든 뒤 `pixellab_assemble.py`로 `assets/sprites/<slug>_pl`에 조립한다.

| 캐릭터 | 전장 slug | 파이프라인 | 상태 |
| --- | --- | --- | --- |
| 진혼병 | `jinhonbyeong` | `pixellab_combat_state` | `ready` |
| 운구 소총수 | `ungoo_rifle` | `pixellab_combat_state` | `ready` |
| 관지기 | `gwanjigi_pl` | `pixellab_combat_state` v4 anime refresh | `ready` |
| 소등사 | `sodeungsa_pl` | PixelLab 검증 자산 | 연결 완료 |
| 집전 의무관 | `jipjeon_medic` | `pixellab_combat_state` | `ready` |
| 사열 돌격수 | `sayeol_striker` | `pixellab_combat_state` | `ready` |
| 납골 방패병 | `napgol_defender` | `pixellab_combat_state` | `ready` |
| 망종 중계사 | `mangjong_relay` | `pixellab_combat_state` | `ready` |

전투 스프라이트 큐 6명은 모두 게임 런타임에 연결됐다. 관지기와 소등사는 `runtime_refreshes`로 별도 리터치가 완료됐고, 카드/얼굴 일러스트 리터치는 별도 단계로 남긴다. 망종 중계사는 PixelLab 크레딧 부족으로 애니메이션만 로컬 결정 프레임으로 임시 완성됐으므로, 크레딧 충전 후 PixelLab 애니메이션 재생성이 우선 교체 대상이다.

## 공통 생성 프롬프트 뼈대

아래 문장은 캐릭터별 `visual_brief` 뒤에 붙인다. 실제 생성 시 `assets/art/anchor_sniper.png`를 화풍 레퍼런스로 주입한다.

```text
matte textured gouache, visible brushstrokes and canvas grain, muted desaturated colors, gritty hand-painted; NOT glossy, NOT shiny, NOT clean CG, NOT 3D render, NOT neon, NOT bright glowing.
full-body, head to toe including feet, standing natural pose, isolated on plain solid pure white background, no scenery, no gradient, no floor shadow.
single cool key light from upper left, weak fill only, rich navy/plum shadows, varied line weight, lost-and-found edges, face and eyes crisp and clean, body and outfit remain painterly.
detail hierarchy: face, hands, signature weapon/relic sharpest; large clothing areas simplified with drybrush texture and quiet negative space.
do NOT copy the reference character, pose, palette, clothing, or weapon; use only the painterly gouache feeling.
```
