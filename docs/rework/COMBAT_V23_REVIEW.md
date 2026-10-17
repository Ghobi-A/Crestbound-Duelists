# Combat v2.3 integration review

The later tuning commits d30aef6 and 2f4c4c2 intentionally superseded the first
v2.3 chassis: Warrior/Mage/Assassin/Guardian/Neutral/Sorcerer speeds are now
48/48/68/36/52/60, Cripple has DEF -8 and SPD -8, and Focus Shift retains DEF/RES
-2 even under Hex. Tests and the README were stale; YAML was preserved.

Both export destinations were regenerated. Python Move records now retain YAML
tags. Brace bypass follows guard_break/resistance_break tags in both runtimes,
fixing the previous Python-only inference that any DEF -8 Signature bypassed
Brace. Cripple remains mitigated by Brace, as its tags specify. AI estimates use
the same tags and configured stat-decay horizon. Reapplication of same-direction
stat effects refreshes the duration/stronger amount rather than stacking.

The deterministic reference generator tools/generate_combat_parity.py invokes
actual Python combat. Its committed fixture covers all 216 combinations of six
attackers, six defenders, three moves and Brace on/off at both variance bounds.
Godot's real resolver compares those ranges and checks Hex tradeoff suppression
and repeated-rider refresh. Pytest checks fixture freshness; presentation CI runs
the Godot script after import. The fixture is QA data, not gameplay balance data.

Local validation: Python regression suite; Godot static/editor import; 216-case
parity harness; route, world, presentation and shop smoke tests; Web release
export. Headless rendering retains the existing custom-sampler/VFX diagnostics.
No new visual validation is claimed for this numerical change.

Fixed-seed snapshot validation used 5,000 simulations per matchup, 500 policy
comparison simulations and seed 42, written outside the committed production
snapshot. The main workflow owns the full production snapshot regeneration.

Diagnostic targets are not acceptance guarantees: a seed-42 500-simulation
lookahead report gave 5.9 average rounds, 15.5% Signature usage and 47.3% Gambit
usage; Neutral averaged 44.3% wins. These are provisional Monte Carlo estimates,
not evidence that the 6–8-round/47–53% targets are fully met. A separate balance
iteration should examine Neutral and action mix across policies/seeds and real
play. This repair preserves the deliberate tuning rather than silently selecting
new stats to make a small diagnostic run satisfy thresholds.
