# Vesper DuelSpec v1

## Playable verb

Choose one Vesper character, close distance, read the opponent's attack tell, and win a single-round side-view duel.

## Match contract

- Player: one selected roster character, left side, keyboard `A/D` move, `W` jump, `J` light, `K` heavy, `L` special.
- Opponent: one selected roster character, right side, deterministic distance-seeking CPU.
- Win: opponent HP reaches `0`.
- Lose: player HP reaches `0`.
- HP: normalized to `100`; roster `dmg` scales light/heavy/special damage.
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
- HP zero routes to the result screen.
- Web export completes without 3D runtime nodes in the active duel scene.
