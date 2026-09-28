EZOCombat = EZOCombat or {}
EZOCombat.PvpTarget = EZOCombat.PvpTarget or {}

local ADDON = EZOCombat
local PvpTarget = ADDON.PvpTarget
local WM = WINDOW_MANAGER
local math = math
local UNIT_TAG = "reticleover"
local ALERT_DURATION_MS = 5000
local FRAME_WIDTH = 260
local FRAME_HEIGHT = 62
local CONTENT_WIDTH = FRAME_WIDTH
local HEALTH_BAR_HEIGHT = 8
local CLASS_ICON_SIZE = 20
local WARNING_TEXTURE = "EsoUI/Art/Miscellaneous/ESO_Icon_Warning.dds"
local HEALTH_TEXTURE = "EsoUI/Art/Miscellaneous/listItem_backdrop_white.dds"
local SCOPE_PVP = "pvp"
local SCOPE_TEST = "test"
local REFRESH_INTERVAL_MS = 100
local REFRESH_UPDATE_NAME = ADDON.name .. "PvpTargetRefreshThrottle"
local WORLD_UPDATE_INTERVAL_MS = 100
local WORLD_UPDATE_NAME = ADDON.name .. "PvpTargetWorldPosition"
local SyncTargetEvents

local function SetHiddenIfChanged(control, hidden)
    hidden = hidden == true
    if control and control:IsHidden() ~= hidden then
        control:SetHidden(hidden)
    end
end

local function SetTextIfChanged(label, text)
    text = text or ""
    if label and label.ezoCombatText ~= text then
        label.ezoCombatText = text
        label:SetText(text)
    end
end

local function SetTextureIfChanged(texture, path)
    path = path or ""
    if texture and texture.ezoCombatTexture ~= path then
        texture.ezoCombatTexture = path
        texture:SetTexture(path)
    end
end

local function SetColorIfChanged(control, r, g, b, a)
    if not control then
        return
    end
    a = a or 1
    if control.ezoCombatColorR ~= r
        or control.ezoCombatColorG ~= g
        or control.ezoCombatColorB ~= b
        or control.ezoCombatColorA ~= a then
        control.ezoCombatColorR = r
        control.ezoCombatColorG = g
        control.ezoCombatColorB = b
        control.ezoCombatColorA = a
        control:SetColor(r, g, b, a)
    end
end

local function SetWidthIfChanged(control, width)
    width = math.max(1, tonumber(width) or 1)
    if control and control.ezoCombatWidth ~= width then
        control.ezoCombatWidth = width
        control:SetWidth(width)
    end
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
    if IsPvpContext() and DoesTargetExist() and IsPlayerTarget() and IsAttackableTarget() then
        return true
    end

    local settings = ADDON.sv and ADDON.sv.pvpTarget or nil
    if not settings or settings.scope ~= SCOPE_TEST then
        return false
    end

    return DoesTargetExist() and IsAttackableTarget()
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

local function GetChampionPoints()
    local isChampion = GetUnitBoolean("IsUnitChampion")
    if isChampion then
        local championPoints = GetUnitNumber("GetUnitEffectiveChampionPoints")
            or GetUnitNumber("GetUnitChampionPoints")
        if championPoints and championPoints > 0 then
            return championPoints
        end
    end
    return nil
end

local function GetRankIcon(rank)
    if type(GetAvARankIcon) ~= "function" or not rank or rank < 0 then
        return ""
    end
    local ok, icon = pcall(GetAvARankIcon, rank)
    return ok and type(icon) == "string" and icon or ""
end

local function GetTargetIdentity()
    if type(GetUnitId) == "function" then
        local ok, unitId = pcall(GetUnitId, UNIT_TAG)
        unitId = ok and tonumber(unitId) or 0
        if unitId and unitId > 0 then
            return "unit:" .. tostring(unitId)
        end
    end
    local displayName = GetUnitText("GetUnitDisplayName")
    local classId = GetUnitNumber("GetUnitClassId") or 0
    return displayName .. "|" .. tostring(classId)
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

local function GetScope()
    local settings = GetSettings()
    return settings and settings.scope == SCOPE_TEST and SCOPE_TEST or SCOPE_PVP
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

local function GetHeadOffsetM()
    local settings = GetSettings()
    local value = settings and tonumber(settings.headOffset) or 2.8
    return math.max(1.5, math.min(4.5, value))
end

local function GetHoldDurationMs()
    local settings = GetSettings()
    local seconds = settings and tonumber(settings.holdDuration) or 1.5
    seconds = math.max(0, math.min(5, seconds))
    return math.floor(seconds * 1000 + 0.5)
end

local function GetNowMilliseconds()
    if type(GetFrameTimeMilliseconds) == "function" then
        return GetFrameTimeMilliseconds()
    end
    if type(GetGameTimeMilliseconds) == "function" then
        return GetGameTimeMilliseconds()
    end
    return 0
end

local function QueueRefresh()
    if not IsEnabled() or not IsHudScene() then
        return
    end
    local now = GetNowMilliseconds()
    local last = tonumber(PvpTarget.lastRefreshMs) or 0
    if last == 0 or now <= 0 or now - last >= REFRESH_INTERVAL_MS then
        if PvpTarget.refreshRegistered and EVENT_MANAGER then
            EVENT_MANAGER:UnregisterForUpdate(REFRESH_UPDATE_NAME)
            PvpTarget.refreshRegistered = false
        end
        PvpTarget.Refresh()
        return
    end

    if PvpTarget.refreshRegistered or not (EVENT_MANAGER and EVENT_MANAGER.RegisterForUpdate) then
        PvpTarget.refreshPending = true
        return
    end

    PvpTarget.refreshPending = true
    PvpTarget.refreshRegistered = true
    EVENT_MANAGER:RegisterForUpdate(REFRESH_UPDATE_NAME, 25, function()
        local current = GetNowMilliseconds()
        if current > 0
            and current - (tonumber(PvpTarget.lastRefreshMs) or 0) < REFRESH_INTERVAL_MS then
            return
        end
        EVENT_MANAGER:UnregisterForUpdate(REFRESH_UPDATE_NAME)
        PvpTarget.refreshRegistered = false
        PvpTarget.refreshPending = false
        PvpTarget.Refresh()
    end)
end

local function StopWorldUpdate()
    if PvpTarget.worldUpdateRegistered and EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForUpdate(WORLD_UPDATE_NAME)
    end
    PvpTarget.worldUpdateRegistered = false
end

local function GetWorldCamera()
    if not PvpTarget.renderControl
        or type(Set3DRenderSpaceToCurrentCamera) ~= "function"
        or type(GuiRender3DPositionToWorldPosition) ~= "function"
        or type(GetWorldDimensionsOfViewFrustumAtDepth) ~= "function" then
        return nil
    end

    local ok, camera = pcall(function()
        Set3DRenderSpaceToCurrentCamera(PvpTarget.renderControl:GetName())
        local cameraX, cameraY, cameraZ = GuiRender3DPositionToWorldPosition(
            PvpTarget.renderControl:Get3DRenderSpaceOrigin()
        )
        local forwardX, forwardY, forwardZ = PvpTarget.renderControl:Get3DRenderSpaceForward()
        local rightX, rightY, rightZ = PvpTarget.renderControl:Get3DRenderSpaceRight()
        local upX, upY, upZ = PvpTarget.renderControl:Get3DRenderSpaceUp()
        local uiW, uiH = GuiRoot:GetDimensions()
        local cameraData = PvpTarget.camera or {}

        cameraData.x = cameraX
        cameraData.y = cameraY
        cameraData.z = cameraZ
        cameraData.uiW = uiW
        cameraData.uiH = uiH
        cameraData.i11 = -(upY * forwardZ - upZ * forwardY)
        cameraData.i12 = -(rightZ * forwardY - rightY * forwardZ)
        cameraData.i13 = -(rightY * upZ - rightZ * upY)
        cameraData.i21 = -(upZ * forwardX - upX * forwardZ)
        cameraData.i22 = -(rightX * forwardZ - rightZ * forwardX)
        cameraData.i23 = -(rightZ * upX - rightX * upZ)
        cameraData.i31 = -(upX * forwardY - upY * forwardX)
        cameraData.i32 = -(rightY * forwardX - rightX * forwardY)
        cameraData.i33 = -(rightX * upY - rightY * upX)
        cameraData.i41 = -(upZ * forwardY * cameraX + upY * forwardX * cameraZ + upX * forwardZ * cameraY - upX * forwardY * cameraZ - upY * forwardZ * cameraX - upZ * forwardX * cameraY)
        cameraData.i42 = -(rightX * forwardY * cameraZ + rightY * forwardZ * cameraX + rightZ * forwardX * cameraY - rightZ * forwardY * cameraX - rightY * forwardX * cameraZ - rightX * forwardZ * cameraY)
        cameraData.i43 = -(rightZ * upY * cameraX + rightY * upX * cameraZ + rightX * upZ * cameraY - rightX * upY * cameraZ - rightY * upZ * cameraX - rightZ * upX * cameraY)
        PvpTarget.camera = cameraData
        return cameraData
    end)
    return ok and camera or nil
end

local function ProjectTargetPosition()
    if type(GetUnitRawWorldPosition) ~= "function" then
        return nil, nil
    end

    local ok, _, worldX, worldY, worldZ = pcall(GetUnitRawWorldPosition, UNIT_TAG)
    worldX = ok and tonumber(worldX) or nil
    worldY = ok and tonumber(worldY) or nil
    worldZ = ok and tonumber(worldZ) or nil
    if not worldX or not worldY or not worldZ then
        return nil, nil
    end

    local camera = GetWorldCamera()
    if not camera then
        return nil, nil
    end

    worldY = worldY + GetHeadOffsetM() * 100
    local screenX = worldX * camera.i11 + worldY * camera.i21 + worldZ * camera.i31 + camera.i41
    local screenY = worldX * camera.i12 + worldY * camera.i22 + worldZ * camera.i32 + camera.i42
    local screenZ = worldX * camera.i13 + worldY * camera.i23 + worldZ * camera.i33 + camera.i43
    if screenZ <= 0 then
        return nil, nil
    end

    local viewW, viewH = GetWorldDimensionsOfViewFrustumAtDepth(screenZ)
    if not viewW or not viewH or viewW == 0 or viewH == 0 then
        return nil, nil
    end
    return screenX * camera.uiW / viewW, -screenY * camera.uiH / viewH
end

local function AnchorToTarget(x, y)
    if not PvpTarget.frame then
        return
    end
    if PvpTarget.worldAnchorX
        and math.abs(PvpTarget.worldAnchorX - x) <= 0.5
        and math.abs(PvpTarget.worldAnchorY - y) <= 0.5 then
        return
    end
    PvpTarget.frame:ClearAnchors()
    PvpTarget.frame:SetAnchor(BOTTOM, PvpTarget.root, CENTER, x, y)
    PvpTarget.worldAnchorX = x
    PvpTarget.worldAnchorY = y
end

local ResetAlert

local function EnsureWorldUpdate()
    if PvpTarget.worldUpdateRegistered
        or not (EVENT_MANAGER and type(EVENT_MANAGER.RegisterForUpdate) == "function") then
        return
    end
    PvpTarget.worldUpdateRegistered = true
    EVENT_MANAGER:RegisterForUpdate(WORLD_UPDATE_NAME, WORLD_UPDATE_INTERVAL_MS, function()
        if not IsHudScene() or not IsEnabled() then
            SetHiddenIfChanged(PvpTarget.root, true)
            SetHiddenIfChanged(PvpTarget.frame, true)
            StopWorldUpdate()
            return
        end

        if IsEligibleTarget() then
            local x, y = ProjectTargetPosition()
            if x and y then
                AnchorToTarget(x, y)
                SetHiddenIfChanged(PvpTarget.frame, false)
                SetHiddenIfChanged(PvpTarget.root, false)
            else
                SetHiddenIfChanged(PvpTarget.frame, true)
                SetHiddenIfChanged(PvpTarget.root, true)
            end
            return
        end

        local now = GetNowMilliseconds()
        if PvpTarget.holdUntilMs and (now <= 0 or now < PvpTarget.holdUntilMs) then
            SetHiddenIfChanged(PvpTarget.frame, false)
            SetHiddenIfChanged(PvpTarget.root, false)
            return
        end

        PvpTarget.holdUntilMs = nil
        PvpTarget.targetIdentity = nil
        PvpTarget.worldAnchorX = nil
        PvpTarget.worldAnchorY = nil
        SetHiddenIfChanged(PvpTarget.frame, true)
        SetHiddenIfChanged(PvpTarget.root, true)
        ResetAlert()
        StopWorldUpdate()
    end)
end

ResetAlert = function()
    PvpTarget.alertSerial = (PvpTarget.alertSerial or 0) + 1
    if PvpTarget.alert then
        SetHiddenIfChanged(PvpTarget.alert, true)
    end
end

local function ShowAlert()
    if not PvpTarget.alert or type(zo_callLater) ~= "function" then
        return
    end
    PvpTarget.alertSerial = (PvpTarget.alertSerial or 0) + 1
    local serial = PvpTarget.alertSerial
    SetHiddenIfChanged(PvpTarget.alert, false)
    zo_callLater(function()
        if serial == PvpTarget.alertSerial and PvpTarget.alert then
            SetHiddenIfChanged(PvpTarget.alert, true)
        end
    end, ALERT_DURATION_MS)
end

local function UpdateHealth(current, maximum, isDead)
    if not current or not maximum or maximum <= 0 then
        SetWidthIfChanged(PvpTarget.healthFill, 0)
        SetHiddenIfChanged(PvpTarget.healthFill, true)
        SetTextIfChanged(PvpTarget.health, GetString(SI_EZOCOMBAT_PVP_HEALTH_UNKNOWN))
        PvpTarget.wasBelowThreshold = false
        return
    end

    local percent = math.max(0, math.min(100, current / maximum * 100))
    SetWidthIfChanged(PvpTarget.healthFill, CONTENT_WIDTH * percent / 100)
    SetHiddenIfChanged(PvpTarget.healthFill, percent <= 0)
    SetTextIfChanged(PvpTarget.health, string.format(
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
        local holdDurationMs = GetHoldDurationMs()
        local now = GetNowMilliseconds()
        if PvpTarget.targetIdentity and holdDurationMs > 0 then
            if not PvpTarget.holdUntilMs then
                PvpTarget.holdUntilMs = now > 0 and now + holdDurationMs or 1
            end
            if now <= 0 or now < PvpTarget.holdUntilMs then
                SetHiddenIfChanged(PvpTarget.frame, false)
                EnsureWorldUpdate()
                return
            end
        end
        PvpTarget.holdUntilMs = nil
        PvpTarget.targetIdentity = nil
        PvpTarget.worldAnchorX = nil
        PvpTarget.worldAnchorY = nil
        PvpTarget.wasBelowThreshold = false
        ResetAlert()
        SetHiddenIfChanged(PvpTarget.frame, true)
        StopWorldUpdate()
        return
    end

    PvpTarget.holdUntilMs = nil
    local identity = GetTargetIdentity()
    if PvpTarget.targetIdentity ~= identity then
        PvpTarget.targetIdentity = identity
        PvpTarget.wasBelowThreshold = false
        ResetAlert()
        PvpTarget.metadataRefreshAt = nil
    end

    local current, maximum = GetHealth()
    local isDead = GetUnitBoolean("IsUnitDead")
    UpdateHealth(current, maximum, isDead)

    -- Identity data rarely changes. Retry once a second for metadata which
    -- ESO may expose after the initial reticle event; health stays at 100 ms.
    local now = GetNowMilliseconds()
    if not PvpTarget.metadataRefreshAt or now >= PvpTarget.metadataRefreshAt then
        PvpTarget.metadataRefreshAt = now + 1000
        local displayName = GetUnitText("GetUnitDisplayName")
        if displayName == "" and GetScope() == SCOPE_TEST then
            displayName = GetUnitText("GetUnitName")
        end
        SetTextIfChanged(PvpTarget.name, displayName ~= "" and displayName or GetString(SI_EZOCOMBAT_PVP_UNKNOWN_PLAYER))
        SetColorIfChanged(PvpTarget.name, 1, 1, 1, 1)

        local classId = GetUnitNumber("GetUnitClassId")
        local classIcon = classId and classId > 0 and GetClassIcon(classId) or ""
        SetTextureIfChanged(PvpTarget.classIcon, classIcon)
        SetHiddenIfChanged(PvpTarget.classIcon, classIcon == "")
        SetColorIfChanged(PvpTarget.classIcon, 1, 1, 1, 1)

        local alliance = GetUnitNumber("GetUnitAlliance")
        local rank = GetUnitNumber("GetUnitAvARank")
        local rankIcon = IsPlayerTarget() and rank and rank > 0 and GetRankIcon(rank) or ""
        SetTextureIfChanged(PvpTarget.rankIcon, rankIcon)
        SetHiddenIfChanged(PvpTarget.rankIcon, rankIcon == "")
        local r, g, b, a = GetAllianceTint(alliance)
        SetColorIfChanged(PvpTarget.rankIcon, r, g, b, a)

        local championPoints = GetChampionPoints()
        SetTextIfChanged(PvpTarget.cp, championPoints
            and zo_strformat(GetString(SI_EZOCOMBAT_PVP_CP), championPoints)
            or "")
        SetHiddenIfChanged(PvpTarget.cp, not championPoints)
    end
    SetHiddenIfChanged(PvpTarget.frame, false)
    EnsureWorldUpdate()
end

local function CreateControl()
    PvpTarget.frame = WM:CreateControl("EZOCombatPvpTargetFrame", PvpTarget.root, CT_CONTROL)
    PvpTarget.frame:SetDimensions(FRAME_WIDTH, FRAME_HEIGHT)
    PvpTarget.frame:SetMovable(false)
    PvpTarget.frame:SetMouseEnabled(false)
    PvpTarget.frame:SetClampedToScreen(true)

    PvpTarget.name = WM:CreateControl(nil, PvpTarget.frame, CT_LABEL)
    PvpTarget.name:SetAnchor(TOPLEFT, PvpTarget.frame, TOPLEFT, 0, 0)
    PvpTarget.name:SetDimensions(CONTENT_WIDTH, 18)
    PvpTarget.name:SetFont("ZoFontGameBold")
    PvpTarget.name:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    PvpTarget.name:SetColor(1, 1, 1, 1)
    PvpTarget.name:SetMouseEnabled(false)

    PvpTarget.alert = WM:CreateControl(nil, PvpTarget.frame, CT_TEXTURE)
    PvpTarget.alert:SetDimensions(22, 22)
    PvpTarget.alert:SetAnchor(TOPRIGHT, PvpTarget.frame, TOPRIGHT, 2, -2)
    PvpTarget.alert:SetTexture(WARNING_TEXTURE)
    PvpTarget.alert:SetColor(1, 0.25, 0.12, 1)
    PvpTarget.alert:SetHidden(true)
    PvpTarget.alert:SetMouseEnabled(false)

    PvpTarget.healthFill = WM:CreateControl(nil, PvpTarget.frame, CT_TEXTURE)
    PvpTarget.healthFill:SetAnchor(TOPLEFT, PvpTarget.frame, TOPLEFT, 0, 21)
    PvpTarget.healthFill:SetDimensions(CONTENT_WIDTH, HEALTH_BAR_HEIGHT)
    PvpTarget.healthFill:SetTexture(HEALTH_TEXTURE)
    PvpTarget.healthFill:SetColor(0.75, 0.06, 0.06, 1)
    PvpTarget.healthFill:SetHidden(true)
    PvpTarget.healthFill:SetMouseEnabled(false)

    PvpTarget.health = WM:CreateControl(nil, PvpTarget.frame, CT_LABEL)
    PvpTarget.health:SetAnchor(TOPLEFT, PvpTarget.frame, TOPLEFT, 0, 17)
    PvpTarget.health:SetDimensions(CONTENT_WIDTH, 16)
    PvpTarget.health:SetFont("ZoFontGameSmall")
    PvpTarget.health:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    PvpTarget.health:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    PvpTarget.health:SetColor(1, 1, 1, 1)
    PvpTarget.health:SetMouseEnabled(false)

    PvpTarget.classIcon = WM:CreateControl(nil, PvpTarget.frame, CT_TEXTURE)
    PvpTarget.classIcon:SetDimensions(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
    PvpTarget.classIcon:SetAnchor(TOPLEFT, PvpTarget.frame, TOPLEFT, 4, 40)
    PvpTarget.classIcon:SetMouseEnabled(false)

    PvpTarget.cp = WM:CreateControl(nil, PvpTarget.frame, CT_LABEL)
    PvpTarget.cp:SetAnchor(TOPLEFT, PvpTarget.frame, TOPLEFT, 30, 40)
    PvpTarget.cp:SetDimensions(76, CLASS_ICON_SIZE)
    PvpTarget.cp:SetFont("ZoFontGameSmall")
    PvpTarget.cp:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    PvpTarget.cp:SetColor(0.90, 0.90, 0.90, 1)
    PvpTarget.cp:SetMouseEnabled(false)

    PvpTarget.rankIcon = WM:CreateControl(nil, PvpTarget.frame, CT_TEXTURE)
    PvpTarget.rankIcon:SetDimensions(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
    PvpTarget.rankIcon:SetAnchor(TOPLEFT, PvpTarget.frame, TOPLEFT, 112, 40)
    PvpTarget.rankIcon:SetMouseEnabled(false)

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
    PvpTarget.root:SetDrawLayer(DL_OVERLAY)
    PvpTarget.root:SetHidden(true)
    PvpTarget.renderControl = WM:CreateControl("EZOCombatPvpTargetRender", PvpTarget.root, CT_CONTROL)
    PvpTarget.renderControl:SetAnchorFill(PvpTarget.root)
    PvpTarget.renderControl:Create3DRenderSpace()
    PvpTarget.renderControl:SetHidden(true)
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

function PvpTarget.SetScope(scope)
    local settings = GetSettings()
    if not settings then
        return false
    end
    settings.scope = scope == SCOPE_TEST and SCOPE_TEST or SCOPE_PVP
    PvpTarget.targetIdentity = nil
    PvpTarget.holdUntilMs = nil
    PvpTarget.wasBelowThreshold = false
    ResetAlert()
    PvpTarget.Refresh()
    return true
end

function PvpTarget.GetScope()
    return GetScope()
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

function PvpTarget.SetHeadOffset(value)
    local settings = GetSettings()
    if not settings then
        return false
    end
    value = tonumber(value) or 2.8
    settings.headOffset = math.max(1.5, math.min(4.5, math.floor(value * 10 + 0.5) / 10))
    PvpTarget.Refresh()
    return true
end

function PvpTarget.GetHeadOffset()
    return GetHeadOffsetM()
end

function PvpTarget.SetHoldDuration(value)
    local settings = GetSettings()
    if not settings then
        return false
    end
    value = tonumber(value) or 1.5
    settings.holdDuration = math.max(0, math.min(5, math.floor(value * 2 + 0.5) / 2))
    if settings.holdDuration <= 0 and PvpTarget.holdUntilMs then
        PvpTarget.holdUntilMs = nil
        PvpTarget.targetIdentity = nil
        SetHiddenIfChanged(PvpTarget.frame, true)
        StopWorldUpdate()
    end
    PvpTarget.Refresh()
    return true
end

function PvpTarget.GetHoldDuration()
    local settings = GetSettings()
    local value = settings and tonumber(settings.holdDuration) or 1.5
    return math.max(0, math.min(5, value))
end

function PvpTarget.Refresh()
    PvpTarget.lastRefreshMs = GetNowMilliseconds()
    PvpTarget.refreshPending = false
    local active = IsEnabled() and IsHudScene() and (GetScope() == SCOPE_TEST or IsPvpContext()) or false
    SyncTargetEvents(active)
    if not active then
        StopWorldUpdate()
        PvpTarget.targetIdentity = nil
        PvpTarget.holdUntilMs = nil
        PvpTarget.metadataRefreshAt = nil
        PvpTarget.wasBelowThreshold = false
        ResetAlert()
        SetHiddenIfChanged(PvpTarget.root, true)
        SetHiddenIfChanged(PvpTarget.frame, true)
        return
    end
    PvpTarget.Create()
    UpdateData()
    local frameVisible = not PvpTarget.frame:IsHidden()
    SetHiddenIfChanged(PvpTarget.root, not frameVisible)
end

function PvpTarget.DebugSnapshot()
    if not ADDON.IsDebugModeEnabled or not ADDON.IsDebugModeEnabled() then
        return false
    end
    local current, maximum = GetHealth()
    local percent = current and maximum and maximum > 0 and (current / maximum * 100) or nil
    ADDON.DebugLog(string.format(
        "pvp-target scope=%s context=%s exists=%s player=%s attackable=%s name=%s health=%s/%s percent=%s threshold=%s alert=%s hold=%s headOffset=%s",
        tostring(GetScope()),
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
        tostring(GetHoldDurationMs() / 1000),
        tostring(GetHeadOffsetM())
    ))
    return true
end

local function RegisterTargetEvents()
    local namespace = ADDON.name .. "PvpTarget"
    local function OnTargetChanged()
        ResetAlert()
        PvpTarget.metadataRefreshAt = nil
        PvpTarget.Refresh()
    end

    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_RETICLE_TARGET_CHANGED, OnTargetChanged)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_RETICLE_TARGET_PLAYER_CHANGED, OnTargetChanged)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_POWER_UPDATE, QueueRefresh)
    EVENT_MANAGER:AddFilterForEvent(
        namespace,
        EVENT_POWER_UPDATE,
        REGISTER_FILTER_POWER_TYPE,
        COMBAT_MECHANIC_FLAGS_HEALTH,
        REGISTER_FILTER_UNIT_TAG,
        UNIT_TAG
    )
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_UNIT_DEATH_STATE_CHANGED, QueueRefresh)
    EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG, UNIT_TAG)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_UNIT_CREATED, QueueRefresh)
    EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_UNIT_CREATED, REGISTER_FILTER_UNIT_TAG, UNIT_TAG)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_UNIT_DESTROYED, QueueRefresh)
    EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_UNIT_DESTROYED, REGISTER_FILTER_UNIT_TAG, UNIT_TAG)
end

SyncTargetEvents = function(active)
    if active == (PvpTarget.eventsActive == true) then
        return
    end
    PvpTarget.eventsActive = active
    if active then
        RegisterTargetEvents()
        return
    end
    for _, event in ipairs({ EVENT_RETICLE_TARGET_CHANGED, EVENT_RETICLE_TARGET_PLAYER_CHANGED,
        EVENT_POWER_UPDATE, EVENT_UNIT_DEATH_STATE_CHANGED, EVENT_UNIT_CREATED, EVENT_UNIT_DESTROYED }) do
        EVENT_MANAGER:UnregisterForEvent(ADDON.name .. "PvpTarget", event)
    end
    EVENT_MANAGER:UnregisterForUpdate(REFRESH_UPDATE_NAME)
    PvpTarget.refreshRegistered = false
end

function PvpTarget.Init()
    local namespace = ADDON.name .. "PvpTargetLifecycle"
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_ZONE_CHANGED, PvpTarget.Refresh)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_ACTIVATED, PvpTarget.Refresh)
    if SCENE_MANAGER and type(SCENE_MANAGER.RegisterCallback) == "function" then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", PvpTarget.Refresh)
    end
    PvpTarget.Refresh()
end
