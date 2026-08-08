# 베스퍼 회랑 - 인게임 픽셀 스프라이트 제작 파이프라인

인게임 전투 스프라이트의 최종 파이프라인은 **PixelLab 전투상태 파이프라인**이다. 일반 이미지 생성이나 임시 낙서 PNG를 게임에 붙이지 않는다.

새 6인 발주 입력은 `assets/pipeline/pixellab/manifest.json`과 `PIXELLAB-RUNBOOK.md`를 기준으로 한다.

## 한 줄 요약

**PixelLab `create_character` → `create_character_state` → `animate_character(mode=v3)` → `pixellab_assemble.py` → Godot 배선.**

`imagegen/rigkit_v2_parts`는 이전 실험/폴백 기록이며, 현재 주력 루트가 아니다.

---

## 실패 기록 — 다시 기본 루트로 삼지 말 것

- PixelLab 단순 직생성/AutoSprite: 캐릭터 비율·전투 자세·프레임 일관성이 흔들렸음.
- Higgsfield AutoSprite: 이미지→픽셀 스프라이트시트 서버측 실패가 반복됐음.
- 프레임별 일반 이미지 생성: 각 프레임마다 얼굴·무기·실루엣이 흔들려 전투 유닛으로 부적합.

결론: PixelLab을 단순 픽셀 생성기로 쓰지 말고, **캐릭터 원본 → 전투상태 파생 → 상태별 애니메이션**으로 써야 한다.

---

## STEP 1 — PixelLab `create_character`

목표는 전투에서 반복 재사용할 캐릭터 원본을 만드는 것이다.

- view: side/east 기준
- 입력: 기존 마스터 레퍼런스가 있으면 사용, 없으면 `GameState.ALL_CHARS[*].visual_brief`
- 승인 게이트:
  - 캐릭터 정체성
  - 비율
  - 무기/소품 실루엣
  - 색 팔레트

승인 전에는 다음 단계로 넘기지 않는다.

## STEP 2 — PixelLab `create_character_state`

전투 애니메이션의 베이스가 되는 상태를 먼저 만든다.

필수 상태:

1. 조준/교전 베이스
   - 낮은 공격적 combat crouch
   - 무릎 굽힘
   - 무기 raised/shouldered/ready
2. 러닝 베이스
   - 앞으로 낮게 달림
   - 몸이 전방으로 기울어짐
   - 무기를 가슴 앞 ready 위치로 유지

프리뷰에서 자세가 높거나 무기가 내려가 있으면 배선하지 않고 그 상태만 재생성한다.

## STEP 3 — PixelLab `animate_character`

기준 호출 계약:

- `mode=v3`
- `directions=["east"]`
- run: 저자세 러닝 베이스에서 8프레임
- aim: 조준/교전 베이스에서 4프레임
- attack: 조준/교전 베이스에서 6프레임
- 선택: hit/death

프레임 수가 너무 많아 실패하면 해당 액션만 줄여 재발주한다. west 방향은 엔진 flip으로 처리한다.

## STEP 4 — 프레임 조립

PixelLab 프레임 URL을 `spec.json`에 넣고 조립한다.

```bash
python3 /Users/minseo/gamedev-toolkit/pixellab_assemble.py spec.json
```

스펙 기준:

- `out`: `/Users/minseo/pixel-front/assets/sprites/<slug>_pl`
- `anims`: `walk`, `aim`, `attack`
- `idle_from`: aim 첫 프레임 또는 별도 idle

도구가 공통 박스 크롭, 발 정렬, `<anim>_<i>.png`, `idle_0.png`, 미리보기 GIF를 만든다.

PixelLab Backblaze URL이 기본 UA로 막히면:

```bash
curl -A "Mozilla/5.0" -L "<url>" -o frame.png
```

## STEP 5 — 게임 배선

`game_state.gd` 캐릭터 항목에 최종 산출물이 있는 경우만 연결한다.

```gdscript
"sprite": "res://assets/sprites/<slug>_pl", "sps": 0.0145, "tightsprite": true
```

`unit3d.gd`는 `sprite` 폴더가 있으면 `AnimatedSprite3D`를 사용한다.

- 이동: `walk`
- 정지: `idle`
- 교전 대기: `aim`이 있으면 aim, 없으면 idle
- 공격: `attack`
- 방향: east 프레임을 기본으로 쓰고 반대 방향은 flip
- 렌더: nearest, alpha scissor, shaded billboard

## 검증법

```bash
godot --headless --path /Users/minseo/pixel-front --import
python3 tools/validate_pixellab_queue.py
godot --headless --path /Users/minseo/pixel-front res://character_identity_test.tscn
godot --headless --path /Users/minseo/pixel-front res://scene_smoke_test.tscn
godot --headless --path /Users/minseo/pixel-front res://battlefield_visual_test.tscn
```

전투 영상 캡처가 필요하면 `_rigkit_shot.tscn --write-movie --fixed-fps 30 -- --burst --solo`를 사용한다. 파일명은 과거 이름이지만 목적은 전장 스프라이트 캡처다.

## 현재 자산 상태

- 소등사: `assets/sprites/sodeungsa_pl` 검증됨.
- 관지기: 기존 HD/리그 데모 스프라이트 사용 중. 새 6인 이후 PixelLab 전환 대상.
- 집전 의무관: `assets/sprites/jipjeon_medic_pl` 검증 및 런타임 연결 완료.
- 나머지 신규 캐릭터: `asset_pipeline:"pixellab_combat_state"` 단계별 진행.

## 남은 일

- [x] 집전 의무관 PixelLab `create_character`
- [x] 집전 의무관 전투상태/애니메이션/조립/런타임 연결
- [x] 진혼병 PixelLab `create_character` 발주
- [x] 진혼병 전투상태 2종 발주
- [x] 진혼병 walk/aim/attack 애니메이션 발주
- [x] 진혼병 조립/런타임 연결
- [ ] 운구 소총수 PixelLab `create_character`
- [ ] 사열 돌격수 PixelLab `create_character`
- [ ] 납골 방패병 PixelLab `create_character`
- [ ] 망종 중계사 PixelLab `create_character`
- [ ] 각 캐릭터 `create_character_state` 2종
- [ ] run/aim/attack 애니 생성
- [ ] `pixellab_assemble.py` 조립 후 `game_state.gd` sprite 연결
