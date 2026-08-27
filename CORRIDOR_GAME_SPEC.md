# Vesper Corridor — Game Spec v0.1

## One-line contract

플레이어는 모아·비질·워든·다우스로 구성된 4인 원정대의 출격 카드를 실시간으로 눌러 단일 전선을 돌파하고,
끝없이 이어지는 회랑에서 전멸하기 전까지의 거리 기록을 갱신한다.

## Player loop

1. 원정 브리핑에서 고정 원정대와 출격 순서를 확인한다.
2. 회랑 지도에서 다음 노드를 선택한다.
3. 전투 중 코스트가 차는 순간 출격 카드를 눌러 사도를 배치한다.
4. 전선, 병종 상성, 적 출격, 보스 패턴을 읽으며 승리한다.
5. 보상·휴식·유물 중 하나를 선택해 원정대를 강화한다.
6. 전투가 끝날 때마다 거리를 1 올리고, 다음 구간의 분기·유물·위협을 생성한다.
7. 원정대가 전멸하면 런이 끝나며, 가장 멀리 간 거리가 기록이다.

## 런 변칙

런 시작 시 시드로 결정되는 변칙 하나가 끝까지 유지된다. 지도에서 이름과 효과를 항상
확인할 수 있으며, 전투 수치와 코스트 계산에 실제로 적용된다.

- **과충전**: 아군 코스트 충전 +12%, 적 공격력 +8%
- **희박한 등불**: 아군 공격력 +8%, 적 최대 체력 +12%
- **붉은 조류**: 적 이동 속도 +15%, 적 공격력 -8%

세 변칙은 같은 시드에서 같은 결과를 만들고, 새 런을 시작하면 다른 운영 압박을 만든다.

## Rules contract

- Active engine: `CorridorSession` only. `Match` is legacy and must not be imported by active scenes.
- Team: player uses the fixed four-person roster: 모아, 비질, 워든, 다우스. Rest can rotate their order, not replace them.
- Battle: one logical line, `FIELD_LEN=280`, spawn offset `20`; the 3D camera shows a window and moves when the cursor rests near the left/right edge.
- Player deployment: manual only. `CombatSim.manual_deploy(team, uid)` spends current cost.
- Retreat/redeploy: click an active player card to retreat that unit. It heals at base for 5 seconds, then can be redeployed at its normal cost with full HP.
- Enemy deployment: automatic queue for encounter pressure.
- Role contrast: 모아와 워든은 전선을 열고 지킨다. 모아는 낮은 체력 대신 빠른 이동·근접 연격으로 빈틈을 찌르고, 비질과 다우스는 42/36의 긴 사거리에서 높은 피해를 주지만 전선이 무너지면 빠르게 쓰러진다.
- Resources: battle cost starts at `0` and is visible as a continuously updating gauge; no AP or turn confirmation.
- Tactical commands: each battle grants two charges shared by `전진`, `방어`, and `집중`; a command is only valid while an allied unit is deployed.
- Win: enemy core reaches zero for the current segment. Lose: player core reaches zero or timeout at `75s`.
- Run: endless segments. Every segment offers safe/supply, normal combat, and elite routes; every 7th segment can offer a boss route.
- Threat: segment threat rises with distance, and encounter HP/attack scale gradually up to the engine's level cap.

## Decisions that create mastery

- Deploy now for tempo, or save cost for a high-impact unit.
- Use role counter timing against the current enemy front.
- Hold a card to respond to a boss pulse or enemy reinforcement.
- Choose a safe rest/supply route or an elite route with better relic access.
- Rotate the fixed squad order at a rest node.

## UI contract

- Top: compact floor, core HP, cost gauge, encounter warning.
- Center: battlefield and passive event/phase feedback. Tactical commands live in the compact battle control strip above the unit cards.
- Bottom: four unit cards. Each card shows portrait, role, cost, alive/deployed state,
  and a clear disabled charging state.
- Card click is the primary verb. No hidden auto-deployment for the player.
- Intro and map explain only the next decision; avoid economy terminology from the old match mode.

## Content contract

- Normal encounter: two enemy units, no special pulse.
- Elite: stronger roster and a six-second `검은 파동` warning/damage pulse.
- Battle variants: `철벽` strengthens and slows the frontline, `돌격` increases enemy movement/attack, and `증식` adds one enemy to the roster.
- Boss: stronger roster, a five-second `매듭 재생` warning/heal pulse, and a `매듭 붕괴` phase at 50% enemy core HP that accelerates the encounter.
- Rest: choose `체력 +20` or `선봉 교대`.
- Supply/event: supply chooses between repair and salvage; event chooses between signal decoding with relic access and a high-risk forced detour.
- Reward: choose one unique relic whenever the reward pool has an unused choice. Normal, supply, event, elite, and boss rewards expose different relic families.
- Relics: 15 unique effects, including shields, opening burst, low-HP comeback, armor pierce, movement, regeneration, and core damage.

## Explicit non-goals for this submission

- No eight-player match, shop, reroll, AI prep, rank, or hidden economy loop in active play.
- No turn-based confirmation flow; tactical commands are limited real-time interventions with two charges.
- No new art production; reuse current character assets and code-native UI.
- No multiplayer or persistence beyond the current run; the current run's distance is the score.

## QA gates

- Headless: corridor session, manual deployment, corridor route, combat, presentation bridge.
- Static: editor load, `git diff --check`, no active `Match` references.
- Export: Godot Web release succeeds.
- Delivery: Vercel production responds HTTP 200.
- Manual visual check: 1280x720 landscape; bottom cards remain visible without scrolling and cursor edge-hover moves the camera across the full line.
