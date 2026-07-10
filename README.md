# EZOCombat

Prefer Spanish? Read the [Spanish README](README.es.md).

EZOCombat is an early public beta addon for **The Elder Scrolls Online** focused on safe combat assistance research for the EZO addon family.

Current scope is intentionally small: the addon loads, applies English/Spanish localization, exposes a basic `/ezocombat` command, and documents the intended safety boundaries for future visual combat helpers. It does not automate combat.

Support, bug reports, and suggestions: https://discord.gg/ekw8zUAcRm

## Beta Status

Version: `0.1.0-beta`

This beta is meant for public visibility, feedback, and controlled testing. Combat-helper feature work is still in design/prototype stage.

## Requirements

- The Elder Scrolls Online PC client.
- ESO API versions declared in the manifest: `101049 101050`.
- Optional developer/debug addons:
  - `LibDebugLogger`
  - `DebugLogViewer`

No external runtime or third-party Lua library is required for normal use.

## Installation

1. Download or clone this repository.
2. Copy the `EZOCombat` folder into your ESO AddOns directory:
   - Live: `Documents/Elder Scrolls Online/live/AddOns/EZOCombat`
   - PTS: `Documents/Elder Scrolls Online/pts/AddOns/EZOCombat`
3. Start ESO or run `/reloadui`.
4. Enable `EZOCombat` from the Add-Ons menu if needed.

## Current Features

- Minimal addon bootstrap through `EVENT_ADD_ON_LOADED`.
- English and Spanish runtime strings selected from the ESO client language.
- Load message confirming that no combat automation is active.
- `/ezocombat` slash command that prints the current conceptual status.
- Public documentation for future combat helper design.
- Explicit safety boundaries for visual assistance versus combat automation.

## Current Options

EZOCombat currently has no LibAddonMenu panel, no SavedVariables, no keybindings, and no user-configurable options.

## Planned Direction

The intended direction is a visual, manual combat assistant:

- detect configured action-bar abilities
- observe whether marked abilities appear to produce damage
- warn visually when a marked ability may have missed or stopped ticking
- support both keyboard/mouse and gamepad users without changing input behavior

These features are not implemented in this beta yet.

## Safety Limits

EZOCombat currently does not perform combat actions. Future work must stay inside these limits:

- cast abilities
- change weapon bars automatically
- run combat rotations
- chain multiple skills from one input
- simulate keyboard or gamepad input
- automate synergy, interrupt, dodge, block, ultimate, or prebuff execution

The addon may provide visual information, reminders, and diagnostics. The player must still decide and perform all combat actions manually.

## Testing Notes

For this beta, verify:

- the addon appears in ESO's Add-Ons list
- the addon loads without Lua errors
- `/reloadui` completes cleanly
- the load message appears in the configured language
- `/ezocombat` prints the localized status message
- keyboard and gamepad controls behave exactly as they did before enabling the addon
- no panel, overlay, keybind, or SavedVariables entry is created

Report issues with the ESO client version, addon version, language, input mode, and any Lua error text.

## License

EZOCombat is released under the MIT License. See [LICENSE](LICENSE).
