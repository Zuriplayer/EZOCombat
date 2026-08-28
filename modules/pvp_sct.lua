EZOCombat = EZOCombat or {}
EZOCombat.PvpSct = EZOCombat.PvpSct or {}

local ADDON = EZOCombat
local PvpSct = ADDON.PvpSct
local math = math
local type = type
local tostring = tostring

local DAMAGE_EVENT_TYPES = {
    SCT_EVENT_TYPE_DAMAGE,
    SCT_EVENT_TYPE_DAMAGE_CRIT,
    SCT_EVENT_TYPE_DOT_TICK,
    SCT_EVENT_TYPE_DOT_TICK_CRIT,
}

local DEFAULT_TIP_DISTANCE = 20
local DEFAULT_CONE_WIDTH = 70
local DEFAULT_ROW_SPACING = 18
local DEFAULT_MINIMUM_SPACING = 90
local SCOPE_PVP = "pvp"
local SCOPE_TEST = "test"

local function SafeCall(functionName, ...)
    local callback = _G[functionName]
    if type(callback) ~= "function" then
        return false
    end

    local ok, a, b, c, d, e, f = pcall(callback, ...)
    if not ok then
        return false
    end
    return true, a, b, c, d, e, f
end

local function IsPvpContext()
    local inAvA = false
    local inBattleground = false
    if type(IsInAvAZone) == "function" then
        local ok, value = pcall(IsInAvAZone)
        inAvA = ok and value == true
    end
    if type(IsActiveWorldBattleground) == "function" then
        local ok, value = pcall(IsActiveWorldBattleground)
        inBattleground = ok and value == true
    end
    return inAvA or inBattleground
end

local function GetSettings()
    return ADDON.sv and ADDON.sv.pvpSct or nil
end

local function Clamp(value, minimum, maximum, fallback)
    value = tonumber(value) or fallback
    return math.max(minimum, math.min(maximum, math.floor(value + 0.5)))
end

local function SafeCallAvailable(functionName)
    return type(_G[functionName]) == "function"
end

local function GetScope()
    local settings = GetSettings()
    return settings and settings.scope == SCOPE_TEST and SCOPE_TEST or SCOPE_PVP
end

local function IsActiveContext()
    return IsPvpContext() or GetScope() == SCOPE_TEST
end

local function GetTargetTypes()
    if GetScope() == SCOPE_TEST and _G.SCT_UNIT_TYPE_MONSTERS ~= nil then
        return { _G.SCT_UNIT_TYPE_MONSTERS }
    end

    local targetTypes = {}
    if _G.SCT_UNIT_TYPE_OTHER_PLAYERS ~= nil then
        targetTypes[#targetTypes + 1] = _G.SCT_UNIT_TYPE_OTHER_PLAYERS
    end
    return targetTypes
end

local function IsNativeSctAvailable()
    local requiredFunctions = {
        "GetNumSCTSlots",
        "SetSCTSlotPosition",
        "GetSCTSlotPosition",
        "IsSCTSlotEventTypeShown",
        "DoesSCTSlotAllowTargetType",
        "SetSCTSlotAnimationMinimumSpacing",
        "GetSCTSlotAnimationMinimumSpacing",
        "GetSCTSlotKeyboardCloudId",
        "GetSCTSlotGamepadCloudId",
        "GetNumSCTCloudOffsets",
        "GetSCTCloudOffset",
        "ClearSCTCloudOffsets",
        "AddSCTCloudOffset",
        "GetSCTCloudAnimationOverlapPercent",
        "SetSCTCloudAnimationOverlapPercent",
    }

    for _, functionName in ipairs(requiredFunctions) do
        if not SafeCallAvailable(functionName) then
            return false
        end
    end

    return _G.SCT_UNIT_ANCHOR_HEAD ~= nil
        and _G.SCT_UNIT_TYPE_OTHER_PLAYERS ~= nil
        and _G.CENTER ~= nil
end

local function IsValidSlot(slotIndex)
    local ok, count = SafeCall("GetNumSCTSlots")
    count = ok and tonumber(count) or 0
    slotIndex = tonumber(slotIndex)
    return slotIndex and slotIndex >= 1 and slotIndex <= count
end

local function IsValidCloud(cloudId)
    cloudId = tonumber(cloudId)
    return cloudId and cloudId > 0
end

local function CaptureCloud(cloudId)
    if not IsValidCloud(cloudId) then
        return nil
    end

    local ok, count = SafeCall("GetNumSCTCloudOffsets", cloudId)
    if not ok then
        return nil
    end

    local snapshot = {
        cloudId = cloudId,
        offsets = {},
    }
    count = tonumber(count) or 0
    for index = 1, count do
        local offsetOk, ordering, offsetX, offsetY = SafeCall(
            "GetSCTCloudOffset",
            cloudId,
            index
        )
        if offsetOk then
            snapshot.offsets[#snapshot.offsets + 1] = {
                ordering = ordering,
                x = offsetX,
                y = offsetY,
            }
        end
    end

    local overlapOk, overlap = SafeCall("GetSCTCloudAnimationOverlapPercent", cloudId)
    snapshot.overlap = overlapOk and overlap or nil
    return snapshot
end

local function CaptureSlot(slotIndex)
    local ok, anchorType, anchorPoint, offsetX, offsetY, cameraRight, cameraUp = SafeCall(
        "GetSCTSlotPosition",
        slotIndex
    )
    if not ok then
        return nil
    end

    local spacingOk, minimumSpacing = SafeCall(
        "GetSCTSlotAnimationMinimumSpacing",
        slotIndex
    )
    local keyboardCloudOk, keyboardCloudId = SafeCall(
        "GetSCTSlotKeyboardCloudId",
        slotIndex
    )
    local gamepadCloudOk, gamepadCloudId = SafeCall(
        "GetSCTSlotGamepadCloudId",
        slotIndex
    )

    return {
        position = {
            anchorType = anchorType,
            anchorPoint = anchorPoint,
            offsetX = offsetX,
            offsetY = offsetY,
            cameraRight = cameraRight,
            cameraUp = cameraUp,
        },
        minimumSpacing = spacingOk and minimumSpacing or nil,
        keyboardCloudId = keyboardCloudOk and keyboardCloudId or nil,
        gamepadCloudId = gamepadCloudOk and gamepadCloudId or nil,
        keyboardCloud = CaptureCloud(keyboardCloudOk and keyboardCloudId or nil),
        gamepadCloud = CaptureCloud(gamepadCloudOk and gamepadCloudId or nil),
    }
end

local function RestoreCloud(snapshot)
    if not snapshot or not IsValidCloud(snapshot.cloudId) then
        return
    end

    SafeCall("ClearSCTCloudOffsets", snapshot.cloudId)
    for _, offset in ipairs(snapshot.offsets or {}) do
        SafeCall(
            "AddSCTCloudOffset",
            snapshot.cloudId,
            offset.ordering,
            offset.x,
            offset.y
        )
    end
    if snapshot.overlap ~= nil then
        SafeCall("SetSCTCloudAnimationOverlapPercent", snapshot.cloudId, snapshot.overlap)
    end
end

local function RestoreSlot(slotIndex, snapshot)
    if not snapshot or not IsValidSlot(slotIndex) then
        return false
    end

    local position = snapshot.position
    if position then
        SafeCall(
            "SetSCTSlotPosition",
            slotIndex,
            position.anchorType,
            position.anchorPoint,
            position.offsetX,
            position.offsetY,
            position.cameraRight,
            position.cameraUp
        )
    end
    if snapshot.minimumSpacing ~= nil then
        SafeCall("SetSCTSlotAnimationMinimumSpacing", slotIndex, snapshot.minimumSpacing)
    end
    RestoreCloud(snapshot.keyboardCloud)
    if not snapshot.gamepadCloud
        or not snapshot.keyboardCloud
        or snapshot.gamepadCloud.cloudId ~= snapshot.keyboardCloud.cloudId then
        RestoreCloud(snapshot.gamepadCloud)
    end
    return true
end

local function IsDamageSlot(slotIndex, targetTypes)
    local shown = false
    for _, eventType in ipairs(DAMAGE_EVENT_TYPES) do
        if eventType ~= nil then
            local ok, isShown = SafeCall(
                "IsSCTSlotEventTypeShown",
                slotIndex,
                eventType
            )
            if ok and isShown == true then
                shown = true
                break
            end
        end
    end
    if not shown then
        return false
    end

    for _, targetType in ipairs(targetTypes or {}) do
        local ok, allowed = SafeCall(
            "DoesSCTSlotAllowTargetType",
            slotIndex,
            targetType
        )
        if ok and allowed == true then
            return true
        end
    end
    return false
end

local function FindStandardDamageSlot(targetTypes)
    local ok, count = SafeCall("GetNumSCTSlots")
    if not ok then
        return nil
    end

    count = tonumber(count) or 0
    for slotIndex = 1, count do
        if IsDamageSlot(slotIndex, targetTypes) then
            return slotIndex
        end
    end
    return nil
end

local function SetOwnedSlotVisible(slotIndex, visible)
    if not IsValidSlot(slotIndex) then
        return
    end
    for _, eventType in ipairs(DAMAGE_EVENT_TYPES) do
        if eventType ~= nil then
            SafeCall("SetSCTSlotEventTypeShown", slotIndex, eventType, visible == true)
        end
    end
end

local function ConfigureOwnedSlot(slotIndex, targetTypes)
    SafeCall("ClearSCTSlotAllowedTargetTypes", slotIndex)
    for _, targetType in ipairs(targetTypes or {}) do
        SafeCall("AddSCTSlotAllowedTargetType", slotIndex, targetType)
    end
    SafeCall("ClearSCTSlotAllowedSourceTypes", slotIndex)
    if _G.SCT_UNIT_TYPE_LOCAL_PLAYER ~= nil then
        SafeCall("AddSCTSlotAllowedSourceType", slotIndex, _G.SCT_UNIT_TYPE_LOCAL_PLAYER)
    end
    if SafeCallAvailable("SetSCTSlotTargetReputationTypes") then
        SafeCall("SetSCTSlotTargetReputationTypes", slotIndex, false, false, true)
    end
end

local function CreateOwnedSlot(settings, targetTypes)
    local ok, slotIndex = SafeCall("CreateNewSCTSlot")
    if not ok or not IsValidSlot(slotIndex) then
        return nil
    end

    ConfigureOwnedSlot(slotIndex, targetTypes)

    local keyboardOk, keyboardCloudId = SafeCall("CreateNewSCTCloud")
    local gamepadOk, gamepadCloudId = SafeCall("CreateNewSCTCloud")
    if keyboardOk and IsValidCloud(keyboardCloudId) then
        SafeCall("SetSCTSlotKeyboardCloud", slotIndex, keyboardCloudId)
    end
    if gamepadOk and IsValidCloud(gamepadCloudId) then
        SafeCall("SetSCTSlotGamepadCloud", slotIndex, gamepadCloudId)
    end

    settings.slotIndex = slotIndex
    settings.mode = "owned"
    SetOwnedSlotVisible(slotIndex, false)
    return slotIndex
end

local function GetOrPrepareSlot(settings, targetTypes)
    if IsValidSlot(settings.slotIndex) and settings.mode == "owned" then
        ConfigureOwnedSlot(settings.slotIndex, targetTypes)
        return tonumber(settings.slotIndex)
    end

    local standardSlot = FindStandardDamageSlot(targetTypes)
    if standardSlot then
        local snapshot = CaptureSlot(standardSlot)
        if snapshot then
            settings.slotIndex = standardSlot
            settings.mode = "standard"
            settings.original = snapshot
            return standardSlot
        end
    end

    return CreateOwnedSlot(settings, targetTypes)
end

local function BuildConeCloud(cloudId, coneWidth, rowSpacing)
    if not IsValidCloud(cloudId) then
        return
    end

    local halfWidth = coneWidth / 2
    local rows = {
        { 0, 0 },
        { -halfWidth * 0.35, -rowSpacing },
        { halfWidth * 0.35, -rowSpacing },
        { -halfWidth * 0.70, -rowSpacing * 2 },
        { halfWidth * 0.70, -rowSpacing * 2 },
        { -halfWidth, -rowSpacing * 3 },
        { halfWidth, -rowSpacing * 3 },
    }

    SafeCall("ClearSCTCloudOffsets", cloudId)
    for ordering, offset in ipairs(rows) do
        SafeCall("AddSCTCloudOffset", cloudId, ordering, offset[1], offset[2])
    end
    SafeCall("SetSCTCloudAnimationOverlapPercent", cloudId, 0)
end

local function ApplySlot(slotIndex, settings)
    local tipDistance = Clamp(settings.tipDistance, 0, 120, DEFAULT_TIP_DISTANCE)
    local coneWidth = Clamp(settings.coneWidth, 0, 240, DEFAULT_CONE_WIDTH)
    local rowSpacing = Clamp(settings.rowSpacing, 8, 50, DEFAULT_ROW_SPACING)
    local minimumSpacing = Clamp(
        settings.minimumSpacing,
        0,
        500,
        DEFAULT_MINIMUM_SPACING
    )

    settings.tipDistance = tipDistance
    settings.coneWidth = coneWidth
    settings.rowSpacing = rowSpacing
    settings.minimumSpacing = minimumSpacing

    local ok = SafeCall(
        "SetSCTSlotPosition",
        slotIndex,
        _G.SCT_UNIT_ANCHOR_HEAD,
        _G.CENTER,
        0,
        -tipDistance,
        0,
        0
    )
    SafeCall("SetSCTSlotAnimationMinimumSpacing", slotIndex, minimumSpacing)

    local keyboardOk, keyboardCloudId = SafeCall("GetSCTSlotKeyboardCloudId", slotIndex)
    local gamepadOk, gamepadCloudId = SafeCall("GetSCTSlotGamepadCloudId", slotIndex)
    if keyboardOk then
        BuildConeCloud(keyboardCloudId, coneWidth, rowSpacing)
    end
    if gamepadOk and (not keyboardOk or gamepadCloudId ~= keyboardCloudId) then
        BuildConeCloud(gamepadCloudId, coneWidth, rowSpacing)
    end

    if settings.mode == "owned" then
        SetOwnedSlotVisible(slotIndex, true)
    end
    return ok
end

local function RestoreActiveSettings(settings)
    local slotIndex = tonumber(settings.slotIndex)
    if settings.mode == "standard" and settings.original then
        RestoreSlot(slotIndex, settings.original)
    elseif settings.mode == "owned" then
        SetOwnedSlotVisible(slotIndex, false)
    end

    settings.applied = false
    settings.original = nil
    settings.appliedScope = nil
    if settings.mode ~= "owned" then
        settings.mode = nil
        settings.slotIndex = nil
    end
end

local function RecoverInterruptedApply(settings)
    if settings.applied ~= true then
        return true
    end
    if settings.mode == "standard" and settings.original then
        if not RestoreSlot(settings.slotIndex, settings.original) then
            return false
        end
    elseif settings.mode == "owned" then
        SetOwnedSlotVisible(settings.slotIndex, false)
    end

    settings.applied = false
    settings.original = nil
    settings.appliedScope = nil
    if settings.mode ~= "owned" then
        settings.mode = nil
        settings.slotIndex = nil
    end
    return true
end

local function IsEnabled()
    local settings = GetSettings()
    return settings and settings.enabled == true
end

function PvpSct.IsEnabled()
    return IsEnabled() == true
end

function PvpSct.SetEnabled(enabled)
    local settings = GetSettings()
    if not settings then
        return false
    end
    settings.enabled = enabled == true
    PvpSct.Refresh()
    return settings.enabled == (enabled == true)
end

function PvpSct.SetScope(scope)
    local settings = GetSettings()
    if not settings then
        return false
    end
    local nextScope = scope == SCOPE_TEST and SCOPE_TEST or SCOPE_PVP
    if settings.scope ~= nextScope and settings.applied == true then
        RestoreActiveSettings(settings)
    end
    settings.scope = nextScope
    PvpSct.Refresh()
    return true
end

function PvpSct.GetScope()
    return GetScope()
end

function PvpSct.SetTipDistance(value)
    local settings = GetSettings()
    if not settings then
        return false
    end
    settings.tipDistance = Clamp(value, 0, 120, DEFAULT_TIP_DISTANCE)
    PvpSct.Refresh()
    return true
end

function PvpSct.GetTipDistance()
    local settings = GetSettings()
    return Clamp(settings and settings.tipDistance, 0, 120, DEFAULT_TIP_DISTANCE)
end

function PvpSct.SetConeWidth(value)
    local settings = GetSettings()
    if not settings then
        return false
    end
    settings.coneWidth = Clamp(value, 0, 240, DEFAULT_CONE_WIDTH)
    PvpSct.Refresh()
    return true
end

function PvpSct.GetConeWidth()
    local settings = GetSettings()
    return Clamp(settings and settings.coneWidth, 0, 240, DEFAULT_CONE_WIDTH)
end

function PvpSct.SetRowSpacing(value)
    local settings = GetSettings()
    if not settings then
        return false
    end
    settings.rowSpacing = Clamp(value, 8, 50, DEFAULT_ROW_SPACING)
    PvpSct.Refresh()
    return true
end

function PvpSct.GetRowSpacing()
    local settings = GetSettings()
    return Clamp(settings and settings.rowSpacing, 8, 50, DEFAULT_ROW_SPACING)
end

function PvpSct.SetMinimumSpacing(value)
    local settings = GetSettings()
    if not settings then
        return false
    end
    settings.minimumSpacing = Clamp(value, 0, 500, DEFAULT_MINIMUM_SPACING)
    PvpSct.Refresh()
    return true
end

function PvpSct.GetMinimumSpacing()
    local settings = GetSettings()
    return Clamp(settings and settings.minimumSpacing, 0, 500, DEFAULT_MINIMUM_SPACING)
end

function PvpSct.Refresh()
    local settings = GetSettings()
    if not settings or not IsNativeSctAvailable() then
        return false
    end

    if not PvpSct.recovered then
        if not RecoverInterruptedApply(settings) then
            return false
        end
        PvpSct.recovered = true
    end

    if settings.applied == true and settings.appliedScope ~= GetScope() then
        RestoreActiveSettings(settings)
    end

    if not IsEnabled() or not IsActiveContext() then
        if settings.applied == true then
            RestoreActiveSettings(settings)
        elseif settings.mode == "owned" and IsValidSlot(settings.slotIndex) then
            SetOwnedSlotVisible(settings.slotIndex, false)
        end
        return true
    end

    local slotIndex = tonumber(settings.slotIndex)
    if settings.applied ~= true then
        local targetTypes = GetTargetTypes()
        slotIndex = GetOrPrepareSlot(settings, targetTypes)
        if not slotIndex then
            if ADDON.DebugLog then
                ADDON.DebugLog("pvp-sct no compatible SCT damage slot")
            end
            return false
        end
        settings.applied = true
        settings.appliedScope = GetScope()
    end

    if not IsValidSlot(slotIndex) then
        settings.applied = false
        settings.original = nil
        settings.mode = nil
        settings.slotIndex = nil
        settings.appliedScope = nil
        return false
    end

    return ApplySlot(slotIndex, settings)
end

function PvpSct.DebugSnapshot()
    if not ADDON.IsDebugModeEnabled or not ADDON.IsDebugModeEnabled() then
        return false
    end
    local settings = GetSettings()
    ADDON.DebugLog(string.format(
        "pvp-sct enabled=%s scope=%s pvp=%s activeContext=%s applied=%s appliedScope=%s mode=%s slot=%s tip=%s width=%s spacing=%s minSpacing=%s native=%s",
        tostring(IsEnabled()),
        tostring(GetScope()),
        tostring(IsPvpContext()),
        tostring(IsActiveContext()),
        tostring(settings and settings.applied == true),
        tostring(settings and settings.appliedScope),
        tostring(settings and settings.mode),
        tostring(settings and settings.slotIndex),
        tostring(PvpSct.GetTipDistance()),
        tostring(PvpSct.GetConeWidth()),
        tostring(PvpSct.GetRowSpacing()),
        tostring(PvpSct.GetMinimumSpacing()),
        tostring(IsNativeSctAvailable())
    ))
    return true
end

function PvpSct.Init()
    if PvpSct.initialized then
        return
    end
    PvpSct.initialized = true

    local namespace = ADDON.name .. "PvpSct"
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_ZONE_CHANGED, PvpSct.Refresh)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_ACTIVATED, PvpSct.Refresh)
    if type(zo_callLater) == "function" then
        zo_callLater(PvpSct.Refresh, 100)
    end
    PvpSct.Refresh()
end
