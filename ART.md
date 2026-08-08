# 아트 디렉션 — 베스퍼 회랑

> 세계관 비주얼은 [WORLD.md](WORLD.md)의 "차가운 병적 청록 + 호박색 등불" 계승. 이 문서는 **스프라이트 제작 규격**.

## 확정 사양 (전 유닛 공통)
| 항목 | 값 | PixelLab 파라미터 |
|---|---|---|
| 비율 | **5등신 스타일라이즈드** | proportions=heroic/stylized, 설명에 "5 heads tall, stylized" 명시 |
| 해상도 | **~64px 캐릭터** | size=64 |
| 외곽선 | **다크 셀렉티브 아웃라인** | outline="selective outline" |
| 셰이딩 | **기본(약한 베이크)** | shading="basic shading" |
| 디테일 | 중간 | detail="medium detail" |
| 뷰 | **side view** | view="side" |
| 방향 | **한 방향 생성 + Godot flip_h로 반대** (8방향 불필요 → 생성량 절약) | n_directions 최소 / 표준 모드 |
| 모드 | **standard humanoid**(비율 제어 위해) 우선 → 결과 보고 필요 시 v3 승급 | mode="standard" |

> HD-2D라 **베이크 셰이딩은 약하게**(basic) — 입체감의 절반은 게임 안 3D 조명(등불 amber / 매듭 cyan)이 입힌다. 너무 진한 셰이딩은 조명과 충돌.

## 팔레트
- 베이스: **차가운 청록/시안 + 호박색 등불 대비.** 채도 낮게, **네온·원색 금지**(무이모지 톤 일치).
- **팀 구분**: 아군 = 호박빛 림 + 깔끔한 군장(되살아난 병사). 적 = 청록·유기적·부패(블룸 변종).
- **병종 구분 = 실루엣 우선** + 액센트색: 스트라이커(근접·각진 무기), 레인저(총·세장), 디펜더(방패·육중), 서포터(등불/드론).

## 아군 vs 적 — 형태가 다르다
- **아군 10종 = 휴머노이드 병사 + 메카.** 메카(강습/중장갑/영구차)는 더 육중한 비율(heavy/heroic), 휴머노이드 베이스 위 중장갑.
- **적 = 변종/괴수(휴머노이드 아님).** 급조 항체·포자·거대 변종·비행 드론·보스 = 크리처(PixelLab quadruped 템플릿 또는 커스텀 크리처). **배교 항체만 인간형**(타락한 옛 운구인 = 우리의 거울).

## 유닛당 애니메이션 세트
- **idle(호흡), walk, attack** 필수. (+ 여유 되면 hit/death)
- side view, 한 방향. Godot AnimatedSprite2D/빌보드에 프레임 연결, 반대 방향은 flip.

## 일관성 규칙
- 전 유닛 **동일 비율·외곽선·셰이딩·팔레트·64px 그리드.**
- **실루엣만으로 병종 구분**되게. 팀은 림/색온도로.
- 생성 시 같은 description 프리픽스(스타일·비율·외곽선·팔레트) 고정 + 유닛별 차이만 변경 → 톤 통일.

## 생성 순서 (PixelLab)
1. **테스트 1종**(운구 소총수 or 관지기)으로 룩·비율 확정 ← *먼저*
2. 아군 휴머노이드 4종 → 3. 메카 3종 → 4. 적 크리처 → 5. 보스 → 6. 유닛별 애니(walk/idle/attack)
- 각 단계 후 Godot 빌보드에 넣어 눈으로 확인하고 다음 단계.

## 공통 프롬프트 프리픽스(초안)
`dark sci-fi, 5 heads tall stylized proportions, ~64px, dark selective outline, basic shading, muted cold teal/cyan palette with amber rim light, grim military, side view —` + (유닛별 설명)
