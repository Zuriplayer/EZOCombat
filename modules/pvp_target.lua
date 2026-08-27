EZOCombat = EZOCombat or {}
EZOCombat.PvpTarget = EZOCombat.PvpTarget or {}

local ADDON = EZOCombat
local PvpTarget = ADDON.PvpTarget
local WM = WINDOW_MANAGER
local UNIT_TAG = "reticleover"
local ALERT_DURATION_MS = 5000
local FRAME_WIDTH = 440
local FRAME_HEIGHT = 92
local CONTENT_LEFT = 12
local CONTENT_WIDTH = FRAME_WIDTH - (CONTENT_LEFT * 2)
local HEALTH_BAR_HEIGHT = 18
local CLASS_ICON_SIZE = 28
local DEFAULT_Y = 150
local WARNING_TEXTURE = "EsoUI/Art/Miscellaneous/ESO_Icon_Warning.dds"

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

local function DoesTargetExist()
    if type(DoesUnitExist) ~= "function" then
        return false
    end
    local ok, exists = pcall(DoesUnitExist, UNIT_TAG)
    return ok and exists == true
end

local function IsPlayerTarget()
    if type(IsUnitPlayer) ~= "function" then
        return false
    end
    local ok, isPlayer = pcall(IsUnitPlayer, UNIT_TAG)
    return ok and isPlayer == true
end

local function IsAttackableTarget()
    if type(IsUnitAttackable) ~= "function" then
        return false
    end
    local ok, attackable = pcall(IsUnitAttackable, UNIT_TAG)
    return ok and attackable == true
end

local function IsEligibleTarget()
    return IsPvpContext() and DoesTargetExist() and IsPlayerTarget() and IsAttackableTarget()
end

local function GetUnitText(functionName)
    local callback = _G[functionName]
    if type(callback) ~= "function" then
        return ""
    end
    local ok, value = pcall(callback, UNIT_TAG)
    if ok and type(value) == "string" then
        return value
    end
    return ""
end

local function GetUnitNumber(functionName)
    local callback = _G[functionName]
    if type(callback) ~= "function" then
        return nil
    end
    local ok, value = pcall(callback, UNIT_TAG)
    return ok and tonumber(value) or nil
end

local function GetUnitBoolean(functionName)
    local callback = _G[functionName]
    if type(callback) ~= "function" then
        return false
    end
    local ok, value = pcall(callback, UNIT_TAG)
    return ok and value == true
end

local function GetHealth()
    if type(GetUnitPower) ~= "function" then
        return nil, nil
    end
    local ok, current, maximum = pcall(GetUnitPower, UNIT_TAG, COMBAT_MECHANIC_FLAGS_HEALTH)
    if not ok then
        return nil, nil
    end
    current = tonumber(current)
    maximum = tonumber(maximum)
    if not current or not maximum or maximum <= 0 then
        return nil, nil
    end
    return math.max(0, current), maximum
end

local function GetClassIcon(classId)
    local callback = ZO_GetPlatformClassIcon or ZO_GetClassIcon
    if type(callback) ~= "function" or not classId then
        return ""
    end
    local ok, icon = pcall(callback, classId)
    return ok and type(icon) == "string" and icon or ""
end

local function GetAllianceIcon(alliance)
    if type(ZO_GetPlatformAllianceSymbolIcon) ~= "function" or not alliance then
        return ""
    end
    local ok, icon = pcall(ZO_GetPlatformAllianceSymbolIcon, alliance)
    return ok and type(icon) == "string" and icon or ""
end

local function GetAllianceTint(alliance)
    if type(_G.GetAllianceColor) ~= "function" or not alliance then
        return 1, 1, 1, 1
    end
    local ok, color = pcall(_G.GetAllianceColor, alliance)
    if ok and color and type(color.UnpackRGBA) == "function" then
        local unpackOk, r, g, b, a = pcall(color.UnpackRGBA, color)
        if unpackOk then
            return r, g, b, a
        end
    end
    return 1, 1, 1, 1
end

local function GetLevelText()
    local isChampion = GetUnitBoolean("IsUnitChampion")
    if isChampion then
        local championPoints = GetUnitNumber("GetUnitEffectiveChampionPoints")
            or GetUnitNumber("GetUnitChampionPoints")
        if championPoints and championPoints > 0 then
            return zo_strformat(GetString(SI_EZOCOMBAT_PVP_CP), championPoints)
        end
    end

    local level = GetUnitNumber("GetUnitEffectiveLevel") or GetUnitNumber("GetUnitLevel")
    if level and level > 0 then
        return zo_strformat(GetString(SI_EZOCOMBAT_PVP_LEVEL), level)
    end
    return ""
end

local function GetRankText()
    if type(GetUnitAvARank) ~= "function" then
        return ""
    end
    local ok, rank = pcall(function()
        local value = GetUnitAvARank(UNIT_TAG)
        return value
    end)
    rank = ok and tonumber(rank) or nil
    if not rank or rank <= 0 then
        return ""
    end
    return zo_strformat(GetString(SI_EZOCOMBAT_PVP_RANK), rank)
end

local function GetTargetIdentity()
    local name = GetUnitText("GetUnitName")
    local displayName = GetUnitText("GetUnitDisplayName")
    local classId = GetUnitNumber("GetUnitClassId") or 0
    return name .. "|" .. displayName .. "|" .. tostring(classId)
end

local function IsHudScene()
    return SCENE_MANAGER
        and type(SCENE_MANAGER.IsShowing) == "function"
        and (SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui"))
        and not (ADDON.Context
            and type(ADDON.Context.IsHudOverlayBlocked) == "function"
            and ADDON.Context.IsHudOverlayBlocked())
end

local function GetSettings()
    return ADDON.sv and ADDON.sv.pvpTarget or nil
end

local function IsEnabled()
    local settings = GetSettings()
    return settings and settings.enabled == true
end

local function IsLowHealthAlertEnabled()
    local settings = GetSettings()
    return settings and settings.lowHealthAlert == true
end

local function GetThreshold()
    local settings = GetSettings()
    local value = settings and tonumber(settings.healthThreshold) or 30
    return math.max(5, math.min(95, value))
end

local function GetMoveMode()
    return PvpTarget.moveMode == true
end

local function ApplyPosition()
    if not PvpTarget.frame or PvpTarget.moving then
        return
    end
    local settings = GetSettings()
    local x = settings and tonumber(settings.x) or nil
    local y = settings and tonumber(settings.y) or nil
    PvpTarget.frame:ClearAnchors()
    if x and y then
        PvpTarget.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    else
        PvpTarget.frame:SetAnchor(TOP, GuiRoot, TOP, 0, DEFAULT_Y)
    end
end

local function ResetAlert()
    PvpTarget.alertSerial = (PvpTarget.alertSerial or 0) + 1
    if PvpTarget.alert then
        PvpTarget.alert:SetHidden(true)
    end
end

local function ShowAlert()
    if not PvpTarget.alert or type(zo_callLater) ~= "function" then
        return
    end
    PvpTarget.alertSerial = (PvpTarget.alertSerial or 0) + 1
    local serial = PvpTarget.alertSerial
    PvpTarget.alert:SetHidden(false)
    zo_callLater(function()
        if serial == PvpTarget.alertSerial and PvpTarget.alert then
            PvpTarget.alert:SetHidden(true)
        end
    end, ALERT_DURATION_MS)
end

local function UpdateHealth(current, maximum, isDead)
    if not current or not maximum or maximum <= 0 then
        PvpTarget.healthFill:SetWidth(0)
        PvpTarget.health:SetText(GetString(SI_EZOCOMBAT_PVP_HEALTH_UNKNOWN))
        PvpTarget.wasBelowThreshold = false
        return
    end

    local percent = math.max(0, math.min(100, current / maximum * 100))
    PvpTarget.healthFill:SetWidth(CONTENT_WIDTH * percent / 100)
    PvpTarget.health:SetText(string.format(
        "%d / %d (%d%%)",
        math.floor(current + 0.5),
        math.floor(maximum + 0.5),
        math.floor(percent + 0.5)
    ))

    local belowThreshold = not isDead and percent <= GetThreshold()
    if not IsLowHealthAlertEnabled() then
        PvpTarget.wasBelowThreshold = belowThreshold
        ResetAlert()
        return
    end

    if belowThreshold and not PvpTarget.wasBelowThreshold then
        ShowAlert()
    end
    PvpTarget.wasBelowThreshold = belowThreshold
end

local function UpdateData()
    if not PvpTarget.frame then
        return
    end

    if not IsEligibleTarget() then
        PvpTarget.frame:SetHidden(true)
        PvpTarget.targetIdentity = nil
        PvpTarget.wasBelowThreshold = false
        ResetAlert()
        if not GetMoveMode() then
            return
        end
        if not IsPvpContext() then
            return
        end
        PvpTarget.frame:SetHidden(false)
        PvpTarget.name:SetText(GetString(SI_EZOCOMBAT_PVP_MOVE_PREVIEW))
        PvpTarget.health:SetText(GetString(SI_EZOCOMBAT_PVP_MOVE_PREVIEW_HEALTH))
        PvpTarget.healthFill:SetWidth(CONTENT_WIDTH)
        PvpTarget.classIcon:SetHidden(true)
        PvpTarget.allianceIcon:SetHidden(true)
        PvpTarget.meta:SetText(GetString(SI_EZOCOMBAT_PVP_MOVE_PREVIEW_META))
        PvpTarget.alert:SetHidden(true)
        return
    end

    local identity = GetTargetIdentity()
    if PvpTarget.targetIdentity ~= identity then
        PvpTarget.targetIdentity = identity
        PvpTarget.wasBelowThreshold = false
        ResetAlert()
    end

    local name = GetUnitText("GetUnitName")
    local displayName = GetUnitText("GetUnitDisplayName")
    if displayName ~= "" and displayName ~= name then
        name = name .. "  |cB0B0B0[" .. displayName .. "]|r"
    end
    PvpTarget.name:SetText(name ~= "" and name or GetString(SI_EZOCOMBAT_PVP_UNKNOWN_PLAYER))

    local current, maximum = GetHealth()
    local isDead = GetUnitBoolean("IsUnitDead")
    UpdateHealth(current, maximum, isDead)

    local classId = GetUnitNumber("GetUnitClassId")
    local className = GetUnitText("GetUnitClass")
    local classIcon = GetClassIcon(classId)
    PvpTarget.classIcon:SetTexture(classIcon)
    PvpTarget.classIcon:SetHidden(classIcon == "")

    local alliance = GetUnitNumber("GetUnitAlliance")
    local allianceIcon = GetAllianceIcon(alliance)
    PvpTarget.allianceIcon:SetTexture(allianceIcon)
    PvpTarget.allianceIcon:SetHidden(allianceIcon == "")
    local r, g, b, a = GetAllianceTint(alliance)
    PvpTarget.name:SetColor(r, g, b, a)
    PvpTarget.classIcon:SetColor(r, g, b, a)
    PvpTarget.allianceIcon:SetColor(r, g, b, a)

    local parts = {}
    if className ~= "" then
        parts[#parts + 1] = className
    end
    local allianceName = ""
    if type(GetAllianceName) == "function" and alliance then
        local ok, value = pcall(GetAllianceName, alliance)
        allianceName = ok and type(value) == "string" and value or ""
    end
    if allianceName ~= "" then
        parts[#parts + 1] = allianceName
    end
    local levelText = GetLevelText()
    if levelText ~= "" then
        parts[#parts + 1] = levelText
    end
    local rankText = GetRankText()
    if rankText ~= "" then
        parts[#parts + 1] = rankText
    end
    PvpTarget.meta:SetText(table.concat(parts, "  |  "))
    PvpTarget.frame:SetHidden(false)
end

local function CreateControl()
    PvpTarget.frame = WM:CreateControl("EZOCombatPvpTargetFrame", PvpTarget.root, CT_CONTROL)
    PvpTarget.frame:SetDimensions(FRAME_WIDTH, FRAME_HEIGHT)
    PvpTarget.frame:SetMovable(false)
    PvpTarget.frame:SetMouseEnabled(false)
    PvpTarget.frame:SetClampedToScreen(true)

    local background = WM:CreateControl(nil, PvpTarget.frame, CT_BACKDROP)
    background:SetAnchorFill(PvpTarget.frame)
    background:SetCenterColor(0.02, 0.02, 0.03, 0.90)
    background:SetEdgeColor(0.35, 0.35, 0.40, 0.95)
    background:SetEdgeTexture(nil, 1, 1, 1, 0)
    background:SetMouseEnabled(false)

    PvpTarget.name = WM:CreateControl(nil, PvpTarget.frame, CT_LABEL)
    PvpTarget.name:SetAnchor(TOPLEFT, PvpTarget.frame, TOPLEFT, CONTENT_LEFT, 7)
    PvpTarget.name:SetDimensions(CONTENT_WIDTH - 42, 22)
    PvpTarget.name:SetFont("ZoFontGameBold")
    PvpTarget.name:SetColor(1, 1, 1, 1)
    PvpTarget.name:SetMouseEnabled(false)

    PvpTarget.alert = WM:CreateControl(nil, PvpTarget.frame, CT_TEXTURE)
    PvpTarget.alert:SetDimensions(28, 28)
    PvpTarget.alert:SetAnchor(TOPRIGHT, PvpTarget.frame, TOPRIGHT, -10, 4)
    PvpTarget.alert:SetTexture(WARNING_TEXTURE)
    PvpTarget.alert:SetColor(1, 0.25, 0.12, 1)
    PvpTarget.alert:SetHidden(true)
    PvpTarget.alert:SetMouseEnabled(false)

    local healthBackground = WM:CreateControl(nil, PvpTarget.frame, CT_BACKDROP)
    healthBackground:SetAnchor(TOPLEFT, PvpTarget.frame, TOPLEFT, CONTENT_LEFT, 30)
    healthBackground:SetDimensions(CONTENT_WIDTH, HEALTH_BAR_HEIGHT)
    healthBackground:SetCenterColor(0.20, 0.03, 0.03, 1)
    healthBackground:SetEdgeColor(0.55, 0.20, 0.20, 1)
    healthBackground:SetEdgeTexture(nil, 1, 1, 1, 0)
    healthBackground:SetMouseEnabled(false)

    PvpTarget.healthFill = WM:CreateControl(nil, PvpTarget.frame, CT_BACKDROP)
    PvpTarget.healthFill:SetAnchor(TOPLEFT, healthBackground, TOPLEFT, 1, 1)
    PvpTarget.healthFill:SetDimensions(CONTENT_WIDTH - 2, HEALTH_BAR_HEIGHT - 2)
    PvpTarget.healthFill:SetCenterColor(0.70, 0.06, 0.06, 1)
    PvpTarget.healthFill:SetEdgeTexture(nil, 0, 0, 0, 0)
    PvpTarget.healthFill:SetMouseEnabled(false)

    PvpTarget.health = WM:CreateControl(nil, PvpTarget.frame, CT_LABEL)
    PvpTarget.health:SetAnchorFill(healthBackground)
    PvpTarget.health:SetFont("ZoFontGameSmall")
    PvpTarget.health:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    PvpTarget.health:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    PvpTarget.health:SetColor(1, 1, 1, 1)
    PvpTarget.health:SetMouseEnabled(false)

    PvpTarget.classIcon = WM:CreateControl(nil, PvpTarget.frame, CT_TEXTURE)
    PvpTarget.classIcon:SetDimensions(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
    PvpTarget.classIcon:SetAnchor(TOPLEFT, PvpTarget.frame, TOPLEFT, CONTENT_LEFT, 56)
    PvpTarget.classIcon:SetMouseEnabled(false)

    PvpTarget.allianceIcon = WM:CreateControl(nil, PvpTarget.frame, CT_TEXTURE)
    PvpTarget.allianceIcon:SetDimensions(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
    PvpTarget.allianceIcon:SetAnchor(TOPLEFT, PvpTarget.frame, TOPLEFT, CONTENT_LEFT + 36, 56)
    PvpTarget.allianceIcon:SetMouseEnabled(false)

    PvpTarget.meta = WM:CreateControl(nil, PvpTarget.frame, CT_LABEL)
    PvpTarget.meta:SetAnchor(TOPLEFT, PvpTarget.frame, TOPLEFT, CONTENT_LEFT + 74, 59)
    PvpTarget.meta:SetDimensions(CONTENT_WIDTH - 74, 24)
    PvpTarget.meta:SetFont("ZoFontGameSmall")
    PvpTarget.meta:SetColor(0.85, 0.85, 0.85, 1)
    PvpTarget.meta:SetMouseEnabled(false)

    PvpTarget.frame:SetHandler("OnMouseDown", function(_, button)
        if GetMoveMode() and button == MOUSE_BUTTON_INDEX_LEFT then
            PvpTarget.moving = true
            PvpTarget.frame:StartMoving()
        end
    end)
    PvpTarget.frame:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            PvpTarget.frame:StopMovingOrResizing()
            PvpTarget.moving = false
        end
    end)
    PvpTarget.frame:SetHandler("OnMoveStop", function()
        PvpTarget.moving = false
        local settings = GetSettings()
        if settings then
            settings.x = PvpTarget.frame:GetLeft()
            settings.y = PvpTarget.frame:GetTop()
        end
    end)

    ApplyPosition()
    PvpTarget.frame:SetHidden(true)
end

local function RegisterFragment()
    if PvpTarget.fragment or type(ZO_HUDFadeSceneFragment) ~= "table" then
        return
    end
    PvpTarget.fragment = ZO_HUDFadeSceneFragment:New(PvpTarget.root)
    HUD_SCENE:AddFragment(PvpTarget.fragment)
    HUD_UI_SCENE:AddFragment(PvpTarget.fragment)
end

function PvpTarget.Create()
    if PvpTarget.root then
        return
    end
    PvpTarget.root = WM:CreateTopLevelWindow("EZOCombatPvpTargetRoot")
    PvpTarget.root:SetAnchorFill(GuiRoot)
    PvpTarget.root:SetHidden(true)
    RegisterFragment()
    CreateControl()
end

function PvpTarget.SetEnabled(enabled)
    local settings = GetSettings()
    if not settings then
        return false
    end
    settings.enabled = enabled == true
    PvpTarget.Refresh()
    return settings.enabled == (enabled == true)
end

function PvpTarget.IsEnabled()
    return IsEnabled() == true
end

function PvpTarget.SetLowHealthAlertEnabled(enabled)
    local settings = GetSettings()
    if not settings then
        return false
    end
    settings.lowHealthAlert = enabled == true
    PvpTarget.Refresh()
    return settings.lowHealthAlert == (enabled == true)
end

function PvpTarget.IsLowHealthAlertEnabled()
    return IsLowHealthAlertEnabled() == true
end

function PvpTarget.SetHealthThreshold(value)
    local settings = GetSettings()
    if not settings then
        return false
    end
    value = tonumber(value) or 30
    settings.healthThreshold = math.max(5, math.min(95, math.floor(value + 0.5)))
    PvpTarget.Refresh()
    return true
end

function PvpTarget.GetHealthThreshold()
    return GetThreshold()
end

function PvpTarget.SetMoveMode(enabled)
    PvpTarget.moveMode = enabled == true
    if PvpTarget.frame then
        if not PvpTarget.moveMode and PvpTarget.moving then
            PvpTarget.frame:StopMovingOrResizing()
            PvpTarget.moving = false
        end
        PvpTarget.frame:SetMovable(PvpTarget.moveMode)
        PvpTarget.frame:SetMouseEnabled(PvpTarget.moveMode)
        ApplyPosition()
    end
    PvpTarget.Refresh()
    return PvpTarget.moveMode
end

function PvpTarget.IsMoveMode()
    return GetMoveMode()
end

function PvpTarget.Refresh()
    PvpTarget.Create()
    if not IsHudScene() or not IsEnabled() then
        PvpTarget.root:SetHidden(true)
        PvpTarget.frame:SetHidden(true)
        return
    end
    UpdateData()
    local frameVisible = not PvpTarget.frame:IsHidden()
    PvpTarget.root:SetHidden(not frameVisible)
end

function PvpTarget.DebugSnapshot()
    if not ADDON.IsDebugModeEnabled or not ADDON.IsDebugModeEnabled() then
        return false
    end
    local current, maximum = GetHealth()
    local percent = current and maximum and maximum > 0 and (current / maximum * 100) or nil
    ADDON.DebugLog(string.format(
        "pvp-target context=%s exists=%s player=%s attackable=%s name=%s health=%s/%s percent=%s threshold=%s alert=%s move=%s",
        tostring(IsPvpContext()),
        tostring(DoesTargetExist()),
        tostring(IsPlayerTarget()),
        tostring(IsAttackableTarget()),
        GetUnitText("GetUnitName"),
        tostring(current),
        tostring(maximum),
        tostring(percent and math.floor(percent + 0.5) or nil),
        tostring(GetThreshold()),
        tostring(IsLowHealthAlertEnabled()),
        tostring(GetMoveMode())
    ))
    return true
end

local function RegisterEvents()
    local namespace = ADDON.name .. "PvpTarget"
    local function OnTargetChanged()
        PvpTarget.targetIdentity = nil
        PvpTarget.wasBelowThreshold = false
        ResetAlert()
        PvpTarget.Refresh()
    end

    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_RETICLE_TARGET_CHANGED, OnTargetChanged)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_RETICLE_TARGET_PLAYER_CHANGED, OnTargetChanged)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_POWER_UPDATE, PvpTarget.Refresh)
    EVENT_MANAGER:AddFilterForEvent(
        namespace,
        EVENT_POWER_UPDATE,
        REGISTER_FILTER_POWER_TYPE,
        COMBAT_MECHANIC_FLAGS_HEALTH,
        REGISTER_FILTER_UNIT_TAG,
        UNIT_TAG
    )
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_UNIT_DEATH_STATE_CHANGED, PvpTarget.Refresh)
    EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG, UNIT_TAG)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_UNIT_CREATED, PvpTarget.Refresh)
    EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_UNIT_CREATED, REGISTER_FILTER_UNIT_TAG, UNIT_TAG)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_UNIT_DESTROYED, PvpTarget.Refresh)
    EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_UNIT_DESTROYED, REGISTER_FILTER_UNIT_TAG, UNIT_TAG)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_ZONE_CHANGED, PvpTarget.Refresh)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_ACTIVATED, PvpTarget.Refresh)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_TARGET_MARKER_UPDATE, PvpTarget.Refresh)
    if SCENE_MANAGER and type(SCENE_MANAGER.RegisterCallback) == "function" then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", PvpTarget.Refresh)
    end
end

function PvpTarget.Init()
    PvpTarget.Create()
    RegisterEvents()
    PvpTarget.Refresh()
end
