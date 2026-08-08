# 일러스트 — AI 티 제거 처방 (AI vs 사람 그림)

> 핵심 결론: **텍스트→이미지만으로는 ~70점이 한계.** 균일 선·균일 디테일은 모델 prior라 프롬프트로 확률만 기울임. 결정적 30%는 **레퍼런스 주입(img2img) + 사람 페인트오버(5~10분, AI 티의 80% 제거) + 마스크 기반 불균질 후처리**가 필요. 모델(Seedream/Flux/nano) 바꿔도 근본 동일.

## 결정적 AI 텔 (우선순위)
1. **위계 부재**(최악): 선 두께 균일 + 얼굴·총·옷·배경 동일 디테일 밀도. 사람은 한 곳에 몰고 나머지를 비움.
2. **lost-and-found 엣지 실종**: 초점/주변이 똑같이 또렷or흐림 → 스티커처럼 뜸.
3. **광원 논리 붕괴 + AO 떡칠**: 부위별 광원 따로 + 모든 틈 균일 반음영 → 3D 렌더 티.
4. **form-following 부재 + 매끈 미드톤**: 붓터치가 곡면을 안 감쌈, 터미네이터가 그라데이션.
5. **죽은 눈 + 왁스 피부**: 캐치라이트 정중앙 대칭, 서브서피스 없음(모에에서 제일 빨리 들킴).
6. **기능 없는 그리블 + 의사글자 깨짐**.
7. **정중앙 대칭 안전 풀샷 구도**(콘트라포스토·오프센터·시선유도선 없음).
8. **틸&오렌지 필터 + 순검정 암부**(색온도 시프트가 아니라 필터 한 장).

## 프롬프트 금지어 (AI 티 유발 주범)
- `highly detailed / intricate / hyperdetailed / extremely detailed everywhere` — 균질 디테일 카펫 1순위 금지. "detailed"는 부위 한정으로만.
- `8k / 4k / ultra sharp / sharp focus(전역) / everything in focus`
- `clean lines / crisp lineart / fine line / precise linework`
- `cel shading / flat colors`
- `cinematic lighting / dramatic lighting / volumetric / studio lighting / softbox`
- `teal and orange / complementary / color grading / vibrant / saturated(전역)`
- `glossy / dewy / porcelain skin / flawless / smooth / airbrush / blended shading`
- `octane / unreal engine / ray tracing / ambient occlusion / photorealistic / 3D render`
- `symmetrical / centered / front view / looking at viewer / full body / full shot`
- `dynamic pose(단독) / holding a rifle(막연)` — 체중·비틀림·쥐는 방식 명시 필요
- `mechanical parts / tubes / wires / panel lines / greebles` 나열
- `masterpiece / best quality / perfect hands / perfect anatomy` 부스터 스팸 → 평균 중앙값으로 수렴, 죽은 표현. 총기 각인 글자 요구도 금지.

## 프롬프트에 넣을 것
- **광원 1개 못박기**: 방향·색온도·강도 서열, 보조광은 weak. 그림자 방향 일관.
- **엣지 위계**: 눈·트리거손만 hard, 나머지 soft→lost.
- **라인 웨이트 변조**: 접촉/그림자부 굵게, 빛받는 능선 얇게/끊김.
- **디테일 위계 + 쉼**: 얼굴·총 볼트에만 디테일, 나머지 단순·여백. dense→empty→accent 리듬.
- **form-following 붓터치 + 면 처리**: 곡면 감싸는 방향, 터미네이터·각진 면.
- **마티에르 불균질**: 하이라이트 impasto / 미드톤 drybrush / 섀도 글레이즈.
- **눈 생기**: 비대칭 캐치라이트, 하안검 젖은 반사, 초점 흐린 시선, 한쪽 눈 그림자.
- **서브서피스**: 귀·코끝·손끝 붉은기, 매트 피부.
- **오프센터 영화 구도**: 좌측 1/3, 우측 여백, 시선유도선(총열 대각), 더치앵글, 콘트라포스토.
- **접촉 물리 + 기능적 손**: 그립 눌림, 손가락 트리거가드 위, 3/4 백뷰 손.
- **리치 블랙 + 한정 팔레트 + 한 점 액센트**: 암부=네이비/플럼, 액센트는 눈/총구만.

## 프롬프트 너머 파이프라인 (휴먼 인 더 루프 전제)
1. **구도 먼저 사람이 확정**: 실루엣 썸네일/포즈돌 → 라인·뎁스맵을 structure ref로 주입(AI가 구도 뽑게 X, 따르게 O).
2. **스타일 레퍼런스 강제 주입**: 실제 과슈/유화 인물화(Sargent alla prima) + 다크SF 페인터리(Mullins/Sparth/Ashley Wood)를 img2img denoise 0.3~0.5로 → 마크메이킹·명암구조 이식.
3. **2패스**: 그레이스케일(밸류·단일광원) 선별 → 컬러 입힘.
4. **2~3 시드 best-of 부분 합성**: 좋은 실루엣 + 좋은 얼굴/손 인페인트 조립.
5. **페인트오버(효과 80%)**: accent of darks 콕 찍기 / 그림자측 외곽선 끊어 lost edge / 큰 붓 한 획 실루엣 / 캐치라이트 손수정 / 서브서피스 한 점 / 멀티림 지우고 키라이트만 / AO 닦기.
6. **디테일 디머핑**: 초점 외 영역 일부러 뭉개 '쉼' 만들기 + 눈·총구만 인페인트로 끌어올림.
7. **마티에르/색 후처리(마스크 기반, 균일 오버레이 금지)**: 명도별 그레인 차등, 미드톤 broken-color로 매끈 그라데이션 깨기, 암부 들어올려 네이비/플럼, split-tone.
8. **각인/패치 벡터 합성**, **좌우 대칭 깨기**, **Topaz 업스케일은 맨 마지막 + 전역 sharpen 금지 → 업스케일 후 초점 외 재-blur**.

## 정직한 한계
- 콘트라포스토·오프센터·시선유도선은 말로 지정해도 모델이 안전한 대칭 디폴트로 회귀 → 포즈/구도 레퍼런스를 사람이 주는 게 10배 정확.
- 손-총 접촉 물리는 생성으로 거의 안 나옴 → 손만 잘라 실사 레퍼런스 인페인트.
- 전역 균일 그레인 한 장은 AI 티를 키움(역효과).
- 가챠 양산: 캐릭터 1체당 **키비주얼만 풀 파이프라인**, 변형 컷은 그 키비주얼을 레퍼런스로 재활용해 비용 배분.

## 재작성 프롬프트 (정본, 영문) — 부스터 제거판
> 저장: 위 금지어를 모두 뺀 단일광원·엣지위계·라인웨이트·오프센터·한정팔레트 버전. (전문은 워크플로 산출물 참조; 핵심은 "한 곳에 디테일 몰고 나머지 비우기 + 광원 하나 + 엣지 차등".)
