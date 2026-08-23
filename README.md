# EZOCombat

Prefer Spanish? Read the [Spanish README](README.es.md).

EZOCombat is a visual, manual action-bar helper for **The Elder Scrolls Online**. It never casts abilities, changes weapon bars, or simulates player input.

Support, bug reports, and suggestions: https://discord.gg/ekw8zUAcRm

## Beta Status

Version: `0.2.21-beta`

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
- Window access through the EZOCombat LAM panel, `/ezocombat`, or an optional binding in ESO Controls.
- Automatic class detection and automatic role selection from the role selected in the Group Finder.
- Manual role selection in LAM when automatic role detection is off. The fallback role is Damage.
- Persistent tracked-ability profiles per character, class, and role.
- HUD icons created from an ability in the action-bar window. Icons can be moved and disabled directly with their `X` button or from LAM.
- Each visible HUD icon shows its native keyboard or gamepad action-slot binding underneath while the ability is on the active weapon bar. The binding is hidden when the ability is only on the other bar.
- Hotbar-specific effective ability IDs are resolved for each bar, preventing weapon-dependent variants such as Blockade of Fire from changing tracked identity after a weapon swap.
- Visibility conditions: while slotted; while active and slotted; and while inactive and slotted. Normal ultimates use ready-to-cast as their active state.
- Layered state evidence from native slot timers, native toggles, same-ID effects on the player, ultimate resource readiness, and explicit per-ability providers. Missing API data remains `UNKNOWN` and does not count as inactive.
- Verified state-variant ability-ID families are matched through a stable identity, so chained or greyed-out native IDs do not break slotted, active, or inactive tracking. New families are added only after their IDs are confirmed in ESO.
- Blighted Blastbones has an explicit native slot-timer provider, so a readable zero timer can establish its initial inactive state before the first cast; this bootstrap rule is reserved for abilities with a verified native negative signal.
- Positive native toggle state is accepted and learned even when ESO omits toggle metadata. Banner Bearer (`217699`) and the configured Warden bear ultimate (`92163`) also have explicit toggle providers.
- Persisted capability learning: after EZOCombat observes a real slot timer or same-ID player effect for an ability, it can use that provider's later absence as reliable inactive evidence.
- Verified timed activity for Warden Subterranean Assault and Deep Fissure, including their 6-second and 9-second active windows.
- Tracker categories `Always visible` and `P1` through `P5`. Always visible bypasses priority filtering but still respects the tracker's slotted, active, or inactive condition.
- Global priority management in LAM: show all eligible levels, only the highest eligible level, or the two highest eligible levels. The two-level mode skips empty levels, so eligible P1 and P3 abilities are shown when P2 has none.
- English and Spanish runtime localization.
- Opt-in diagnostics through LAM or `/ezocombatdebug`, using LibDebugLogger and optional chat mirroring.

## Current Limits

The beta intentionally does not infer generic ability state from missing data. It does not yet provide:

- cooldown or remaining-duration percentages;
- automatic mapping when a slotted ability and its applied player effect use different ability IDs;
- verified class-specific semantics for every ability; toggled abilities use ESO's native toggle metadata and slot state, but still require in-client coverage;
- rotation, cast, weapon-swap, block, dodge, interrupt, synergy, or ultimate automation.

Future state rules and alternate effect-ID mappings will be registered per ability ID only after their events and meaning are confirmed in ESO. An ability that exposes no verified provider remains `UNKNOWN`, so neither its active nor inactive condition is shown.

## Usage

1. Open the action-bar window from LAM, `/ezocombat`, or the optional Controls binding.
2. Right-click a slotted ability in either bar to keep its configuration open.
3. Enable its HUD icon and choose its visibility condition and `Always visible` or `P1`-`P5` category from the window selectors. LAM provides the same category selector and the global priority-management mode.
4. Drag a visible icon to its preferred HUD position. Use its `X` button or its LAM checkbox to disable it.

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
- the window opens from LAM, `/ezocombat`, and an assigned binding;
- keyboard, mouse, gamepad, chat/Enter, ESC, and normal menus retain their native behavior;
- both bars show five normal slots and an ultimate;
- changing a slotted ability refreshes the action-bar window immediately and after closing and reopening it;
- a tracked icon disappears when its ability is removed from both bars;
- Blockade of Fire and other hotbar-overridden abilities retain their tracked identity and eligible icon after swapping away from their bar;
- Blighted Blastbones, Blastbones, and Stalking Blastbones remain matched when ESO changes their native slot ID between normal and greyed-out states, including the inactive condition;
- Blighted Blastbones shows its inactive tracker on the first load when its native slot timer is readable, without requiring a prior cast;
- Deep Fissure remains active for its verified nine-second predicted window and becomes inactive when that window expires, without being overridden by a partial native slot timer;
- Arctic Blast and other native timed skills become active while their slot counter is positive and inactive after expiry; the observed timer capability remains available after `/reloadui`;
- EZOCombat HUD icons and the configuration window hide while ESO's interactive radial or utility wheels are open and return when the wheel closes;
- toggled abilities follow `IsAbilityDurationToggled` plus `IsSlotToggled`, while normal ultimate active and inactive mean ready and not ready to cast;
- Banner Bearer is active only while its native slot toggle is on and becomes inactive when the banner is disabled;
- skills without a verified provider remain `UNKNOWN` rather than appearing as inactive;
- `Show all` keeps every eligible priority level visible;
- `Highest visible priority` shows only the lowest numbered eligible P-level, plus every eligible Always visible icon;
- `Two highest visible priorities` shows the first two P-levels that contain eligible abilities, plus every eligible Always visible icon;
- the binding below an icon follows the current keyboard/gamepad mode and is hidden when its ability is not on the active bar;
- dragging and disabling an icon persist through `/reloadui`;
- an icon follows the cursor smoothly while being dragged, even when combat or HUD state refreshes occur during the drag;
- `Show all configured` ignores activity and priority filtering only while selected, excludes disabled or unslotted trackers, and switches off when the action-bar window closes;
- the window and HUD icons remain hidden outside HUD/HUD UI scenes.

Report issues with client API version, addon version, language, input mode, and the Lua error text.

For state or selector issues, enable **Debug** in LAM, reproduce the issue with the ability, then use **Capture configuration diagnostic** or `/ezocombatdebug`. The snapshot includes phase, source, confidence, slot timer, duration, stacks, toggle, cooldown, ultimate resource, and current player-effect IDs. Include the EZOCombat entries from LibDebugLogger in the report; when that optional library is unavailable, EZOCombat writes the diagnostic to chat instead.

## License

EZOCombat is released under the MIT License. See [LICENSE](LICENSE).
