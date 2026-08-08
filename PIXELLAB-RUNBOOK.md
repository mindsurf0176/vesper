# 베스퍼 회랑 — PixelLab 실행 런북

목표: 새 6명 캐릭터를 PixelLab 전투상태 파이프라인으로 생성하고, 게임 런타임에 연결한다.

정본 입력은 `assets/pipeline/pixellab/manifest.json`이다. PixelLab MCP는 Codex config에 연결되어 있으며, 네이티브 도구 목록에 노출되지 않으면 `PIXELLAB_API_KEY` 기반 MCP streamable-http 클라이언트로 직접 호출한다.

2026-07-15 결정: 신규 캐릭터는 `assets/pipeline/illustration/manifest.json`의 소등사급 히어로 일러스트가 승인된 뒤 전장 스프라이트를 발주한다. 이미 연결된 전장 스프라이트는 유지하되, 히어로 일러스트와 디자인이 충돌하면 전장 스프라이트를 재생성한다.

## 1. 캐릭터 원본 생성

우선순위는 manifest의 `characters[*].priority`를 따른다.

1. `create_character`
   - prompt: 해당 캐릭터의 `create_character_prompt`
   - global: `global_contract.view`, `style`, `do_not`
2. 승인 게이트:
   - 전투 축소 크기에서도 캐릭터가 읽히는가
   - side/east 방향인가
   - 머리가 과하게 크지 않은가
   - 무기/소품 실루엣이 직업을 설명하는가
3. 발주 직후 manifest의 해당 캐릭터 `stage`를 `base_processing`으로 올리고 `base_character_id`를 기록한다.
4. `get_character` 완료본이 승인 게이트를 통과하면 `stage`를 `state_needed`로 올린다.

## 2. 전투상태 생성

승인된 원본 ID로 `create_character_state`를 2개 만든다.

- `aim_base`: `manifest.state_contract.aim_base.prompt`
- `run_base`: `manifest.state_contract.run_base.prompt`

발주 직후 `stage`를 `state_processing`으로 올리고 `state_character_ids.aim_base/run_base`를 기록한다. 프리뷰에서 자세가 높거나 무기/소품이 내려가 있으면 그 상태만 재생성한다. 통과하면 `stage`를 `animation_needed`로 올린다.

## 3. 애니메이션 생성

각 상태 ID로 아래 애니메이션을 생성한다.

- `walk`: run_base, `frame_count=8`
- `aim`: aim_base, `frame_count=4`
- `attack`: aim_base, `frame_count=6`

공통 설정:

- `mode=v3`
- `directions=["east"]`
- west는 엔진 flip으로 처리

발주 직후 `stage`를 `animation_processing`으로 올리고 `animation_requests`에 각 애니메이션의 source state, character id, frame count, generation cost를 기록한다.

## 4. 조립 spec 채우기

캐릭터별 템플릿을 복사해 실제 spec으로 만든다.

예시:

```bash
cp assets/pipeline/pixellab/specs/jipjeon_medic.template.json \
  /Users/minseo/vesper-preview/pixellab_jipjeon_medic.spec.json
```

그 뒤 `frames` 배열에 PixelLab 프레임 URL을 순서대로 채운다.

## 5. 게임 스프라이트 조립

```bash
python3 /Users/minseo/gamedev-toolkit/pixellab_assemble.py \
  /Users/minseo/vesper-preview/pixellab_jipjeon_medic.spec.json
```

출력은 `assets/sprites/<slug>_pl`이다.

## 6. 게임 배선

조립 결과가 확인된 캐릭터만 `game_state.gd`에 `sprite`를 추가하고 `stage`를 `ready`로 바꾼다.

```gdscript
"sprite": "res://assets/sprites/<slug>_pl", "sps": 0.0145, "tightsprite": true
```

## 7. 검증

```bash
python3 tools/validate_pixellab_queue.py
godot --headless --path /Users/minseo/pixel-front --import
godot --headless --path /Users/minseo/pixel-front res://character_identity_test.tscn
godot --headless --path /Users/minseo/pixel-front res://scene_smoke_test.tscn
godot --headless --path /Users/minseo/pixel-front res://battlefield_visual_test.tscn
```

## 현재 발주 순서

1. 집전 의무관 — `jipjeon_medic` — ready
2. 진혼병 — `jinhonbyeong` — ready
3. 운구 소총수 — `ungoo_rifle` — base_needed
4. 사열 돌격수 — `sayeol_striker` — base_needed
5. 납골 방패병 — `napgol_defender` — base_needed
6. 망종 중계사 — `mangjong_relay` — base_needed
