EZOCombat = EZOCombat or {}
EZOCombat.Overlays = EZOCombat.Overlays or {}

local ADDON = EZOCombat
local Overlays = ADDON.Overlays
local WM = WINDOW_MANAGER
local ICON_SIZE = 54
local KEYBIND_HEIGHT = 20
local CONTROL_HEIGHT = ICON_SIZE + KEYBIND_HEIGHT
local CLOSE_SIZE = 16

local function IsHudScene()
    return SCENE_MANAGER
        and type(SCENE_MANAGER.IsShowing) == "function"
        and (SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui"))
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

local function ApplyPosition(control, tracker, index)
    control:ClearAnchors()
    if tracker.x and tracker.y then
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, tracker.x, tracker.y)
        return
    end

    local column = (index - 1) % 4
    local row = math.floor((index - 1) / 4)
    control:SetAnchor(CENTER, GuiRoot, CENTER, 140 + column * 88, -90 + row * 84)
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

local function CreateControl(tracker)
    local control = WM:CreateControl("EZOCombatOverlay" .. tracker.id, Overlays.root, CT_CONTROL)
    control:SetDimensions(ICON_SIZE, CONTROL_HEIGHT)
    control:SetMovable(true)
    control:SetMouseEnabled(true)
    control:SetClampedToScreen(true)
    control:SetHidden(true)
    control.trackerId = tracker.id

    local background = WM:CreateControl(nil, control, CT_BACKDROP)
    background:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
    background:SetDimensions(ICON_SIZE, ICON_SIZE)
    background:SetEdgeTexture(nil, 1, 1, 1, 0)
    background:SetCenterColor(0.02, 0.02, 0.03, 0.86)

    local texture = WM:CreateControl(nil, control, CT_TEXTURE)
    texture:SetAnchor(TOPLEFT, background, TOPLEFT, 3, 3)
    texture:SetAnchor(BOTTOMRIGHT, background, BOTTOMRIGHT, -3, -3)
    control.texture = texture

    local priority = WM:CreateControl(nil, control, CT_LABEL)
    priority:SetAnchor(BOTTOMLEFT, background, BOTTOMLEFT, 4, -2)
    priority:SetFont("ZoFontGameSmall")
    priority:SetColor(1, 1, 1, 1)
    control.priority = priority

    local binding = WM:CreateControl(nil, control, CT_LABEL)
    binding:SetAnchor(TOP, background, BOTTOM, 0, 1)
    binding:SetDimensions(80, KEYBIND_HEIGHT)
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
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:StartMoving()
        end
    end)
    control:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:StopMovingOrResizing()
        end
    end)
    control:SetHandler("OnMoveStop", function()
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
    local showAllConfigured = ADDON.Window
        and type(ADDON.Window.IsShowingAllConfigured) == "function"
        and ADDON.Window.IsShowingAllConfigured()
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
        ApplyPosition(control, tracker, index)
        control:SetHidden(false)
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
