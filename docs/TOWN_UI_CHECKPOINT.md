# Town and UI restoration

This checkpoint reconstructs the lost town/UI work on current main. It preserves
the newer overworld animation atlases and all combat and movement rules.

- Shared dark blue recessed panels apply across dialogue, menus and battle UI.
- Title uses live typography, Hollow Court scenery and Neutral Kai artwork.
- Party selection uses portrait cards and scrolls for parties larger than three.
- Dialogue portraits have a dedicated frame inside the existing clipped layout.
- Greymere has authored stone facades anchored to existing door cells, plus a
  connecting promenade. Buildings do not change the collision map.

The lost generated town-material and trial-cast images are not recovered here.
The existing terrain, cast and battle artwork remain. This is a reconstruction,
not a claim that the earlier image files have been restored.

## Verification

Run static Godot validation, presentation contract tests, headless editor import
and the presentation smoke scene. GitHub Pages builds from main.

## Visual QA still required

- Check the town facades, promenade and NPC depth at native and reduced viewport.
- Check every dialogue portrait and long names/text.
- Check party cards, scrolling, class selection and controller hints.
- Check battle, victory and defeat presentation in a rendered browser session.

Headless verification does not certify the rendered appearance.
