# EZOCombat

Prefer Spanish? Read the [Spanish README](README.es.md).

EZOCombat is a visual, manual action-bar helper for **The Elder Scrolls Online**. It never casts abilities, changes weapon bars, or simulates player input.

Support, bug reports, and suggestions: https://discord.gg/ekw8zUAcRm

## Beta Status

Version: `0.2.35-beta`

This functional beta provides the persistent UI, priority foundation, and a layered ability-state engine. Ability-specific effect mappings, remaining-time thresholds, and class rule packs still require separate in-client verification.

## Requirements

- The Elder Scrolls Online PC client.
- `LibAddonMenu-2.0`.
- ESO API versions declared in the manifest: `101049 101050`.
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
- HUD icons created from an ability in the action-bar window. Icons can be moved and disabled directly with their `X` button or through the selected-ability editor in LAM.
- Character-wide HUD icon size from 32 to 128 pixels in LAM. Changing it resizes existing trackers without changing their saved top-left positions.
- Each visible HUD icon shows its native keyboard or gamepad action-slot binding underneath while the ability is on the active weapon bar. The binding is hidden when the ability is only on the other bar.
- Hotbar-specific effective ability IDs are resolved for each bar, preventing weapon-dependent variants such as Blockade of Fire from changing tracked identity after a weapon swap.
- Visibility conditions: while slotted; while active and slotted; and while inactive and slotted. Normal ultimates use ready-to-cast as their active state.
- Layered state evidence from native slot timers, native toggles, same-ID effects on the player, ultimate resource readiness, and explicit per-ability providers. Missing API data remains `UNKNOWN`; an enabled and slotted tracker configured for inactivity is shown provisionally until positive evidence becomes available, without falsifying the underlying state.
- Verified state-variant ability-ID families are matched through a stable identity, so chained or greyed-out native IDs do not break slotted, active, or inactive tracking. New families are added only after their IDs are confirmed in ESO.
- Crystal Fragments uses an explicit proc family: its slotted identity (`114716`), proc cast variant (`46324`), and player proc effect (`46327`) are matched without relying on localized names. The effect's presence is active evidence and its verified absence is inactive evidence.
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
- PvP enemy target frame limited to attackable player targets in AvA zones and active battlegrounds. It shows the target name, native current/max health and percentage, class and alliance icons, level or CP, and AvA rank when ESO provides those values.
- Configurable low-health alert that shows a warning icon for five seconds when the enemy target crosses below the selected percentage. Repeated health events do not restart the timer.
- Mouse-only PvP target-frame positioning preview with a persisted position. It is available only in PvP HUD scenes and never forces the frame visible during normal gameplay without an eligible target.
- Optional PvP inverted damage cone using ESO's native scrolling combat text. Its tip starts above the target's head, opens upward, and exposes adjustable tip distance, width, row spacing, and repeated-hit spacing. The standard SCT position and cloud are restored outside PvP or when the feature is disabled.
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
4. Adjust **HUD icon size** in LAM if required, then drag a visible icon to its preferred HUD position. Use its `X` button or the selected-ability LAM checkbox to disable it.
5. In the PvP enemy target section, enable the frame and low-health alert, choose the threshold, and enable **Move PvP target frame** to drag its preview with the mouse while in an AvA zone or active battleground.
6. To test the optional damage display, enable **Use inverted PvP damage cone** in the PvP floating-damage section and tune the tip distance, cone width, row spacing, and minimum text spacing. It affects ESO's native SCT damage slot only while in PvP.

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
- keyboard, mouse, gamepad, chat/Enter, ESC, and normal menus retain their native behavior;
- both bars show five normal slots and an ultimate;
- changing a slotted ability refreshes the action-bar window immediately and after closing and reopening it;
- a tracked icon disappears when its ability is removed from both bars;
- Blockade of Fire and other hotbar-overridden abilities retain their tracked identity and eligible icon after swapping away from their bar;
- Blighted Blastbones, Blastbones, and Stalking Blastbones remain matched when ESO changes their native slot ID between normal and greyed-out states, including the inactive condition;
- Crystal Fragments appears with the active condition as soon as its proc loads, remains matched across a weapon swap, and returns to inactive immediately after consuming or losing the proc;
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
- the LAM configured-ability selector lists only the active class/role profile, follows current front/back slot order, labels configured unslotted trackers, updates after changing bar contents, creating a tracker, or changing profile without reopening Settings, and edits only the selected ability in both standalone LAM and EZOCore-hosted Settings;
- changing HUD icon size between 32 and 128 pixels resizes every current-character tracker, preserves its saved position, and remains applied after `/reloadui`;
- the binding below an icon follows the current keyboard/gamepad mode and is hidden when its ability is not on the active bar;
- dragging and disabling an icon persist through `/reloadui`;
- an icon follows the cursor smoothly while being dragged, even when combat or HUD state refreshes occur during the drag;
- `Show all configured` ignores activity and priority filtering only while selected, excludes disabled or unslotted trackers, and switches off when the action-bar window closes;
- the PvP target frame remains hidden in PvE, against NPCs, against allied players, and when no attackable player target exists;
- the PvP target frame updates when changing targets and when the target's native health changes;
- class and alliance icons, level/CP, rank, and health values are shown only when ESO provides valid data;
- the low-health warning appears once when the target crosses below the configured threshold, remains visible for five seconds, does not extend on repeated damage, and can trigger again after recovery;
- enabling the PvP target-frame move mode shows a temporary preview only in PvP HUD scenes, mouse dragging persists its position, and disabling the mode removes the preview;
- the PvP target frame and warning hide while ESO's interactive radial or utility wheels are open and return when the wheel closes;
- the optional PvP damage cone changes the native SCT position only in AvA or active battleground scenes, places the cone tip nearest the target head, and restores the previous SCT position and cloud when disabled or leaving PvP;
- the optional PvP damage cone applies independently to keyboard and gamepad SCT clouds and does not create combat input or duplicate combat events;
- the window and HUD icons remain hidden outside HUD/HUD UI scenes.

Report issues with client API version, addon version, language, input mode, and the Lua error text.

For state or selector issues, enable **Debug** in LAM, reproduce the issue with the ability, then use **Capture configuration diagnostic** or `/ezocombatdebug`. The snapshot includes the stable ability ID, matched effect ID, phase, source, confidence, slot timer, duration, stacks, toggle, cooldown, ultimate resource, and current player-effect IDs. Include the EZOCombat entries from LibDebugLogger in the report; when that optional library is unavailable, EZOCombat writes the diagnostic to chat instead.

## License

EZOCombat is released under the MIT License. See [LICENSE](LICENSE).
