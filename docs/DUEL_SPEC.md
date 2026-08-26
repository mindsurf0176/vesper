# Vesper DuelSpec v1

## Playable verb

Choose one Vesper character, close distance, read the opponent's attack tell, and win a best-of-three side-view duel.

## Match contract

- Player: one selected roster character, left side, keyboard `A/D` move, `W` jump, `J` light, `K` heavy, `L` special, `S` guard.
- Opponent: one selected roster character, right side, deterministic distance-seeking CPU.
- Match: first fighter to win two rounds wins.
- Round: opponent HP reaches `0` to win; player HP reaches `0` to lose. Fighters reset to 100 HP between rounds.
- HP: normalized to `100`; roster `dmg` scales light/heavy/special damage.
- Guard: holding `S` reduces ordinary damage to 18%; the first 0.18 seconds is a perfect-guard window that deals no damage and staggers the attacker. Guard-break specials ignore guard reduction.
- Character specials: shield/tank uses `IRON BREAK`, rifle/sniper uses `PIERCE SHOT`, relic/support uses `LAST LIGHT` healing the user, and other fighters use the high-damage `BREAKTHROUGH`.
- Arena: `1280x720`, ground `y=558`, horizontal bounds `110..1170`.
- Z order: arena background, fighters, hit flashes, HUD.

## State contract

`duel.gd` owns positions, cooldowns, attack reach, hit timing, HP, meter, gravity, CPU choice, and result state. `duel_actor.gd` only consumes action state and renders the character sprite or bounded fallback.

## Asset contract

- Sprite source: `def.sprite/<idle|walk|attack|hit|death>_<frame>.png`.
- Filter: nearest-neighbor.
- Ground anchor: actor origin at arena ground; sprite extends upward.
- Fallback: deterministic role silhouette using `visual.primary` and `visual.accent`.
- Gameplay never depends on image dimensions for collision or damage.

## QA gates

- Selection flow chooses distinct player and opponent definitions.
- Selected definitions reach the duel actors.
- A light attack reduces opponent HP.
- Guard and perfect guard produce distinct deterministic outcomes.
- Round one win, round reset, and round two match win are recorded.
- Match end routes to the result screen.
- Web export completes without 3D runtime nodes in the active duel scene.
