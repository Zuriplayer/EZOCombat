-- Standalone Lua 5.1 regression harness. Never loaded by the addon manifest.
-- Run from the repository root with a desktop Lua interpreter.
local now, tests = 1000, 0
local calls = { slot = 0, buff = 0, captures = 0, paints = 0, resolves = 0 }
local updates, events = {}, {}
local function check(value, message)
    assert(value, message)
    tests = tests + 1
end
local function advance(ms)
    local finish = now + ms
    while true do
        local name, nextTime
        for key, update in pairs(updates) do
            if update.at <= finish and (not nextTime or update.at < nextTime) then
                name, nextTime = key, update.at
            end
        end
        if not name then break end
        now = nextTime
        local update = updates[name]
        update.at = now + update.interval
        update.callback()
    end
    now = finish
end
local eventNames = {
    "EVENT_ACTION_SLOT_UPDATED", "EVENT_HOTBAR_SLOT_UPDATED", "EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED",
    "EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED", "EVENT_PLAYER_ACTIVATED", "EVENT_ACTION_SLOT_EFFECT_UPDATE",
    "EVENT_ACTION_SLOT_EFFECTS_CLEARED", "EVENT_POWER_UPDATE", "EVENT_ULTIMATE_ABILITY_COST_CHANGED",
    "EVENT_EFFECT_CHANGED", "EVENT_EFFECTS_FULL_UPDATE", "EVENT_ACTION_SLOT_ABILITY_USED",
    "EVENT_RETICLE_TARGET_CHANGED", "EVENT_RETICLE_TARGET_PLAYER_CHANGED", "EVENT_UNIT_DEATH_STATE_CHANGED",
    "EVENT_UNIT_CREATED", "EVENT_UNIT_DESTROYED", "EVENT_ZONE_CHANGED", "EVENT_TARGET_MARKER_UPDATE",
}
for _, name in ipairs(eventNames) do _G[name] = name end
EVENT_MANAGER = {}
function EVENT_MANAGER:RegisterForUpdate(name, interval, callback)
    updates[name] = { interval = interval, callback = callback, at = now + interval }
end
function EVENT_MANAGER:UnregisterForUpdate(name) updates[name] = nil end
function EVENT_MANAGER:RegisterForEvent(name, event, callback)
    events[name .. ":" .. event] = callback
end
function EVENT_MANAGER:UnregisterForEvent(name, event) events[name .. ":" .. event] = nil end
function EVENT_MANAGER:AddFilterForEvent() end
local function fire(name, event, ...)
    local callback = events[name .. ":" .. event]
    if callback then callback(event, ...) end
end
HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP = 1, 2
ACTION_BAR_FIRST_NORMAL_SLOT_INDEX, ACTION_BAR_ULTIMATE_SLOT_INDEX = 2, 7
COMBAT_UNIT_TYPE_PLAYER, COMBAT_MECHANIC_FLAGS_ULTIMATE = 1, 10
COMBAT_MECHANIC_FLAGS_HEALTH = 1
REGISTER_FILTER_UNIT_TAG, REGISTER_FILTER_POWER_TYPE = 1, 2
EFFECT_RESULT_FADED = 2
local slots = { [1] = {}, [2] = {} }
local stacks, remaining, buffStacks, ultimate = 0, 0, 0, 0
local activeBar = 1
GetFrameTimeMilliseconds = function() return now end
GetFrameTimeSeconds = function() return now / 1000 end
GetSlotBoundId = function(slot, bar)
    calls.captures = calls.captures + 1
    return slots[bar or activeBar][slot] or 0
end
GetEffectiveAbilityIdForAbilityOnHotbar = function(id) return id end
GetAbilityName = function(id) return tostring(id) end
GetAbilityIcon = function(id) return "icon" .. tostring(id) end
zo_strformat = function(_, text) return text end
GetActionSlotEffectStackCount = function() calls.slot = calls.slot + 1; return stacks end
GetActionSlotEffectTimeRemaining = function() return remaining end
GetActionSlotEffectDuration = function() return remaining end
IsSlotToggled = function() return false end
IsAbilityDurationToggled = function() return false end
GetActiveHotbarCategory = function() return activeBar end
GetUnitPower = function() return ultimate end
GetSlotAbilityCost = function() return 100 end
GetNumBuffs = function() return 40 end
GetUnitBuffInfo = function(_, index)
    calls.buff = calls.buff + 1
    local id = index == 40 and buffStacks > 0 and 203447 or 70000 + index
    return "effect", now / 1000, now / 1000 + 10, index, buffStacks, nil, nil, nil, nil, nil, id, nil, true
end
local profile = { trackers = {} }
EZOCombat = {
    name = "EZOCombat", sv = { general = { enabled = true }, abilityState = {}, layout = {} },
    Context = { GetActiveProfile = function() return profile end },
    IsDebugModeEnabled = function() return false end,
}
dofile("modules/ability_state.lua")
dofile("modules/priority.lua")
dofile("modules/action_bars.lua")
dofile("modules/layout.lua")
local addon = EZOCombat
local resolve = addon.AbilityState.Resolve
addon.AbilityState.Resolve = function(...)
    calls.resolves = calls.resolves + 1
    return resolve(...)
end
addon.Overlays = { Refresh = function()
    calls.paints = calls.paints + 1
    addon.ActionBars.SyncTracking()
    for _, tracker in ipairs(addon.Priority.Evaluate()) do
        if addon.AbilityState.IsSlotStackProvider(tracker.abilityId) then
            addon.ActionBars.GetAbilityState(tracker.abilityId)
        end
    end
end }
local function tracker(id, condition, priority)
    local t = { id = "ability-" .. id, abilityId = id, enabled = true,
        condition = condition or "active", priority = priority or 1 }
    profile.trackers[t.id] = t
    addon.Priority.Invalidate()
    return t
end
addon.AbilityState.Init()
local bound = tracker(24165)
addon.ActionBars.Init()
advance(1000)
check(calls.buff == 0 and calls.slot == 0, "unslotted tracker must perform no buff/slot reads")
check(not updates.EZOCombatAbilityStates, "no periodic state work without slotted consumers")
check(not events["EZOCombatPlayerEffects:" .. EVENT_EFFECT_CHANGED], "no effect listener without consumers")
slots[1][3] = 24165
addon.ActionBars.Refresh("test-slot")
check(updates.EZOCombatAbilityStates ~= nil, "slotting starts state ticker")
local beforeBuff = calls.buff
advance(1000)
check(calls.buff - beforeBuff <= 80, "zero fallback scan bounded to twice per second")
beforeBuff = calls.buff
stacks = 4
local beforeResolve = calls.resolves
advance(100)
local state = addon.ActionBars.GetAbilityState(24165)
check(state.active and state.stacks == 4, "four native stacks activate Bound")
check(calls.resolves - beforeResolve == 1, "poll, priority and counter share one resolution")
check(calls.buff == beforeBuff, "positive native stack count bypasses buff scan")
stacks = 5
local beforePaint = calls.paints
advance(100)
check(calls.paints == beforePaint + 1 and addon.ActionBars.GetAbilityState(24165).stacks == 5,
    "stack-only changes refresh counter")
beforePaint = calls.paints
for _ = 1, 100 do fire("EZOCombatActionSlotEffect", EVENT_ACTION_SLOT_EFFECT_UPDATE) end
advance(100)
check(calls.paints == beforePaint, "unchanged state event bursts must not repaint")
check(not addon.AbilityState.HandleEffectChanged(1, 1, 0, 0, 1, 999999, 1), "unrelated effects ignored")
check(next(addon.AbilityState.activeEffects) == nil, "unrelated effects not stored")
stacks = 0
addon.AbilityState.HandleEffectChanged(1, 40, now / 1000, now / 1000 + 10, 6, 203447, 1)
advance(100)
check(addon.ActionBars.GetAbilityState(24165).stacks == 6, "player effect fallback remains functional")
addon.AbilityState.HandleEffectChanged(EFFECT_RESULT_FADED, 40, 0, 0, 0, 203447, 1)
advance(100)
check(not addon.ActionBars.GetAbilityState(24165).active, "faded stacks stop activity")
addon.sv.general.enabled = false
addon.Overlays.Refresh()
local beforeSlot = calls.slot
beforeBuff = calls.buff
advance(1000)
check(calls.slot == beforeSlot and calls.buff == beforeBuff, "HUD off performs no state queries")
check(not updates.EZOCombatAbilityStates, "HUD off unregisters ticker")
addon.sv.general.enabled = true
addon.Overlays.Refresh()
check(updates.EZOCombatAbilityStates ~= nil, "HUD on restores ticker")
slots[1][3], slots[2][3] = nil, 24165
local beforeCapture = calls.captures
for _ = 1, 20 do fire("EZOCombatActionSlots", EVENT_ACTION_SLOT_UPDATED) end
advance(1)
check(calls.captures - beforeCapture == 12, "slot event burst captures both bars once")
check(addon.ActionBars.IsAbilitySlotted(24165), "backup bar still tracked")
check(addon.ActionBars.GetActiveEntryForAbility(24165) == nil, "backup-only binding hidden")
activeBar = 2
check(addon.ActionBars.GetActiveEntryForAbility(24165).hotbar == "back", "active backup binding resolved")
slots[2][3] = nil
fire("EZOCombatActionSlots", EVENT_ACTION_SLOT_UPDATED)
advance(1)
beforeSlot, beforeBuff = calls.slot, calls.buff
advance(1000)
check(calls.slot == beforeSlot and calls.buff == beforeBuff, "removing last slot stops all ability reads")
check(not updates.EZOCombatAbilityStates and not next(addon.AbilityState.predictions), "last removal clears runtime")
slots[1][3] = 114716
local crystal = tracker(114716)
addon.ActionBars.Refresh("crystal")
remaining = 3000
advance(100)
check(not addon.ActionBars.GetAbilityState(114716).active, "Crystal cost timer is not proc readiness")
addon.AbilityState.HandleEffectChanged(1, 7, now / 1000, now / 1000 + 2, 1, 46327, 2)
advance(100)
check(addon.ActionBars.GetAbilityState(114716).active, "Crystal exact proc accepted including non-player source")
advance(2100)
check(not addon.ActionBars.GetAbilityState(114716).active, "expired proc disappears without final event")
slots[1][8] = 999
tracker(999)
addon.ActionBars.Refresh("ultimate")
ultimate = 100
advance(100)
check(addon.ActionBars.GetAbilityState(999).ready, "normal ultimate resource still determines readiness")
ultimate = 0
advance(100)
check(not addon.ActionBars.GetAbilityState(999).active, "ultimate consumption reflected")
addon.Priority.SetCondition(crystal, "slotted")
addon.Priority.SetEnabled(profile.trackers["ability-999"], false)
check(not updates.EZOCombatAbilityStates, "ordinary slotted-only trackers need no state ticker")
addon.Priority.SetCondition(crystal, "inactive")
addon.Priority.SetPriority(crystal, 2)
addon.Priority.SetEnabled(bound, false)
GuiRoot = { GetWidth = function() return 1920 end, GetHeight = function() return 1080 end }
addon.sv.layout.mode = "vertical"
local firstLayout = addon.Layout.Calculate(54, 20)
check(firstLayout == addon.Layout.Calculate(54, 20), "unchanged layout returns same cached result")
check(firstLayout ~= addon.Layout.Calculate(64, 20), "icon size invalidates layout")
addon.Priority.SetPriority(crystal, 3)
check(firstLayout ~= addon.Layout.Calculate(54, 20), "priority changes invalidate layout")
local oldProfile = profile
profile = { trackers = {} }
addon.Overlays.Refresh()
check(not updates.EZOCombatAbilityStates, "empty profile suspends old tracking")
profile = oldProfile
addon.Overlays.Refresh()
check(updates.EZOCombatAbilityStates ~= nil, "returning profile restores tracking")
-- Disabled PvP frame must not create any controls or receive target events.
addon.sv.pvpTarget = { enabled = false, scope = "pvp" }
WINDOW_MANAGER = { CreateTopLevelWindow = function() error("disabled target created UI") end }
SCENE_MANAGER = { IsShowing = function() return true end, RegisterCallback = function() end }
dofile("modules/pvp_target.lua")
addon.PvpTarget.Init()
check(not addon.PvpTarget.root, "disabled frame creates no controls")
check(not events["EZOCombatPvpTarget:" .. EVENT_POWER_UPDATE], "disabled frame has no health listener")
check(not updates.EZOCombatPvpTargetWorldPosition, "disabled frame has no projection ticker")
-- Predicted cycles are only listened to when a selected, slotted provider needs them.
activeBar = 1
slots[1][4], slots[1][5] = 93778, 40382
tracker(93778)
addon.ActionBars.Refresh("prediction")
check(events["EZOCombatPredictedActivities:" .. EVENT_ACTION_SLOT_ABILITY_USED] ~= nil, "prediction listener selected")
fire("EZOCombatPredictedActivities", EVENT_ACTION_SLOT_ABILITY_USED, 5)
check(not addon.AbilityState.predictions[40382], "unconfigured cast cannot start prediction")
fire("EZOCombatPredictedActivities", EVENT_ACTION_SLOT_ABILITY_USED, 4)
check(addon.AbilityState.predictions[93778] ~= nil, "tracked cast starts prediction")
slots[1][4] = nil
addon.ActionBars.Refresh("remove-prediction")
check(not addon.AbilityState.predictions[93778], "unslotting prunes prediction immediately after capture")
check(not events["EZOCombatPredictedActivities:" .. EVENT_ACTION_SLOT_ABILITY_USED], "prediction listener removed independently")
-- All/highest/top-two policies preserve ALWAYS and do not admit disabled/unslotted trackers.
slots[1][3], slots[1][4], slots[1][5], slots[1][6] = 1001, 1002, 1003, 1004
tracker(1001, "slotted", 0)
tracker(1002, "slotted", 1)
tracker(1003, "slotted", 2)
tracker(1004, "slotted", 3)
addon.ActionBars.Refresh("priorities")
addon.Priority.SetMode("all")
check(#addon.Priority.Evaluate() == 4, "all priority levels visible")
addon.Priority.SetMode("highest")
check(#addon.Priority.Evaluate() == 2, "ALWAYS plus highest priority")
addon.Priority.SetMode("top_two")
check(#addon.Priority.Evaluate() == 3, "ALWAYS plus two highest priorities")
check(#addon.Priority.Evaluate(true) == 4, "preview bypasses priority but not slot selection")
addon.Priority.SetEnabled(profile.trackers["ability-1004"], false)
check(#addon.Priority.Evaluate(true) == 3, "preview excludes disabled tracker")
check(not events["EZOCombatUltimatePower:" .. EVENT_POWER_UPDATE], "ultimate listener removed when ultimate tracker disabled")

-- Exercise the real rendering module with controls which count native UI writes.
local writes = { font = 0, text = 0, texture = 0, anchors = 0 }
local methods = {}
function methods:IsHidden() return self.hidden == true end
function methods:SetHidden(value) self.hidden = value end
function methods:SetDimensions(w, h) self.width, self.height = w, h end
function methods:GetWidth() return self.width or 1920 end
function methods:GetHeight() return self.height or 1080 end
function methods:GetParent() return self.parent end
function methods:SetParent(parent) self.parent = parent end
function methods:SetFont(font) self.font = font; writes.font = writes.font + 1 end
function methods:SetText(text) self.text = text; writes.text = writes.text + 1 end
function methods:SetTexture() writes.texture = writes.texture + 1 end
function methods:ClearAnchors() writes.anchors = writes.anchors + 1 end
function methods:SetHandler(name, callback) self.handlers[name] = callback end
function methods:GetLeft() return 123 end
function methods:GetTop() return 234 end
function methods:GetCenter() return 640, 480 end
local noop = function() end
for _, name in ipairs({ "SetMovable", "SetMouseEnabled", "SetClampedToScreen", "SetAnchor", "SetAnchorFill",
    "SetEdgeTexture", "SetCenterColor", "SetColor", "SetHorizontalAlignment", "SetVerticalAlignment",
    "SetDrawLayer", "SetNormalFontColor", "SetMouseOverFontColor", "SetWidth", "Create3DRenderSpace" }) do
    methods[name] = noop
end
local function control(parent)
    return setmetatable({ parent = parent, handlers = {} }, { __index = methods })
end
WINDOW_MANAGER.CreateTopLevelWindow = function() return control() end
WINDOW_MANAGER.CreateControl = function(_, _, parent) return control(parent) end
for _, name in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "CENTER", "TOP", "BOTTOM",
    "CT_CONTROL", "CT_BACKDROP", "CT_TEXTURE", "CT_LABEL", "CT_BUTTON", "DL_OVERLAY", "TEXT_ALIGN_RIGHT",
    "TEXT_ALIGN_BOTTOM", "TEXT_ALIGN_CENTER" }) do _G[name] = name end
local hudShowing = true
SCENE_MANAGER.IsShowing = function() return hudShowing end
local bindingRegistrations = 0
ZO_Keybindings_RegisterLabelForBindingUpdate = function(label, _, _, _, callback, _, _, scale)
    bindingRegistrations = bindingRegistrations + 1
    label.nativeScale = scale
    label:SetText("native-binding")
    callback(label, "native-binding")
end
ZO_Keybindings_UnregisterLabelForBindingUpdate = noop
dofile("modules/overlays.lua")
addon.Overlays.Refresh()
local firstRegistrations = bindingRegistrations
local fonts, textures, texts, anchors = writes.font, writes.texture, writes.text, writes.anchors
addon.Overlays.Refresh()
check(writes.font == fonts and writes.texture == textures and writes.text == texts
    and writes.anchors == anchors, "unchanged real HUD skips font/text/texture/anchor writes")
local icon = addon.Overlays.controls["ability-1001"]
check(icon.binding.nativeScale == 120 and icon.binding.font == "ZoFontGameBold", "native glyph scale and keyboard font enlarged")
check(icon.binding:GetWidth() >= 112 and icon.binding:GetHeight() == 34, "larger binding footer reserved")
check(bindingRegistrations == firstRegistrations, "unchanged refresh does not reregister native binding")
activeBar = 2
addon.Overlays.Refresh()
check(icon.binding:IsHidden(), "real binding hidden when skill leaves active bar")
activeBar = 1
addon.Overlays.Refresh()
check(not icon.binding:IsHidden(), "real binding restored on active bar")
icon.handlers.OnMouseEnter(icon)
check(icon ~= nil, "cached ability metadata remains available to tooltip handler")
addon.Overlays.SetIconSize(80)
check(writes.font > fonts, "icon size change updates real label font")
addon.sv.layout.mode = "manual"
addon.Priority.SetPosition(profile.trackers["ability-1001"], 123, 234)
addon.Overlays.Refresh()
check(icon.ezoCombatAnchorX == 123 and icon.ezoCombatAnchorY == 234, "manual saved positions retained")
icon.ezoCombatMoving = true
anchors = writes.anchors
addon.Overlays.Refresh()
check(writes.anchors == anchors, "refresh does not reanchor moving icon")
icon.ezoCombatMoving = false
hudShowing = false
addon.Overlays.Refresh()
check(addon.Overlays.root:IsHidden(), "HUD hidden in non-HUD scene")
hudShowing = true
addon.Overlays.Refresh()
check(not addon.Overlays.root:IsHidden(), "HUD restored after scene change")

-- Window closed must perform no slot setters, even when its controls exist.
dofile("modules/window.lua")
addon.Window.bars = { front = { slots = { { icon = control(), target = control(), marker = control(), frame = control() } } } }
texts, textures = writes.text, writes.texture
addon.Window.RefreshBars()
check(writes.text == texts and writes.texture == textures, "closed window performs no slot UI writes")
addon.Window.requestedVisible = true
addon.Window.RefreshBars()
check(writes.texture > textures, "opening window can populate refreshed slots")
addon.Window.requestedVisible = false

-- Target lifecycle and slower identity metadata, using the same native API surface.
local metadataCalls = 0
IsInAvAZone = function() return true end
DoesUnitExist, IsUnitPlayer, IsUnitAttackable = function() return true end, function() return true end, function() return true end
GetUnitDisplayName = function() return "@test" end
GetUnitId = function() return 1 end
GetUnitName = function() return "test" end
GetUnitClassId = function() metadataCalls = metadataCalls + 1; return 1 end
GetUnitPower = function() return 500, 1000 end
GetString = function(value) return tostring(value) end
addon.PvpTarget.SetEnabled(true)
check(events["EZOCombatPvpTarget:" .. EVENT_POWER_UPDATE] ~= nil, "enabled in-scope frame registers health events")
local beforeMetadata = metadataCalls
for _ = 1, 5 do addon.PvpTarget.Refresh() end
check(metadataCalls == beforeMetadata, "health refresh does not reread static identity every time")
addon.PvpTarget.SetEnabled(false)
check(not events["EZOCombatPvpTarget:" .. EVENT_POWER_UPDATE]
    and not updates.EZOCombatPvpTargetWorldPosition, "disabling live target stops listeners and projection")
IsInAvAZone = function() return false end
addon.PvpTarget.SetEnabled(true)
check(not events["EZOCombatPvpTarget:" .. EVENT_POWER_UPDATE], "PvP-only target inactive outside PvP")
addon.PvpTarget.SetScope("test")
check(events["EZOCombatPvpTarget:" .. EVENT_POWER_UPDATE] ~= nil, "explicit dummy scope reactivates target")
addon.PvpTarget.SetEnabled(false)

-- SCT restoration must retain recovery data if any native restore call throws.
for _, name in ipairs({ "GetSCTSlotPosition", "IsSCTSlotEventTypeShown", "DoesSCTSlotAllowTargetType",
    "SetSCTSlotAnimationMinimumSpacing", "GetSCTSlotAnimationMinimumSpacing", "GetSCTSlotKeyboardCloudId",
    "GetSCTSlotGamepadCloudId", "GetNumSCTCloudOffsets", "GetSCTCloudOffset", "ClearSCTCloudOffsets",
    "AddSCTCloudOffset", "GetSCTCloudAnimationOverlapPercent", "SetSCTCloudAnimationOverlapPercent" }) do
    _G[name] = noop
end
SCT_UNIT_ANCHOR_HEAD, SCT_UNIT_TYPE_OTHER_PLAYERS = 1, 2
GetNumSCTSlots = function() return 1 end
SetSCTSlotPosition = function() error("simulated native restore failure") end
addon.sv.pvpSct = { enabled = false, applied = true, mode = "standard", slotIndex = 1,
    original = { position = { anchorType = 1 } } }
dofile("modules/pvp_sct.lua")
check(not addon.PvpSct.Refresh(), "failed native SCT restore reported")
check(addon.sv.pvpSct.applied and addon.sv.pvpSct.original ~= nil, "failed restore retains original snapshot")
SetSCTSlotPosition = noop
check(addon.PvpSct.Refresh(), "later native restore can succeed")
check(not addon.sv.pvpSct.applied and addon.sv.pvpSct.original == nil, "successful restoration clears snapshot")
print(string.format("PASS: %d regression assertions (mock ESO API, not an ESO/FPS test)", tests))
