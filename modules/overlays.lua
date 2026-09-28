EZOCombat = EZOCombat or {}
EZOCombat.Overlays = EZOCombat.Overlays or {}

local ADDON = EZOCombat
local Overlays = ADDON.Overlays
local WM = WINDOW_MANAGER
local KEYBIND_HEIGHT = 34
local KEYBIND_WIDTH = 112
local KEYBIND_SCALE_PERCENT = 120
local CLOSE_SIZE = 16

Overlays.DEFAULT_ICON_SIZE = 54
Overlays.MIN_ICON_SIZE = 32
Overlays.MAX_ICON_SIZE = 128
Overlays.KEYBIND_HEIGHT = KEYBIND_HEIGHT
Overlays.KEYBIND_WIDTH = KEYBIND_WIDTH

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

local function SetMovableIfChanged(control, movable)
    if control.ezoCombatMovable ~= movable then
        control.ezoCombatMovable = movable
        control:SetMovable(movable)
    end
end

local function SetDimensionsIfChanged(control, width, height)
    if not control then
        return
    end
    if control.ezoCombatWidth ~= width or control.ezoCombatHeight ~= height then
        control.ezoCombatWidth = width
        control.ezoCombatHeight = height
        control:SetDimensions(width, height)
    end
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

local function ApplyManualPosition(control, tracker, index)
    -- Refreshes can arrive while ESO is moving the control. Re-anchoring a
    -- moving TopLevelWindow here makes the cursor-to-icon offset jump.
    if control.ezoCombatMoving == true then
        return
    end
    if tracker.x and tracker.y then
        if control.ezoCombatAnchorMode == "manual-saved"
            and control.ezoCombatAnchorX == tracker.x
            and control.ezoCombatAnchorY == tracker.y then
            return
        end
        control.ezoCombatAnchorMode = "manual-saved"
        control.ezoCombatAnchorX = tracker.x
        control.ezoCombatAnchorY = tracker.y
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, tracker.x, tracker.y)
        return
    end

    local iconSize = Overlays.GetIconSize()
    local column = (index - 1) % 4
    local row = math.floor((index - 1) / 4)
    local x = 140 + column * (iconSize + 34)
    local y = -90 + row * (iconSize + 30)
    if control.ezoCombatAnchorMode == "manual-default"
        and control.ezoCombatAnchorX == x
        and control.ezoCombatAnchorY == y then
        return
    end
    control.ezoCombatAnchorMode = "manual-default"
    control.ezoCombatAnchorX = x
    control.ezoCombatAnchorY = y
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, x, y)
end

local function ApplyAutomaticContainer(layoutResult)
    local container = Overlays.autoContainer
    if not container then
        return
    end
    SetHiddenIfChanged(container, false)
    if container.ezoCombatMoving == true then
        return
    end
    SetDimensionsIfChanged(container, layoutResult.width, layoutResult.height)
    local anchorX, anchorY = ADDON.Layout.GetAnchor(ADDON.Layout.GetMode())
    local pixelX = anchorX * GuiRoot:GetWidth()
    local pixelY = anchorY * GuiRoot:GetHeight()
    if container.ezoCombatAnchorMode == "automatic"
        and container.ezoCombatAnchorX == pixelX
        and container.ezoCombatAnchorY == pixelY then
        return
    end
    container.ezoCombatAnchorMode = "automatic"
    container.ezoCombatAnchorX = pixelX
    container.ezoCombatAnchorY = pixelY
    container:ClearAnchors()
    container:SetAnchor(
        CENTER,
        GuiRoot,
        TOPLEFT,
        pixelX,
        pixelY
    )
end

local function ApplyAutomaticPosition(control, position)
    if not position or not Overlays.autoContainer then
        return
    end
    if control:GetParent() ~= Overlays.autoContainer then
        control:SetParent(Overlays.autoContainer)
        control.ezoCombatAnchorMode = nil
    end
    SetMovableIfChanged(control, false)
    if Overlays.autoContainer.ezoCombatMoving == true then
        return
    end
    if control.ezoCombatAnchorMode == "automatic"
        and control.ezoCombatAnchorX == position.x
        and control.ezoCombatAnchorY == position.y then
        return
    end
    control.ezoCombatAnchorMode = "automatic"
    control.ezoCombatAnchorX = position.x
    control.ezoCombatAnchorY = position.y
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, Overlays.autoContainer, TOPLEFT, position.x, position.y)
end

local function PrepareManualControl(control)
    if control:GetParent() ~= Overlays.root then
        control:SetParent(Overlays.root)
        control.ezoCombatAnchorMode = nil
    end
    SetMovableIfChanged(control, true)
end

local function HideTooltip(control)
    if type(ZO_Tooltips_HideTextTooltip) == "function" then
        ZO_Tooltips_HideTextTooltip(control)
    end
end

local function ClearBinding(control)
    if not control.bindingAction and control.binding
        and control.binding.ezoCombatText == "" then
        return
    end
    if control.bindingAction
        and control.binding
        and type(ZO_Keybindings_UnregisterLabelForBindingUpdate) == "function" then
        ZO_Keybindings_UnregisterLabelForBindingUpdate(control.binding)
    end
    control.bindingAction = nil
    if control.binding then
        control.binding.ezoCombatText = nil
        SetTextIfChanged(control.binding, "")
        SetHiddenIfChanged(control.binding, true)
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
            SetHiddenIfChanged(label, not bindingText or bindingText == "")
        end,
        false,
        false,
        KEYBIND_SCALE_PERCENT
    )
end

local function UpdateStackCount(control, tracker)
    local hasStackProvider = ADDON.AbilityState
        and type(ADDON.AbilityState.IsSlotStackProvider) == "function"
        and ADDON.AbilityState.IsSlotStackProvider(tracker.abilityId)
    if not hasStackProvider then
        SetTextIfChanged(control.stacks, "")
        SetHiddenIfChanged(control.stacks, true)
        return
    end

    local state
    if ADDON.ActionBars and type(ADDON.ActionBars.GetAbilityState) == "function" then
        state = ADDON.ActionBars.GetAbilityState(tracker.abilityId)
    end
    local stackCount = state and tonumber(state.stacks) or 0
    local text = stackCount > 0 and tostring(stackCount) or ""
    SetTextIfChanged(control.stacks, text)
    SetHiddenIfChanged(control.stacks, text == "")
end

local function ApplySize(control)
    local iconSize = Overlays.GetIconSize()
    if control.ezoCombatIconSize == iconSize then
        return
    end
    control.ezoCombatIconSize = iconSize
    SetDimensionsIfChanged(control, iconSize, iconSize + KEYBIND_HEIGHT)
    SetDimensionsIfChanged(control.background, iconSize, iconSize)
    SetDimensionsIfChanged(
        control.stacks,
        math.max(16, iconSize - 8),
        math.max(14, math.floor(iconSize * 0.62))
    )
    control.stacks:SetFont(
        iconSize >= 58 and "ZoFontWinH3"
            or iconSize >= 36 and "ZoFontWinH4"
            or "ZoFontGameLargeBold"
    )
    SetDimensionsIfChanged(control.binding, math.max(KEYBIND_WIDTH, iconSize), KEYBIND_HEIGHT)
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

    local stacks = WM:CreateControl(nil, control, CT_LABEL)
    stacks:SetMouseEnabled(false)
    stacks:SetDimensions(math.max(16, iconSize - 8), math.max(14, math.floor(iconSize * 0.62)))
    stacks:SetAnchor(BOTTOMRIGHT, background, BOTTOMRIGHT, -3, -2)
    stacks:SetFont("ZoFontGameLargeBold")
    stacks:SetColor(0.95, 0.72, 0.22, 1)
    stacks:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    stacks:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    stacks:SetDrawLayer(DL_OVERLAY)
    stacks:SetHidden(true)
    control.stacks = stacks

    local binding = WM:CreateControl(nil, control, CT_LABEL)
    binding:SetAnchor(TOP, background, BOTTOM, 0, 1)
    binding:SetDimensions(math.max(KEYBIND_WIDTH, iconSize), KEYBIND_HEIGHT)
    binding:SetFont("ZoFontGameBold")
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
        local entry = ADDON.ActionBars.GetEntryForAbility(tracker.abilityId)
        local name = entry and entry.name or tostring(tracker.abilityId)
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
    if ADDON.ActionBars and ADDON.ActionBars.SyncTracking then
        ADDON.ActionBars.SyncTracking()
    end
    Overlays.Create()
    if not IsHudScene() then
        SetHiddenIfChanged(Overlays.root, true)
        return
    end

    local active = Overlays.activeControls or {}
    for id in pairs(active) do
        active[id] = nil
    end
    Overlays.activeControls = active
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
            SetHiddenIfChanged(control, true)
        end
    end

    local automatic = ADDON.Layout and ADDON.Layout.IsAutomatic()
    local layoutResult
    if automatic and #visible > 0 then
        layoutResult = ADDON.Layout.Calculate(Overlays.GetIconSize(), KEYBIND_HEIGHT)
        ApplyAutomaticContainer(layoutResult)
    elseif Overlays.autoContainer then
        SetHiddenIfChanged(Overlays.autoContainer, true)
    end

    local index = 0
    for _, tracker in ipairs(visible) do
        index = index + 1
        local control = Overlays.controls[tracker.id]
        if not control then
            control = CreateControl(tracker)
            Overlays.controls[tracker.id] = control
        end
        local entry = ADDON.ActionBars.GetEntryForAbility(tracker.abilityId)
        SetTextureIfChanged(control.texture, entry and entry.icon or "")
        SetTextIfChanged(control.priority, tracker.priority == ADDON.Priority.ALWAYS and "" or "P" .. tostring(tracker.priority))
        UpdateBinding(control, tracker)
        UpdateStackCount(control, tracker)
        ApplySize(control)
        if automatic then
            ApplyAutomaticPosition(control, layoutResult.positions[tracker.id])
        else
            PrepareManualControl(control)
            ApplyManualPosition(control, tracker, index)
        end
        SetHiddenIfChanged(control, false)
    end

    if automatic and Overlays.autoContainer then
        SetHiddenIfChanged(Overlays.autoContainer, index == 0)
    end
    SetHiddenIfChanged(Overlays.root, index == 0)
end

function Overlays.Init()
    Overlays.Create()
    if SCENE_MANAGER and type(SCENE_MANAGER.RegisterCallback) == "function" then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", Overlays.Refresh)
    end
    Overlays.Refresh()
end
