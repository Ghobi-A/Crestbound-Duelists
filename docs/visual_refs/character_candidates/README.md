# Character animation candidates — not production assets

These three reference-derived sheets are retained for review and further animation
work. They are outside `game/`, are not exported, and are not referenced by the
runtime character registry. They are not replacements for the existing sprites yet.

| File | Identity check | Remaining work |
| --- | --- | --- |
| `kai_neutral.png` | Brown hair, bare face, cream/charcoal field clothes and Verdant sword/magic motif retained | Side rows still repeat a stride; correct opposite-leg contact and passing poses, then register feet and test in motion |
| `almyra.png` | Long silver hair, blue/gold tabard, steel armour and shield retained | Review opposite-leg continuity and shield's anatomical side across all facings; test motion and scale |
| `gell.png` | Existing green cap, brown hair, cream sleeves and green workwear retained | Review side-facing stride alternation and cap-clasp/pouch continuity; test motion and scale |

All use a magenta colour-key background, not alpha transparency. The first Kai
attempt produced a painted checkerboard and was rejected; the retained correction
has a flat keyed background. Do not mistake that technical correction for full
animation approval. No sheet has passed the runtime visual gate.

Generated with the built-in image-generation tool. Initial prompts are preserved
in `prompts.json`. Kai's subsequent correction requested removal of the
checkerboard in favour of solid #FF00FF and alternating left/right leg contacts
with passing poses. The background correction succeeded; side-walk correction
remains incomplete. References and precedence decisions are recorded in
`../../rework/GREYMERE_CHARACTER_REFERENCE_AUDIT.md`.
