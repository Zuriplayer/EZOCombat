# EZOCombat

Prefer Spanish? Read the [Spanish README](README.es.md).

EZOCombat is a visual, manual action-bar helper for **The Elder Scrolls Online**. It never casts abilities, changes weapon bars, or simulates player input.

Support, bug reports, and suggestions: https://discord.gg/ekw8zUAcRm

## Beta Status

Version: `0.2.50-beta`

This functional beta provides the persistent UI, priority foundation, and a layered ability-state engine. Ability-specific effect mappings, remaining-time thresholds, and class rule packs still require separate in-client verification.

## Requirements

### Performance and tracking lifecycle

- Automatic ability-state work is restricted to enabled trackers on either current weapon bar. Ordinary `slotted` trackers need no state polling; explicit stack counters still do. Unslotted/unconfigured abilities do not start predictions or native slot-state queries.
- A shared 100 ms state pass serves priorities and stack labels. Unchanged states do not repaint the HUD. Layouts and slot metadata are reused until their inputs change; a closed action-bar window does not repaint its slots.
- With HUD icons disabled, or no trackers needing state evidence, the state timer and combat-evidence listeners are unregistered. Slot/weapon-bar and profile lifecycle notifications remain to discover newly slotted abilities. This is not a global addon OFF switch: the PvP frame and native damage cone have independent settings.
- Bound Armaments reads native stacks first. Its player-effect recovery is event-fed and limited to one scan per 500 ms when native stacks are zero/unavailable, including caching zero. The four-stack active threshold is unchanged.
- The PvP frame disconnects target listeners outside its enabled scope/HUD scenes and creates controls only when needed. Identity metadata refreshes at most once per second for the same target; health and projection retain their 100 ms cadence. SCT restoration retains its original snapshot after native call failures so restoration can be retried.
- Re-enabling tracking rebuilds current native effects. Predicted cast cycles cannot reconstruct casts made while tracking was disabled or the skill was unslotted; test these with a fresh cast.
- Run the standalone Lua 5.1 regression suite from the project root with `lua tools/tests/performance_spec.lua`. It uses mock ESO APIs and is not loaded by the addon. Passing it is not proof of improved client FPS or LIVE/PTS acceptance.

### Runtime dependencies

- The Elder Scrolls Online PC client.
- `LibAddonMenu-2.0`.
- ESO API version declared in the manifest: `101051` (current client API confirmed by the user on 2026-09-28; not a substitute for runtime/FPS validation).
- Optional developer/debug addons:
  - `LibDebugLogger`
  - `DebugLogViewer`
- Optional EZO-family integration:
  - `EZOCore` for shared language preference inheritance, when installed.

## Installation

1. Download or clone this repository.
2. Copy the `EZOCombat` folder into your ESO AddOns directory:
   - Live: `Documents/Elder Scrolls Online/live/AddOns/EZOCombat`
   - PTS: `Documents/Elder Scrolls Online/pts/AddOns/EZOCombat`
3. Start ESO or run `/reloadui`.
4. Enable `EZOCombat` from the Add-Ons menu if needed.

## Current Features

- Movable EZOArmory-style window showing the front and back action bars, including both ultimate slots.
- Session-only `Show all configured` selector in the action-bar window. It temporarily shows every enabled tracker still slotted on the current profile's bars so the icons can be positioned, then restores normal visibility when disabled or when the window closes.
- Window access through the EZOCombat LAM panel, `/ezocombat`, or the default `Shift+NumPad 3` binding when that exact input is free.
- Automatic class detection and automatic role selection from the role selected in the Group Finder.
- Manual role selection in LAM when automatic role detection is off. The fallback role is Damage.
- Persistent tracked-ability profiles per character, class, and role.
- HUD icons created from an ability in the action-bar window. Manual mode preserves each icon's independent mouse position; automatic vertical and horizontal modes move the complete icon group. Icons can be disabled directly with their `X` button or through the selected-ability editor in LAM.
- Character-wide HUD icon size from 32 to 128 pixels in LAM. Changing it resizes existing trackers without changing their saved top-left positions.
- Manual, vertical-by-priority, and horizontal-by-priority HUD arrangements. Vertical mode places `Always visible`, P1, P2, P3, P4, and P5 from top to bottom and puts equal-priority icons side by side. Horizontal mode places those groups from left to right and stacks equal-priority icons vertically.
- Automatic layouts reserve stable cells from every enabled tracker that is still slotted in the current profile. Activity conditions and the `Show all`/highest/two-highest policy only hide or show those cells, so ordinary combat-state and weapon-bar transitions do not reflow the remaining icons. Groups wrap to extra rows or columns when required by the screen size.
- Combat-state HUD refreshes are coalesced to a 100 ms cadence and skip unchanged ZOS UI writes, reducing pressure from player-effect, slot-effect and ultimate-resource event bursts during dense combat.
- Automatic-layout alignment, icon spacing, and priority-group spacing are configurable in LAM. Each class/role profile keeps separate normalized vertical and horizontal mouse-drag positions, while switching back to manual restores the untouched individual icon positions. Optional EZOCore `family.layout` integration can temporarily preview all configured cells for group positioning.
- Each visible HUD icon shows its native keyboard or gamepad action-slot binding underneath while the ability is on the active weapon bar. The binding is hidden when the ability is only on the other bar.
- Binding labels use a larger bold keyboard font and 120% native icon markup (previously 80%), with a 34-pixel footer and at least 112 pixels of width. Automatic layouts reserve this space; saved manual icon positions are unchanged.
- Hotbar-specific effective ability IDs are resolved for each bar, preventing weapon-dependent variants such as Blockade of Fire from changing tracked identity after a weapon swap.
- Visibility conditions: while slotted; while active and slotted; and while inactive and slotted. Normal ultimates use ready-to-cast as their active state.
- Layered state evidence from native slot timers, native toggles, same-ID effects on the player, ultimate resource readiness, and explicit per-ability providers. Missing API data remains `UNKNOWN`; an enabled and slotted tracker configured for inactivity is shown provisionally until positive evidence becomes available, without falsifying the underlying state.
- Verified state-variant ability-ID families are matched through a stable identity, so chained or greyed-out native IDs do not break slotted, active, or inactive tracking. New families are added only after their IDs are confirmed in ESO.
- Crystal Fragments uses an explicit proc provider: its slotted identity (`114716`) and proc cast variant (`46324`) preserve the tracker identity, while only the charged player proc effect (`46327`) marks it active. The separate three-second cost-reduction timer for the next non-Ultimate ability is deliberately ignored, so it cannot make Crystal Fragments appear active; the missing proc effect marks it inactive.
- Bound Armaments uses an explicit slot-stack provider: the active condition requires at least four native stacks (`24165` / `203447`) and the HUD shows the real count in the icon's lower-right corner. If the slot API is unavailable or returns zero, EZOCombat uses the specific player effect `203447` as a fallback and retries that read while the cached value is zero; fewer than four stacks are observed as inactive without changing the generic rules for other stack-based skills.
- Blighted Blastbones has an explicit native slot-timer provider, so a readable zero timer can establish its initial inactive state before the first cast; this bootstrap rule is reserved for abilities with a verified native negative signal.
- Cruxweaver Armor uses its explicit native slot timer, including a readable zero as initial inactive evidence. Barbed Trap and both effective Fulminating Rune resource variants use explicit 20-second cast cycles and can be inactive before their first cast because their useful activity is represented on the ground or target rather than by a reliable generic player effect.
- Proximity Detonation normalizes its effective (`63302`) and base progression (`61487`) IDs and uses the native slot-timer strategy, allowing a readable zero to establish inactivity before the first cast without merging the different Inevitable Detonation morph.
- Positive native toggle state is accepted and learned even when ESO omits toggle metadata. Banner Bearer (`217699`) and the configured Warden bear ultimate (`92163`) also have explicit toggle providers.
- Persisted capability learning: after EZOCombat observes a real slot timer or same-ID player effect for an ability, it can use that provider's later absence as reliable inactive evidence.
- Generic first-use protection: an inactive-condition tracker whose state is still `UNKNOWN` remains visible with debug reason `unknown-inactive-fallback`. Any observed timer, effect, toggle, or ultimate-resource state immediately resumes normal active/inactive visibility. This covers native-duration abilities such as Stampede without maintaining an ID whitelist.
- State providers follow documented, opt-in patterns for native slot timers, player effects, toggles, ultimate resources, and verified cast cycles. Missing generic evidence remains `UNKNOWN`; see [ability-state patterns](docs/ABILITY_STATE_PATTERNS.md).
- Verified timed activity for Warden Subterranean Assault and Deep Fissure, including their 6-second and 9-second active windows.
- Tracker categories `Always visible` and `P1` through `P5`. Always visible bypasses priority filtering but still respects the tracker's slotted, active, or inactive condition.
- Global priority management in LAM: show all eligible levels, only the highest eligible level, or the two highest eligible levels. The two-level mode skips empty levels, so eligible P1 and P3 abilities are shown when P2 has none.
- The LAM tracked-ability section uses one current-profile selector with enable and priority controls. Slotted trackers follow front-bar then back-bar slot order, while configured unslotted trackers are clearly labelled. It refreshes when bar contents, tracked abilities, or the active role profile change, both in standalone LAM and when hosted by EZOCore.
- LAM sections use the purple information icon for section-wide help; each individual setting keeps its specific help on that field.
- PvP enemy target frame limited by default to attackable player targets in AvA zones and active battlegrounds. It follows the target's projected head position and shows only the player's display name, a compact native-health bar, the normalized class icon, CP when available, and the normalized AvA rank icon.
- Configurable low-health alert that shows a warning icon for five seconds when the enemy target crosses below the selected percentage. Repeated health events do not restart the timer.
- Explicit PvE dummy-test scope for the target frame. When selected in LAM, the frame can follow the current attackable reticle target outside PvP so health, movement, and the low-health alert can be verified on dummies.
- Configurable target-frame hold time keeps the last target data at its last projected position for a short period after the reticle temporarily loses that target; setting it to zero hides the frame immediately.
- The target frame follows the projected position above the target's head automatically. Its vertical distance is configurable with `Height above target head`, while `Target-frame hold time` controls how long the last position remains after temporary reticle loss. It has no manual-move mode and does not capture mouse or gamepad input.
- Optional PvP inverted damage cone using ESO's native scrolling combat text. Its tip starts above the target's head, opens upward, and exposes adjustable tip distance, width, row spacing, and repeated-hit spacing. The default scope applies only to PvP player damage.
- Explicit PvE dummy-test scope for the inverted damage cone. When selected, EZOCombat also permits monster/dummy targets outside PvP and restores the previous SCT slot/cloud before switching between PvP and test scopes.
- English and Spanish runtime localization.
- Opt-in diagnostics through LAM or `/ezocombatdebug`, using LibDebugLogger and optional chat mirroring.

## Current Limits

The beta intentionally does not infer generic ability state from missing data. It does not yet provide:

- cooldown or remaining-duration percentages;
- automatic mapping when a slotted ability and its applied player effect use different ability IDs;
- verified class-specific semantics for every ability; toggled abilities use ESO's native toggle metadata and slot state, but still require in-client coverage;
- rotation, cast, weapon-swap, block, dodge, interrupt, synergy, or ultimate automation.
- a persistent focus target separate from ESO's current `reticleover` target; the PvP frame follows the currently selected attackable enemy player;
- PvP target health when ESO does not expose a valid maximum value.

Future state rules and alternate effect-ID mappings will be registered per ability ID only after their events and meaning are confirmed in ESO. An ability that exposes no verified provider remains `UNKNOWN`: its active condition is not shown, while its inactive-condition reminder is shown provisionally. If ESO never exposes positive evidence, the reminder can remain visible during use until a verified provider is added.

## Usage

1. Open the action-bar window from LAM, `/ezocombat`, or its ESO Controls binding (`Shift+NumPad 3` by default when free).
2. Right-click a slotted ability in either bar to keep its configuration open.
3. Enable its HUD icon and choose its visibility condition and `Always visible` or `P1`-`P5` category from the window selectors. In LAM, select any configured ability to edit its enabled state and priority, alongside the global priority-management mode.
4. Choose **Manual**, **Vertical by priority**, or **Horizontal by priority** in LAM. In manual mode, drag each visible icon independently with the right mouse button. In an automatic mode, drag any visible icon with the right mouse button to move the complete group; alignment and both spacing values are configurable, and each orientation keeps its own position. Use `Show all configured` while positioning every enabled and slotted tracker.
5. In the PvP enemy target section, enable the frame and low-health alert, choose **PvP only** for real PvP or **PvE dummy test** for dummy verification, choose the threshold, then adjust `Height above target head` and `Target-frame hold time`.
6. To test the optional damage display, enable **Use inverted PvP damage cone** in the PvP floating-damage section, choose **PvP only** or **PvE dummy test**, and tune the tip distance, cone width, row spacing, and minimum text spacing.

## Safety Limits

EZOCombat only observes configuration and displays information. It does not:

- cast abilities;
- change weapon bars automatically;
- execute combat rotations;
- chain multiple skills from one input;
- simulate keyboard or gamepad input;
- automate synergies, interrupts, dodges, blocks, ultimates, or prebuffs.

The player always decides and performs every combat action manually.

## Testing Notes

Verify in ESO:

- `/reloadui` completes without Lua errors;
- the PvP target frame initializes without a `BackdropControl` edge-texture error and its solid health fill remains visible;
- the window opens from LAM, `/ezocombat`, and an assigned binding;
- the target frame does not capture mouse or gamepad input, including while opening radial or utility wheels;
- keyboard, mouse, gamepad, chat/Enter, ESC, and normal menus retain their native behavior;
- both bars show five normal slots and an ultimate;
- changing a slotted ability refreshes the action-bar window immediately and after closing and reopening it;
- a tracked icon disappears when its ability is removed from both bars;
- Blockade of Fire and other hotbar-overridden abilities retain their tracked identity and eligible icon after swapping away from their bar;
- Blighted Blastbones, Blastbones, and Stalking Blastbones remain matched when ESO changes their native slot ID between normal and greyed-out states, including the inactive condition;
- Crystal Fragments appears with the active condition as soon as its instant/half-cost proc loads, ignores the separate three-second cost-reduction effect, remains matched across a weapon swap, and returns to inactive immediately after consuming or losing the proc;
- Bound Armaments appears with the active condition at four or more native stacks or via its player-effect fallback, shows the matching numeric count in the icon's lower-right corner, remains inactive below four stacks, and returns to inactive after the stacks are fired;
- Blighted Blastbones shows its inactive tracker on the first load when its native slot timer is readable, without requiring a prior cast;
- Deep Fissure remains active for its verified nine-second predicted window and becomes inactive when that window expires, without being overridden by a partial native slot timer;
- Arctic Blast and other native timed skills become active while their slot counter is positive and inactive after expiry; the observed timer capability remains available after `/reloadui`;
- EZOCombat HUD icons and the configuration window hide while ESO's interactive radial or utility wheels are open and return when the wheel closes;
- toggled abilities follow `IsAbilityDurationToggled` plus `IsSlotToggled`, while normal ultimate active and inactive mean ready and not ready to cast;
- Banner Bearer is active only while its native slot toggle is on and becomes inactive when the banner is disabled;
- skills without a verified provider remain `UNKNOWN`; their active condition stays hidden, while an enabled and slotted inactive-condition tracker remains provisionally visible with `eligibilityReason=unknown-inactive-fallback`;
- Cruxweaver Armor is visible before its first cast when configured as inactive, hides for its native active timer, and reappears when that timer ends;
- Barbed Trap and Fulminating Rune are visible before their first cast when configured as inactive, hide when cast, and reappear after their explicit 20-second cycle;
- Proximity Detonation is visible before its first cast when configured as inactive, hides during its native eight-second countdown, and reappears after detonation;
- Stampede is visible before its first cast when configured as inactive, hides when ESO starts its native 15-second ground-effect timer, and reappears after that timer expires, including across a weapon swap;
- `Show all` keeps every eligible priority level visible;
- `Highest visible priority` shows only the lowest numbered eligible P-level, plus every eligible Always visible icon;
- `Two highest visible priorities` shows the first two P-levels that contain eligible abilities, plus every eligible Always visible icon;
- manual, vertical, and horizontal arrangements switch without overwriting the saved manual positions;
- vertical mode orders Always visible and P1-P5 downward, keeps equal-priority icons in a horizontal row, and preserves empty cells while configured trackers are condition-hidden;
- horizontal mode orders the same groups left to right, stacks equal-priority icons vertically, and preserves those cells under the highest/two-highest priority filters;
- changing bars does not reorder automatic cells merely because the active weapon bar changed; replacing or moving a slotted ability intentionally recalculates the configured grid;
- dragging any icon in an automatic arrangement moves the complete group smoothly, and vertical/horizontal positions remain independent after `/reloadui`;
- Start, Centre, and End alignment, both spacing controls, automatic wrapping, position reset, and screen-resize recalculation behave without overlap at icon sizes from 32 to 128 pixels;
- the LAM configured-ability selector lists only the active class/role profile, follows current front/back slot order, labels configured unslotted trackers, updates after changing bar contents, creating a tracker, or changing profile without reopening Settings, and edits only the selected ability in both standalone LAM and EZOCore-hosted Settings;
- changing HUD icon size between 32 and 128 pixels resizes every current-character tracker, preserves its saved position, and remains applied after `/reloadui`;
- the binding below an icon follows the current keyboard/gamepad mode and is hidden when its ability is not on the active bar;
- dragging and disabling an icon persist through `/reloadui`;
- an icon follows the cursor smoothly while being dragged, even when combat or HUD state refreshes occur during the drag;
- in a dense combat or dummy stress test, repeated effect/resource changes do not cause visible freezes, interface errors, or icon jitter; static validation cannot prove this and it must be checked in ESO;
- `Show all configured` ignores activity and priority filtering only while selected, excludes disabled or unslotted trackers, and switches off when the action-bar window closes;
- in **PvP only**, the target frame remains hidden in PvE, against NPCs, against allied players, and when no attackable player target exists;
- in **PvE dummy test**, the target frame follows the current attackable reticle target outside PvP, including dummies, while class/CP/rank fields stay hidden when ESO provides no data;
- the PvP target frame updates when changing targets and when the target's native health changes;
- the display name, compact health bar, class icon, CP and normalized rank icon are shown only when ESO provides valid data;
- the target frame follows the projected position above the target's head while the target is eligible, updates at most every 100 ms, and honors the configured hold time after temporary reticle loss;
- the low-health warning appears once when the target crosses below the configured threshold, remains visible for five seconds, does not extend on repeated damage, and can trigger again after recovery;
- changing `Height above target head` moves the frame vertically while it continues to follow the target, and changing `Target-frame hold time` controls whether the last position remains after temporary reticle loss;
- the PvP target frame and warning hide while ESO's interactive radial or utility wheels are open and return when the wheel closes;
- in **PvP only**, the optional damage cone changes the native SCT position only in AvA or active battleground scenes, places the cone tip nearest the target head, and restores the previous SCT position and cloud when disabled or leaving PvP;
- in **PvE dummy test**, the optional damage cone can be tuned on monster/dummy targets outside PvP and restores the previous SCT position/cloud when disabled or when switching back to PvP-only scope;
- the optional PvP damage cone applies independently to keyboard and gamepad SCT clouds and does not create combat input or duplicate combat events;
- the window and HUD icons remain hidden outside HUD/HUD UI scenes.

Report issues with client API version, addon version, language, input mode, and the Lua error text.

For state or selector issues, enable **Debug** in LAM, reproduce the issue with the ability, then use **Capture configuration diagnostic** or `/ezocombatdebug`. The snapshot includes the stable ability ID, matched effect ID, phase, source, confidence, slot timer, duration, stacks, toggle, cooldown, ultimate resource, and current player-effect IDs. Include the EZOCombat entries from LibDebugLogger in the report; when that optional library is unavailable, EZOCombat writes the diagnostic to chat instead.

## License

EZOCombat is released under the MIT License. See [LICENSE](LICENSE).
