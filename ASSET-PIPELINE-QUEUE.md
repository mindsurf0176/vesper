# 베스퍼 회랑 — PixelLab 캐릭터 에셋 큐

이 문서는 새 캐릭터 6명의 전장 스프라이트 생산 큐다. 최종 결정은 `imagegen/rigkit`이 아니라 **PixelLab 전투상태 파이프라인**이다. 단, 2026-07-15부터 신규 캐릭터 생산 순서는 **소등사급 히어로 일러스트 승인 → 전장 스프라이트**로 고정한다. 일러스트 정본 큐는 `assets/pipeline/illustration/manifest.json`이다.

실행 입력:

- 발주 manifest: `assets/pipeline/pixellab/manifest.json`
- 조립 spec 템플릿: `assets/pipeline/pixellab/specs/*.template.json`
- 실행 런북: `PIXELLAB-RUNBOOK.md`

## 정본 파이프라인

전장 스프라이트는 아래 순서가 정본이다.

1. PixelLab `create_character`
   - side view / east 기준
   - 마스터 레퍼런스가 있으면 사용, 없으면 `visual_brief`로 생성
   - 사람이 정체성·비율·무기 실루엣을 승인
2. PixelLab `create_character_state`로 전투 베이스 2종 파생
   - 저자세 조준/교전: 낮은 공격적 전투 crouch, 무기 shouldered/ready
   - 저자세 러닝: 앞으로 낮게 달리며 무기 ready
3. PixelLab `animate_character`
   - `mode=v3`
   - `directions=["east"]`
   - `run` 8프레임
   - `aim` 4프레임
   - `attack` 6프레임
   - 필요 시 `hit`, `death` 추가
4. 완료된 프레임 URL을 `spec.json`에 기록
5. 조립:

```bash
python3 /Users/minseo/gamedev-toolkit/pixellab_assemble.py spec.json
```

6. 출력 폴더를 `assets/sprites/<slug>_pl`로 둔다.
7. `game_state.gd`에 최종 산출물이 생긴 캐릭터만 아래처럼 연결한다.

```gdscript
"sprite": "res://assets/sprites/<slug>_pl", "sps": 0.0145, "tightsprite": true
```

8. Godot import와 회귀 테스트를 실행한다.

```bash
godot --headless --path /Users/minseo/pixel-front --import
python3 tools/validate_pixellab_queue.py
godot --headless --path /Users/minseo/pixel-front res://character_identity_test.tscn
godot --headless --path /Users/minseo/pixel-front res://scene_smoke_test.tscn
godot --headless --path /Users/minseo/pixel-front res://battlefield_visual_test.tscn
```

PixelLab Backblaze URL이 기본 UA로 403이면 `curl -A "Mozilla/5.0"`로 받는다.

## 현재 실행 조건

현재 Codex 설정에는 PixelLab MCP가 연결되어 있다. 네이티브 도구 목록에 노출되지 않는 환경에서는 `PIXELLAB_API_KEY`를 환경변수로 두고 MCP streamable-http 클라이언트로 `create_character`, `create_character_state`, `animate_character`, `get_character`를 호출한다.

`imagegen/rigkit_v2_parts`는 이전 실험/폴백 기록이며, 현재 주력 경로가 아니다.

## 신규 6인 PixelLab 큐

신규 `base_needed` 캐릭터는 먼저 일러스트 manifest의 `hero_needed`를 해결한 뒤 PixelLab 베이스를 발주한다. 이미 `ready`인 진혼병/집전 의무관 전장 스프라이트는 런타임용으로 유지하되, 히어로 일러스트에서 디자인이 크게 바뀌면 재생성 대상이 된다.

| 우선순위 | 캐릭터 | slug | 현재 상태 | 다음 액션 |
| --- | --- | --- | --- | --- |
| 1 | 집전 의무관 | `jipjeon_medic` | `ready` | 완료: `assets/sprites/jipjeon_medic_pl` 런타임 연결 |
| 2 | 진혼병 | `jinhonbyeong` | `ready` | 완료: `assets/sprites/jinhonbyeong_pl` 런타임 연결 |
| 3 | 운구 소총수 | `ungoo_rifle` | `base_needed` | `visual_brief`로 `create_character` |
| 4 | 사열 돌격수 | `sayeol_striker` | `base_needed` | `visual_brief`로 `create_character` |
| 5 | 납골 방패병 | `napgol_defender` | `base_needed` | `visual_brief`로 `create_character` |
| 6 | 망종 중계사 | `mangjong_relay` | `base_needed` | `visual_brief`로 `create_character` |

생성 요청 후 상태는 `base_processing` → 완료/승인 후 `state_needed` → 상태 발주 후 `state_processing` → 애니 발주 후 `animation_processing` → 조립 완료 시 `ready`로 올린다. `ready`가 되기 전에는 `sprite` 필드를 연결하지 않는다.

## 검증된 기준 자산

- 소등사: `assets/sprites/sodeungsa_pl`
  - walk=run 8프레임
  - aim 5프레임
  - attack 7프레임
  - idle 1프레임
- 진혼병: `assets/sprites/jinhonbyeong_pl`
  - walk 8프레임
  - aim 5프레임
  - attack 7프레임
  - idle 1프레임
- 집전 의무관: `assets/sprites/jipjeon_medic_pl`
  - walk 8프레임
  - aim 5프레임
  - attack 7프레임
  - idle 1프레임
- 관지기: 현재 기존 HD/리그 데모 스프라이트 사용 중. 신규 PixelLab 전환 대상은 새 6인 이후로 둔다.

## 카드/도감 원화

카드/얼굴 원화는 전장 스프라이트와 별도 산출물이다.

- 스타일 정본: `ART-illustration-style.md`, `ART-illustration-tells.md`
- 최종 산출: `assets/art/card_<slug>.png`, `assets/art/face_<slug>.png`
- 전장에는 PixelLab `<slug>_pl` 스프라이트만 연결한다.

게임에는 최종 산출물이 생긴 뒤에만 `art`/`card_art`/`sprite`를 연결한다. 생성 전에는 `asset_pipeline:"pixellab_combat_state"`와 `asset_pipeline_stage`만 둔다.
