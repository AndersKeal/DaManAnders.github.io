# Dev Note — Damage Feedback (12v12)

_Captured 2026-06-16_

## Goal
When a player takes damage, give them two pieces of feedback:

1. **Directional damage indicators** — a marker/arc pointing toward the source
   of the damage so they know which way to turn.
2. **Damage splash** — a quick red vignette / flash on screen that fires
   *every* time damage is actually applied.

## Notes / approach (Verse + UEFN)

- Listen for damage on each player's `fort_character`:
  ```
  Player.GetFortCharacter[].DamagedEvent().Subscribe(OnDamaged)
  ```
  The `damage_result` payload gives you the amount and (importantly) the
  instigator, which you need to compute direction.

- **Direction math:** get the world position of the victim and the instigator,
  take the vector between them, then convert to a yaw *relative to the victim's
  current view rotation*. That relative angle is what drives which way the
  on-screen arrow points (front / left / right / behind). If the instigator is
  null (fall damage, storm, etc.) just skip the directional arrow but still
  play the splash.

- **UI:** build the HUD with `canvas` + `widget` (e.g. `texture_block` /
  `material_block`) shown via a `player_ui` (`GetPlayerUI[]`). One arrow widget
  you rotate, or a small ring of 8 arrows you toggle. Consider pooling/fading
  them with a short timer so multiple hits don't stack forever.

- **Splash:** a full-screen semi-transparent red `texture_block` whose opacity
  you spike on hit and then ease back to 0 over ~0.3s. Scale intensity with
  damage amount if you want low vs. heavy hits to feel different.

## Things to decide later
- Indicator lifetime / fade time.
- Do indicators stack per-attacker or merge into one strongest direction?
- Splash intensity curve (flat vs. scaled by damage).
- Performance with 24 players all subscribing — verify event load is fine.
- Should teammates' friendly fire (if any) trigger it?
