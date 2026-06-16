# Prompt to paste into your UEFN project (desktop)

Copy everything below the line into your project's coding assistant.

---

I'm building a **12v12 game in UEFN with Verse**. I want a damage-feedback
system with two parts:

1. **On-screen hit splash** — a full-screen flash every time my player actually
   takes damage. I have (or will make) a custom full-screen splash texture I
   want to use for this.
2. **Directional damage indicators** — a marker that appears around the edge of
   the screen pointing toward whatever damaged me, computed relative to where I'm
   currently looking (front/left/right/behind).

I have a starting Verse device below (`damage_feedback_device.verse`). Please:

- **Add it to my project** as a Verse creative device, then place one instance
  in the level so it runs.
- **Reconcile every API call against my installed Verse digest** and fix
  anything that differs in my version. Pay special attention to:
  - `damage_result` — confirm the field that exposes the **instigator/attacker**
    and how to get its location. That's isolated in `GetAttackerLocation(...)`;
    fix it there. The splash must keep working even if the attacker can't be
    resolved (it should just skip the directional marker).
  - UI method/field names: `color_block` / `texture_block` (`SetOpacity`,
    `SetColor`, `SetDesiredSize`, `SetVisibility`, `DefaultColor`,
    `DefaultOpacity`), `canvas` / `canvas_slot` (`AddWidget`, `RemoveWidget`,
    `anchors`, `margin`, `Alignment`, `SizeToContent`, `ZOrder`), and
    `GetPlayerUI[]`.
  - Character APIs: `DamagedEvent()`, `EliminatedEvent()`, `GetViewLocation()`,
    `GetViewRotation()`, and `rotation.GetLocalForward()/GetLocalRight()`.
  - Math: confirm `Sqrt`, `DotProduct`, and vector3 `-` are imported from the
    right modules for my version.
- **Swap the placeholder visuals for my textures**: replace the splash
  `color_block` with a `texture_block` using my full-screen splash texture, and
  (optionally) replace the indicator `color_block` with an arrow texture. Keep
  the marker positioned by where it sits on the ring — since UEFN's UI can't
  rotate a widget at runtime, the position around the ring conveys direction.
- Keep the `@editable` knobs (colors, opacity, sizes, durations) so I can tune
  them in the UEFN details panel.
- Confirm it builds with no Verse errors, and tell me exactly what you changed
  from the original.

A couple of design questions I'm undecided on — pick sensible defaults and note
your choice: (a) should multiple simultaneous attackers each show a marker, or
just the most recent hit? (b) should friendly fire (if I enable it) trigger the
feedback? Right now the stub shows one marker per hit and treats all damage the
same.

```verse
// <-- paste the full contents of damage_feedback_device.verse here -->
```
