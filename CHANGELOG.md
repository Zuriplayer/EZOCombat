# Changelog

## 0.2.26-beta - 2026-08-17

- Seed Blighted Blastbones' initial inactive state from its verified readable zero slot timer, so the first cast is no longer required to learn the negative evidence.

## 0.2.25-beta - 2026-08-17

- Match verified native state variants through stable ability identities, fixing inactive tracking for Blighted Blastbones and the corresponding Blastbones families.

## 0.2.24-beta - 2026-08-16

- Hide EZOCombat HUD icons and the configuration window while ESO interactive radial or utility wheels are open, then restore them when the wheel closes.

## 0.2.23-beta - 2026-08-16

- Give the explicit Deep Fissure predicted provider precedence over incomplete native slot timing, so its active and inactive conditions follow the verified nine-second window.

## 0.2.21-beta - 2026-08-16

- Added a session-only `Show all configured` checkbox to the EZOCombat action-bar window.
- While enabled, every enabled tracker still slotted on the current profile's bars is shown for positioning without applying its activity condition or priority filter.
- Closing the action-bar window disables the positioning preview and restores normal visibility rules. The preview is local to EZOCombat and has no LAM or EZOCore integration.

## 0.2.20-beta - 2026-08-16

- Normalize every slotted ability through `GetEffectiveAbilityIdForAbilityOnHotbar` for its own hotbar category.
- Fixed hotbar-overridden abilities such as Blockade of Fire changing from their effective ID (`39012`) to the base ID (`39011`) when swapping bars, which incorrectly made their tracked icon disappear.

## 0.2.19-beta - 2026-08-16

- Added a global LAM priority policy with three modes: show every eligible level, show only the highest eligible level, or show the two highest eligible levels.
- Added the `Always visible` tracker category. These icons bypass priority-level filtering but continue to respect their assigned slotted, active, or inactive condition.
- Changed the two-level mode to select the two highest levels that currently contain eligible abilities, so P1 and P3 are shown when P2 has no eligible abilities.
- Added the native keyboard or gamepad action-slot binding below each visible HUD icon. The binding is shown only while that ability is present on the active weapon bar.

## 0.2.18-beta - 2026-08-16

- Treat any positive native `IsSlotToggled` response as observed activity, even when `IsAbilityDurationToggled` does not classify the ability beforehand.
- Persist learned toggle capability so the later false state becomes reliable inactive evidence.
- Registered Banner Bearer (`217699`) as a native toggle provider, covering its inactive state before the first activation.

## 0.2.17-beta - 2026-08-16

- Replaced the binary normal-ability check with a layered evidence engine that keeps active, inactive, ready, toggled, timed, and unknown states separate.
- Added observed providers for native slot timers, toggled abilities, same-ID player effects, and ultimate resource readiness. Cooldowns and stack counts are diagnostic data and no longer imply activity.
- Persist native timer and same-ID effect capabilities after they are observed, so a later zero or missing effect is valid negative evidence for that ability instead of a generic assumption.
- Seeded Arctic Blast (`86156`) as a native slot-timer provider and the configured Warden bear ultimate (`92163`) as a native toggle provider.
- Rebuild the player-effect registry from `GetUnitBuffInfo` after full effect updates and expose raw slot, toggle, cooldown, resource, confidence, and effect data in debug snapshots.
- Keep Subterranean Assault and Deep Fissure on explicit predicted providers when ESO does not expose a complete native activity cycle.

## 0.2.16-beta - 2026-08-15

- Re-evaluate active and inactive tracker conditions when native action-slot counters cross between zero and a positive value, including counters that expire without a final ESO event.
- Use native action-slot counters as the general normal-ability source and keep manual timers only for verified exceptions. Removed the broad `GetAbilityDuration` fallback, which could classify unrelated ability durations as active state.

## 0.2.15-beta - 2026-08-15

- Added a general timed activity provider for normal abilities using their native `GetAbilityDuration` after `EVENT_ACTION_SLOT_ABILITY_USED`. This covers abilities such as Arctic Blast whose applied effect can use a different ability ID from the slotted action.
- Kept explicit duration overrides for verified exceptions such as Subterranean Assault and Deep Fissure.

## 0.2.14-beta - 2026-08-15

- Added verified timed state providers for Subterranean Assault (6 s, `86019`) and Deep Fissure (9 s, `93778`) because their action-slot signal is incomplete. Both active and inactive conditions now resolve without relying on a missing slot effect.

## 0.2.13-beta - 2026-08-15

- Refined normal ability activity with the native action-slot effect first and matching real player-effect events as a secondary source. Debug snapshots now report the evaluated slot state and source data.

## 0.2.12-beta - 2026-08-15

- Defined active state for ultimates as ready to cast: current ultimate power meets the slot's native ultimate cost. Inactive means not ready. Normal abilities continue using their native action-slot effect state.

## 0.2.11-beta - 2026-08-15

- Added slotted, active-and-slotted, and inactive-and-slotted visibility conditions using native action-slot effect state and effect-update events.

## 0.2.10-beta - 2026-08-13

- Changed P1-P5 from visibility suppression to display ordering: every enabled, eligible icon remains visible regardless of its priority.

## 0.2.9-beta - 2026-08-13

- Moved ability-configuration selection to right-click only. The selected menu remains open until another ability is right-clicked or the same one is right-clicked again, and the active slot is highlighted.

## 0.2.8-beta - 2026-08-13

- Added a direct transparent `CT_BUTTON` target to every slotted ability after runtime traces showed no input delivery to either backdrop or texture controls.

## 0.2.7-beta - 2026-08-13

- Matched EZOArmory's direct skill-icon hierarchy: the visual frame, icon, and marker are now sibling controls in each action bar so the icon can receive mouse input.

## 0.2.6-beta - 2026-08-09

- Routed slot hover and click handling through each visible ability texture after in-client debug confirmed that the backdrop never received mouse events.

## 0.2.5-beta - 2026-08-09

- Added a left-click fallback that opens the same hovered-ability configurator and records whether the interaction came from hover or click.

## 0.2.4-beta - 2026-08-09

- Added chat fallback for diagnostics when LibDebugLogger is unavailable.

## 0.2.3-beta - 2026-08-09

- Added opt-in EZO-family debug controls, EZOCore debug-controller registration, LibDebugLogger output, optional chat mirroring, and `/ezocombatdebug` snapshots.
- Added diagnostic traces for action-bar reads, hovered slots, native selector availability, tracker changes, and priority resolution.

## 0.2.2-beta - 2026-08-08

- Added native visibility-condition and P1-P5 priority selectors to the hovered ability configurator.
- Prevented action-bar icon textures and slot markers from consuming hover input intended for their slot.

## 0.2.1-beta - 2026-08-08

- Made the EZOCombat title and context labels non-interactive so the full window header reliably starts dragging.

## 0.2.0-beta - 2026-08-08

- Added persistent class and role profiles with automatic Group Finder role detection and a manual fallback.
- Added a movable action-bar window, LAM panel, `/ezocombat` toggle command, and optional ESO Controls binding.
- Added movable HUD ability icons that are visible only while their ability remains slotted.
- Added P1-P5 priority resolution: equal highest-priority icons show together while lower priorities remain hidden.
- Kept combat state, cooldown, duration, and ultimate-ready detection out of this release pending in-client verification.

## 0.1.2-beta - 2026-07-19

- Expanded the manifest description so ESO's Add-ons screen lists the optional diagnostics and EZOCore integrations.

## 0.1.1-beta - 2026-07-14

- Added optional `EZOCore` language preference inheritance with fallback to the ESO client language.
- Registered an optional `EZOCore` language-change callback when the shared service is available.
- Updated public documentation for the optional language integration.

## 0.1.0-beta - 2026-07-10

- Prepared the addon for public beta publication.
- Kept runtime scope minimal: addon bootstrap, localization, and `/ezocombat`.
- Documented combat automation safety limits and planned visual-helper direction.
- Added repository hygiene for public release.
- Added MIT license.
