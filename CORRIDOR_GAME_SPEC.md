# Vesper Corridor — Game Spec v0.1

## One-line contract

플레이어는 고정된 3인 원정대의 출격 카드를 실시간으로 눌러 단일 전선을 돌파하고,
5개 층의 분기·휴식·유물 선택으로 다음 전투의 해법을 만든다.

## Player loop

1. 원정 브리핑에서 3명의 사도를 선택한다.
2. 회랑 지도에서 다음 노드를 선택한다.
3. 전투 중 코스트가 차는 순간 출격 카드를 눌러 사도를 배치한다.
4. 전선, 병종 상성, 적 출격, 보스 패턴을 읽으며 승리한다.
5. 보상·휴식·유물 중 하나를 선택해 원정대를 강화한다.
6. 5층 보스까지 돌파하거나 전멸하면 런이 끝난다.

## Rules contract

- Active engine: `CorridorSession` only. `Match` is legacy and must not be imported by active scenes.
- Team: player owns exactly 3 selected units for the whole run. Rest can rotate their order, not replace them.
- Battle: one logical line, `FIELD_LEN=140`, spawn offset `20`.
- Player deployment: manual only. `CombatSim.manual_deploy(team, uid)` spends current cost.
- Enemy deployment: automatic queue for encounter pressure.
- Resources: battle cost is visible as a continuously updating gauge; no AP or turn confirmation.
- Win: enemy core reaches zero. Lose: player core reaches zero or timeout.
- Run: five floors, branch nodes on floors 2–4, boss on floor 5.

## Decisions that create mastery

- Deploy now for tempo, or save cost for a high-impact unit.
- Use role counter timing against the current enemy front.
- Hold a card to respond to a boss pulse or enemy reinforcement.
- Choose a safe rest/supply route or an elite route with better relic access.
- Rotate the fixed squad order at a rest node.

## UI contract

- Top: compact floor, core HP, cost gauge, encounter warning.
- Center: battlefield only; no tactical planning toolbar.
- Bottom: three large unit cards. Each card shows portrait, role, cost, alive/deployed state,
  and a clear disabled charging state.
- Card click is the primary verb. No hidden auto-deployment for the player.
- Intro and map explain only the next decision; avoid economy terminology from the old match mode.

## Content contract

- Normal encounter: two enemy units, no special pulse.
- Elite: stronger roster and a six-second `검은 파동` warning/damage pulse.
- Boss: stronger roster and a five-second `매듭 재생` warning/heal pulse.
- Rest: choose `체력 +20` or `선봉 교대`.
- Reward: choose one unique relic. Unit cards come from the fixed squad; relics are run growth.

## Explicit non-goals for this submission

- No eight-player match, shop, reroll, AI prep, rank, or hidden economy loop in active play.
- No separate AP/turn tactical command system.
- No new art production; reuse current character assets and code-native UI.
- No multiplayer or persistence beyond the current run.

## QA gates

- Headless: corridor session, manual deployment, corridor route, combat, presentation bridge.
- Static: editor load, `git diff --check`, no active `Match` references.
- Export: Godot Web release succeeds.
- Delivery: Vercel production responds HTTP 200.
- Manual visual check: 1280x720 landscape; bottom cards remain visible without scrolling.
