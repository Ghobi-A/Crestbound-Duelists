# Greymere 2D production pass

This pass extends the merged Greymere and UI work. It keeps the Godot 2D renderer,
the authored character registry, battle formulas, turn order, status effects and
existing story dialogue. The separate v2.3 combat balance bundle is not merged.

## Implemented

- Enemy battlefield plates display name, live HP ratio, downed state and the
  most important active status. They use each `BattleUnit` directly and space
  themselves from the actual formation positions for one, two or three enemies.
  Target selection highlights the plate alongside the existing sprite ring.
- Gell's shop counter and shopkeeper open the same buy interface. Potion (25 HP,
  18 crowns) and Hi-Potion (55 HP, 42 crowns) are data-driven. The field bag in
  the pause menu applies them to a chosen party member between battles.
- Crown balance, inventory and remaining party HP persist in the existing
  version-2 save payload. Older version-2 saves default to 60 crowns, empty
  inventory and full HP. The next encounter reads party HP from that payload;
  victory writes survivors' HP back, with downed members recovering to 1 HP.
- Lena's house has a tighter footprint; the inn has more social seating and
  Ferris as a patron. Merchant crates mark the east commercial lane. Existing
  floor, building, foliage, sprite and UI assets remain the visual foundation.

## Visual QA checklist

- [ ] Inspect 720p and 1080p Greymere, east lane, Lena house, inn and shop.
- [ ] Inspect shop and field bag overlays for readable price, ownership, funds,
  item description, healing target and purchase feedback.
- [ ] Inspect 1v1, 2v2, 3v1 and 3v3 enemy plates for spacing, HP, down state,
  status, selection emphasis and sprite visibility.
- [ ] Inspect target preview, victory/defeat, dialogue and all six Kai classes.
- [ ] Inspect 640x360 and browser viewports for clipping and font readability.
- [x] World smoke exercises doors, NPCs, furniture, shop interactions and saves.
- [x] Shop smoke exercises purchases, insufficient funds, full-health refusal,
  healing, UI commands, save/reload and old-save defaults.
- [x] Presentation smoke exercises combat victory and defeat.

## Known art work

The walk-contact audit still flags eight side facings: Almyra west, Ferris east
and west, Gell west, Kai Assassin west, Kai Warrior west, Liora east and the
Hooded Stranger west. Their source contact drawings need a faithful manual
redraw. Data-only later encounters also lack authored battle sprites, and
several optional VFX still use the documented system pulse. No unrelated
character art is substituted to conceal those gaps.

The new shop adds attrition between battles. Its starting funds and item prices
are provisional balance values; the combat resolver and class stats are unchanged.
