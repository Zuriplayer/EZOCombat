EZOCombat = EZOCombat or {}
EZOCombat.Overlays = EZOCombat.Overlays or {}

local ADDON = EZOCombat
local Overlays = ADDON.Overlays
local WM = WINDOW_MANAGER
local KEYBIND_HEIGHT = 20
local CLOSE_SIZE = 16

Overlays.DEFAULT_ICON_SIZE = 54
Overlays.MIN_ICON_SIZE = 32
Overlays.MAX_ICON_SIZE = 128

local function IsHudScene()
    return SCENE_MANAGER
        and type(SCENE_MANAGER.IsShowing) == "function"
        and (SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui"))
        and not (ADDON.Context
            and type(ADDON.Context.IsHudOverlayBlocked) == "function"
            and ADDON.Context.IsHudOverlayBlocked())
end

local function NormalizeIconSize(value)
    value = tonumber(value) or Overlays.DEFAULT_ICON_SIZE
    value = math.floor(value + 0.5)
    return math.max(Overlays.MIN_ICON_SIZE, math.min(Overlays.MAX_ICON_SIZE, value))
end

function Overlays.GetIconSize()
    local general = ADDON.sv and ADDON.sv.general
    return NormalizeIconSize(general and general.iconSize)
end

function Overlays.SetIconSize(value)
    if not (ADDON.sv and ADDON.sv.general) then
        return false
    end
    ADDON.sv.general.iconSize = NormalizeIconSize(value)
    Overlays.Refresh()
    return true
end

local function GetAbilityDetails(abilityId)
    local name = tostring(abilityId or "")
    local icon = ""
    if type(GetAbilityName) == "function" then
        local ok, value = pcall(GetAbilityName, abilityId)
        if ok and value and value ~= "" then
            name = zo_strformat("<<C:1>>", value)
        end
    end
    if type(GetAbilityIcon) == "function" then
        local ok, value = pcall(GetAbilityIcon, abilityId)
        if ok and value then
            icon = value
        end
    end
    return name, icon
end

local function ApplyManualPosition(control, tracker, index)
    -- Refreshes can arrive while ESO is moving the control. Re-anchoring a
    -- moving TopLevelWindow here makes the cursor-to-icon offset jump.
    if control.ezoCombatMoving == true then
        return
    end
    control:ClearAnchors()
    if tracker.x and tracker.y then
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, tracker.x, tracker.y)
        return
    end

    local iconSize = Overlays.GetIconSize()
    local column = (index - 1) % 4
    local row = math.floor((index - 1) / 4)
    control:SetAnchor(CENTER, GuiRoot, CENTER, 140 + column * (iconSize + 34), -90 + row * (iconSize + 30))
end

local function ApplyAutomaticContainer(layoutResult)
    local container = Overlays.autoContainer
    if not container then
        return
    end
    container:SetHidden(false)
    if container.ezoCombatMoving == true then
        return
    end
    container:SetDimensions(layoutResult.width, layoutResult.height)
    local anchorX, anchorY = ADDON.Layout.GetAnchor(ADDON.Layout.GetMode())
    container:ClearAnchors()
    container:SetAnchor(
        CENTER,
        GuiRoot,
        TOPLEFT,
        anchorX * GuiRoot:GetWidth(),
        anchorY * GuiRoot:GetHeight()
    )
end

local function ApplyAutomaticPosition(control, position)
    if not position or not Overlays.autoContainer then
        return
    end
    if control:GetParent() ~= Overlays.autoContainer then
        control:SetParent(Overlays.autoContainer)
    end
    control:SetMovable(false)
    if Overlays.autoContainer.ezoCombatMoving == true then
        return
    end
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, Overlays.autoContainer, TOPLEFT, position.x, position.y)
end

local function PrepareManualControl(control)
    if control:GetParent() ~= Overlays.root then
        control:SetParent(Overlays.root)
    end
    control:SetMovable(true)
end

local function HideTooltip(control)
    if type(ZO_Tooltips_HideTextTooltip) == "function" then
        ZO_Tooltips_HideTextTooltip(control)
    end
end

local function ClearBinding(control)
    if control.bindingAction
        and control.binding
        and type(ZO_Keybindings_UnregisterLabelForBindingUpdate) == "function" then
        ZO_Keybindings_UnregisterLabelForBindingUpdate(control.binding)
    end
    control.bindingAction = nil
    if control.binding then
        control.binding:SetText("")
        control.binding:SetHidden(true)
    end
end

local function UpdateBinding(control, tracker)
    local entry = ADDON.ActionBars
        and ADDON.ActionBars.GetActiveEntryForAbility
        and ADDON.ActionBars.GetActiveEntryForAbility(tracker.abilityId)
    if not entry or type(ZO_Keybindings_RegisterLabelForBindingUpdate) ~= "function" then
        ClearBinding(control)
        return
    end

    local keyboardActionName
    local gamepadActionName
    if ACTION_BAR_ASSIGNMENT_MANAGER
        and type(ACTION_BAR_ASSIGNMENT_MANAGER.GetKeyboardAndGamepadActionNameForSlot) == "function" then
        local ok, keyboardName, gamepadName = pcall(function()
            return ACTION_BAR_ASSIGNMENT_MANAGER:GetKeyboardAndGamepadActionNameForSlot(
                entry.slotIndex,
                entry.hotbarCategory
            )
        end)
        if ok then
            keyboardActionName = keyboardName
            gamepadActionName = gamepadName
        end
    end
    keyboardActionName = keyboardActionName or "ACTION_BUTTON_" .. tostring(entry.slotIndex)
    gamepadActionName = gamepadActionName or "GAMEPAD_ACTION_BUTTON_" .. tostring(entry.slotIndex)
    local bindingKey = keyboardActionName .. "|" .. gamepadActionName
    if control.bindingAction == bindingKey then
        return
    end
    ClearBinding(control)
    control.bindingAction = bindingKey
    ZO_Keybindings_RegisterLabelForBindingUpdate(
        control.binding,
        keyboardActionName,
        false,
        gamepadActionName,
        function(label, bindingText)
            label:SetHidden(not bindingText or bindingText == "")
        end,
        false,
        false,
        80
    )
end

local function ApplySize(control)
    local iconSize = Overlays.GetIconSize()
    control:SetDimensions(iconSize, iconSize + KEYBIND_HEIGHT)
    control.background:SetDimensions(iconSize, iconSize)
    control.binding:SetDimensions(math.max(80, iconSize), KEYBIND_HEIGHT)
end

local function CreateControl(tracker)
    local iconSize = Overlays.GetIconSize()
    local control = WM:CreateControl("EZOCombatOverlay" .. tracker.id, Overlays.root, CT_CONTROL)
    control:SetDimensions(iconSize, iconSize + KEYBIND_HEIGHT)
    control:SetMovable(true)
    control:SetMouseEnabled(true)
    control:SetClampedToScreen(true)
    control:SetHidden(true)
    control.trackerId = tracker.id

    local background = WM:CreateControl(nil, control, CT_BACKDROP)
    background:SetMouseEnabled(false)
    background:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
    background:SetDimensions(iconSize, iconSize)
    background:SetEdgeTexture(nil, 1, 1, 1, 0)
    background:SetCenterColor(0.02, 0.02, 0.03, 0.86)
    control.background = background

    local texture = WM:CreateControl(nil, control, CT_TEXTURE)
    texture:SetMouseEnabled(false)
    texture:SetAnchor(TOPLEFT, background, TOPLEFT, 3, 3)
    texture:SetAnchor(BOTTOMRIGHT, background, BOTTOMRIGHT, -3, -3)
    control.texture = texture

    local priority = WM:CreateControl(nil, control, CT_LABEL)
    priority:SetMouseEnabled(false)
    priority:SetAnchor(BOTTOMLEFT, background, BOTTOMLEFT, 4, -2)
    priority:SetFont("ZoFontGameSmall")
    priority:SetColor(1, 1, 1, 1)
    control.priority = priority

    local binding = WM:CreateControl(nil, control, CT_LABEL)
    binding:SetAnchor(TOP, background, BOTTOM, 0, 1)
    binding:SetDimensions(math.max(80, iconSize), KEYBIND_HEIGHT)
    binding:SetFont("ZoFontGameSmall")
    binding:SetColor(1, 1, 1, 1)
    binding:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    binding:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    binding:SetMouseEnabled(false)
    binding:SetHidden(true)
    control.binding = binding

    local close = WM:CreateControl(nil, control, CT_BUTTON)
    close:SetDimensions(CLOSE_SIZE, CLOSE_SIZE)
    close:SetAnchor(TOPRIGHT, background, TOPRIGHT, 1, -1)
    close:SetFont("ZoFontGameBold")
    close:SetText("X")
    close:SetNormalFontColor(1, 0.85, 0.85, 1)
    close:SetMouseOverFontColor(1, 0.35, 0.35, 1)
    close:SetHandler("OnClicked", function()
        local current = ADDON.Priority and ADDON.Priority.GetTracker(tracker.abilityId)
        if current then
            ADDON.Priority.SetEnabled(current, false)
            if ADDON.Settings then
                ADDON.Settings.RequestSettingsRefresh(true)
            end
        end
    end)
    close:SetHandler("OnMouseEnter", function(controlRef)
        if type(ZO_Tooltips_ShowTextTooltip) == "function" then
            ZO_Tooltips_ShowTextTooltip(controlRef, BOTTOM, GetString(SI_EZOCOMBAT_DISABLE_ICON))
        end
    end)
    close:SetHandler("OnMouseExit", HideTooltip)

    control:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            if ADDON.Layout and ADDON.Layout.IsAutomatic() and Overlays.autoContainer then
                Overlays.autoContainer.ezoCombatMoving = true
                Overlays.autoContainer:StartMoving()
            else
                control.ezoCombatMoving = true
                control:StartMoving()
            end
        end
    end)
    control:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            if ADDON.Layout and ADDON.Layout.IsAutomatic() and Overlays.autoContainer then
                Overlays.autoContainer:StopMovingOrResizing()
                Overlays.autoContainer.ezoCombatMoving = false
            else
                control:StopMovingOrResizing()
                control.ezoCombatMoving = false
            end
        end
    end)
    control:SetHandler("OnMoveStop", function()
        control.ezoCombatMoving = false
        if ADDON.Layout and ADDON.Layout.IsAutomatic() then
            return
        end
        local current = ADDON.Priority and ADDON.Priority.GetTracker(tracker.abilityId)
        if current then
            ADDON.Priority.SetPosition(current, control:GetLeft(), control:GetTop())
        end
    end)
    control:SetHandler("OnMouseEnter", function(controlRef)
        local name = GetAbilityDetails(tracker.abilityId)
        if type(ZO_Tooltips_ShowTextTooltip) == "function" then
            ZO_Tooltips_ShowTextTooltip(controlRef, TOP, name)
        end
    end)
    control:SetHandler("OnMouseExit", HideTooltip)
    return control
end

local function RegisterFragment()
    if Overlays.fragment or type(ZO_HUDFadeSceneFragment) ~= "table" then
        return
    end
    Overlays.fragment = ZO_HUDFadeSceneFragment:New(Overlays.root)
    HUD_SCENE:AddFragment(Overlays.fragment)
    HUD_UI_SCENE:AddFragment(Overlays.fragment)
end

function Overlays.Create()
    if Overlays.root then
        return Overlays.root
    end

    Overlays.root = WM:CreateTopLevelWindow("EZOCombatOverlayRoot")
    Overlays.root:SetAnchorFill(GuiRoot)
    Overlays.root:SetHidden(true)
    Overlays.controls = {}

    Overlays.autoContainer = WM:CreateControl("EZOCombatAutomaticLayout", Overlays.root, CT_CONTROL)
    Overlays.autoContainer:SetDimensions(1, 1)
    Overlays.autoContainer:SetMovable(true)
    Overlays.autoContainer:SetMouseEnabled(false)
    Overlays.autoContainer:SetClampedToScreen(true)
    Overlays.autoContainer:SetHidden(true)
    Overlays.autoContainer:SetHandler("OnMoveStop", function(container)
        container.ezoCombatMoving = false
        if not (ADDON.Layout and ADDON.Layout.IsAutomatic()) then
            return
        end
        local centerX, centerY = container:GetCenter()
        ADDON.Layout.SetAnchorFromPixels(ADDON.Layout.GetMode(), centerX, centerY)
    end)
    RegisterFragment()
    return Overlays.root
end

function Overlays.Refresh()
    Overlays.Create()
    if not IsHudScene() then
        Overlays.root:SetHidden(true)
        return
    end

    local active = {}
    local showAllConfigured = (ADDON.Window
        and type(ADDON.Window.IsShowingAllConfigured) == "function"
        and ADDON.Window.IsShowingAllConfigured())
        or (ADDON.Layout
            and type(ADDON.Layout.IsEditMode) == "function"
            and ADDON.Layout.IsEditMode())
    local visible = ADDON.Priority
        and ADDON.Priority.Evaluate
        and ADDON.Priority.Evaluate(showAllConfigured)
        or {}
    for _, tracker in ipairs(visible) do
        active[tracker.id] = true
    end

    for id, control in pairs(Overlays.controls) do
        if not active[id] then
            ClearBinding(control)
            control:SetHidden(true)
        end
    end

    local automatic = ADDON.Layout and ADDON.Layout.IsAutomatic()
    local layoutResult
    if automatic then
        layoutResult = ADDON.Layout.Calculate(Overlays.GetIconSize(), KEYBIND_HEIGHT)
        ApplyAutomaticContainer(layoutResult)
    elseif Overlays.autoContainer then
        Overlays.autoContainer:SetHidden(true)
    end

    local index = 0
    for _, tracker in ipairs(visible) do
        index = index + 1
        local control = Overlays.controls[tracker.id]
        if not control then
            control = CreateControl(tracker)
            Overlays.controls[tracker.id] = control
        end
        local _, icon = GetAbilityDetails(tracker.abilityId)
        control.texture:SetTexture(icon)
        control.priority:SetText(
            tracker.priority == ADDON.Priority.ALWAYS and "" or "P" .. tostring(tracker.priority)
        )
        UpdateBinding(control, tracker)
        ApplySize(control)
        if automatic then
            ApplyAutomaticPosition(control, layoutResult.positions[tracker.id])
        else
            PrepareManualControl(control)
            ApplyManualPosition(control, tracker, index)
        end
        control:SetHidden(false)
    end

    if automatic and Overlays.autoContainer then
        Overlays.autoContainer:SetHidden(index == 0)
    end
    Overlays.root:SetHidden(index == 0)
end

function Overlays.Init()
    Overlays.Create()
    if SCENE_MANAGER and type(SCENE_MANAGER.RegisterCallback) == "function" then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", Overlays.Refresh)
    end
    Overlays.Refresh()
end
