EZOCombat = EZOCombat or {}
EZOCombat.Window = EZOCombat.Window or {}

local ADDON = EZOCombat
local Window = ADDON.Window
local WM = WINDOW_MANAGER
local WINDOW_NAME = "EZOCombatWindow"
local WIDTH = 760
local HEIGHT = 330
local HEADER_HEIGHT = 34
local SLOT_SIZE = 54
local TITLE_COLOR = "B040FF"

local function DebugLog(message)
    if ADDON.DebugLog then
        ADDON.DebugLog("[Window] " .. tostring(message))
    end
end

local function IsHudScene()
    return SCENE_MANAGER
        and type(SCENE_MANAGER.IsShowing) == "function"
        and (SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui"))
        and not (ADDON.Context
            and type(ADDON.Context.IsHudOverlayBlocked) == "function"
            and ADDON.Context.IsHudOverlayBlocked())
end

local function SavedWindow()
    local sv = ADDON.sv
    if not sv then
        return nil
    end
    sv.window = sv.window or {}
    return sv.window
end

local function GetBarLabel(key)
    return key == "back" and GetString(SI_EZOCOMBAT_BACK_BAR) or GetString(SI_EZOCOMBAT_FRONT_BAR)
end

local function GetEntryTooltip(entry)
    if not entry or entry.abilityId == 0 then
        return GetString(SI_EZOCOMBAT_EMPTY_SLOT)
    end
    return string.format("%s\n%s", entry.name, GetString(SI_EZOCOMBAT_HOVER_CONFIGURE))
end

local function PopulateCombo(comboControl, labels, values, currentValue, onSelect)
    if type(ZO_ComboBox_ObjectFromContainer) ~= "function" then
        DebugLog("combo unavailable: ZO_ComboBox_ObjectFromContainer is not a function")
        return false
    end
    local ok, combo = pcall(ZO_ComboBox_ObjectFromContainer, comboControl)
    if not ok or not combo then
        DebugLog("combo unavailable: " .. tostring(combo))
        return false
    end
    local populated, errorText = pcall(function()
        combo:SetSortsItems(false)
        combo:ClearItems()
        local selectedLabel
        for index, label in ipairs(labels) do
            local value = values[index]
            local item = combo:CreateItemEntry(label, function()
                onSelect(value)
            end)
            combo:AddItem(item, ZO_COMBOBOX_SUPPRESS_UPDATE)
            if value == currentValue then
                selectedLabel = label
            end
        end
        combo:UpdateItems()
        combo:SetSelectedItemText(selectedLabel or "")
    end)
    if not populated then
        DebugLog("combo populate failed: " .. tostring(errorText))
        return false
    end
    return true
end

local function PriorityChoices()
    local labels = { GetString(SI_EZOCOMBAT_PRIORITY_ALWAYS) }
    local values = { ADDON.Priority.ALWAYS }
    for priority = ADDON.Priority.MIN, ADDON.Priority.MAX do
        labels[#labels + 1] = zo_strformat(GetString(SI_EZOCOMBAT_PRIORITY_LABEL), priority)
        values[#values + 1] = priority
    end
    return labels, values
end

local function CreateSlot(parent, index)
    -- Keep the interaction target as a direct child of the bar. EZOArmory's
    -- verified skill icons use this sibling layout; a CT_BACKDROP parent does
    -- not deliver mouse input to its texture child in this window.
    local frame = WM:CreateControl(nil, parent, CT_BACKDROP)
    frame:SetDimensions(SLOT_SIZE, SLOT_SIZE)
    frame:SetEdgeTexture(nil, 1, 1, 1, 0)
    frame:SetCenterColor(0.05, 0.04, 0.07, 0.9)
    frame:SetMouseEnabled(false)

    local icon = WM:CreateControl(nil, parent, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, frame, TOPLEFT, 3, 3)
    icon:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -3, -3)
    icon:SetMouseEnabled(true)

    local marker = WM:CreateControl(nil, parent, CT_LABEL)
    marker:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -3, -2)
    marker:SetFont("ZoFontGameSmall")
    marker:SetColor(1, 1, 1, 1)
    marker:SetMouseEnabled(false)

    -- CT_BUTTON is the native click target used by ESO windows. Keep it above
    -- the visual siblings so the interaction is not affected by texture or
    -- label input routing.
    local target = WM:CreateControl(nil, parent, CT_BUTTON)
    target:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    target:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 0, 0)
    target:SetMouseEnabled(true)
    target:SetText("")

    local slot = {
        frame = frame,
        icon = icon,
        marker = marker,
        target = target,
        index = index,
    }
    target:SetHandler("OnMouseEnter", function()
        local entry = slot.entry or {}
        if type(ZO_Tooltips_ShowTextTooltip) == "function" then
            ZO_Tooltips_ShowTextTooltip(target, TOP, GetEntryTooltip(entry))
        end
    end)
    target:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            Window.ToggleEntryDetails(slot.entry or {})
        end
    end)
    target:SetHandler("OnMouseExit", function()
        if type(ZO_Tooltips_HideTextTooltip) == "function" then
            ZO_Tooltips_HideTextTooltip(target)
        end
    end)
    return slot
end

local function CreateBar(parent, key, offsetY)
    local bar = WM:CreateControl(nil, parent, CT_CONTROL)
    bar:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, offsetY)
    bar:SetDimensions(410, SLOT_SIZE + 24)

    local label = WM:CreateControl(nil, bar, CT_LABEL)
    label:SetAnchor(TOPLEFT, bar, TOPLEFT, 0, 0)
    label:SetFont("ZoFontGameBold")
    label:SetColor(0.88, 0.78, 1, 1)
    label:SetText(GetBarLabel(key))

    bar.slots = {}
    for index = 1, 6 do
        local slot = CreateSlot(bar, index)
        slot.frame:SetAnchor(TOPLEFT, bar, TOPLEFT, (index - 1) * (SLOT_SIZE + 10), 24)
        bar.slots[index] = slot
    end
    return bar
end

local function CreateDetails(parent)
    local details = WM:CreateControl(nil, parent, CT_CONTROL)
    details:SetAnchor(TOPLEFT, parent, TOPLEFT, 440, 16)
    details:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0)
    details:SetHidden(true)

    local name = WM:CreateControl(nil, details, CT_LABEL)
    name:SetAnchor(TOPLEFT, details, TOPLEFT, 0, 0)
    name:SetFont("ZoFontWinH2")
    name:SetColor(1, 1, 1, 1)
    name:SetWidth(280)
    details.name = name

    local conditionLabel = WM:CreateControl(nil, details, CT_LABEL)
    conditionLabel:SetAnchor(TOPLEFT, name, BOTTOMLEFT, 0, 16)
    conditionLabel:SetFont("ZoFontGame")
    conditionLabel:SetColor(0.75, 0.75, 0.8, 1)
    conditionLabel:SetText(GetString(SI_EZOCOMBAT_CONDITION))

    local condition = WM:CreateControlFromVirtual("EZOCombatConditionCombo", details, "ZO_ComboBox")
    condition:SetHeight(28)
    condition:SetAnchor(TOPLEFT, conditionLabel, BOTTOMLEFT, 0, 4)
    condition:SetWidth(270)
    details.condition = condition

    local priorityLabel = WM:CreateControl(nil, details, CT_LABEL)
    priorityLabel:SetAnchor(TOPLEFT, condition, BOTTOMLEFT, 0, 12)
    priorityLabel:SetFont("ZoFontGame")
    priorityLabel:SetColor(0.75, 0.75, 0.8, 1)
    priorityLabel:SetText(GetString(SI_EZOCOMBAT_PRIORITY))

    local toggle = WM:CreateControl(nil, details, CT_BUTTON)
    toggle:SetDimensions(250, 30)
    toggle:SetAnchor(TOPLEFT, priorityLabel, BOTTOMLEFT, 0, 46)
    toggle:SetFont("ZoFontGame")
    toggle:SetNormalFontColor(0.95, 0.85, 1, 1)
    toggle:SetMouseOverFontColor(1, 1, 1, 1)
    toggle:SetHandler("OnClicked", function()
        Window.ToggleSelectedTracker()
    end)
    details.toggle = toggle

    local priority = WM:CreateControlFromVirtual("EZOCombatPriorityCombo", details, "ZO_ComboBox")
    priority:SetHeight(28)
    priority:SetAnchor(TOPLEFT, priorityLabel, BOTTOMLEFT, 0, 4)
    priority:SetWidth(270)
    details.priority = priority
    return details
end

local function RegisterFragment()
    if Window.fragment or type(ZO_HUDFadeSceneFragment) ~= "table" then
        return
    end
    Window.fragment = ZO_HUDFadeSceneFragment:New(Window.control)
    HUD_SCENE:AddFragment(Window.fragment)
    HUD_UI_SCENE:AddFragment(Window.fragment)
end

function Window.SavePosition()
    local saved = SavedWindow()
    if saved and Window.control then
        saved.x = Window.control:GetLeft()
        saved.y = Window.control:GetTop()
    end
end

function Window.RefreshVisibility()
    if not Window.control then
        return
    end
    Window.control:SetHidden(not (Window.requestedVisible == true and IsHudScene()))
end

function Window.RefreshContext()
    if not Window.contextLabel or not ADDON.Context then
        return
    end
    Window.contextLabel:SetText(string.format(
        "%s - %s",
        ADDON.Context.GetClassLabel(),
        ADDON.Context.GetRoleLabel(ADDON.Context.GetActiveRole())
    ))
end

function Window.IsShowingAllConfigured()
    return Window.showAllConfigured == true
end

function Window.SetShowAllConfigured(enabled)
    Window.showAllConfigured = enabled == true
    if Window.showAllConfiguredCheck and type(ZO_CheckButton_SetCheckState) == "function" then
        ZO_CheckButton_SetCheckState(Window.showAllConfiguredCheck, Window.showAllConfigured)
    end
    DebugLog("show all configured=" .. tostring(Window.showAllConfigured))
    if ADDON.Overlays and type(ADDON.Overlays.Refresh) == "function" then
        ADDON.Overlays.Refresh()
    end
end

function Window.RefreshDetails()
    local details = Window.details
    local entry = Window.selectedEntry
    if not details then
        return
    end
    if not entry or entry.abilityId == 0 then
        DebugLog("details hidden: no slotted entry")
        details:SetHidden(true)
        return
    end

    local tracker = ADDON.Priority.GetTracker(entry.abilityId)
    DebugLog(string.format(
        "details ability=%s tracker=%s enabled=%s priority=%s",
        tostring(entry.abilityId),
        tostring(tracker and tracker.id),
        tostring(tracker and tracker.enabled),
        tostring(tracker and tracker.priority)
    ))
    details.name:SetText(entry.name)
    local conditionReady = PopulateCombo(
        details.condition,
        {
            GetString(SI_EZOCOMBAT_CONDITION_SLOTTED),
            GetString(SI_EZOCOMBAT_CONDITION_ACTIVE),
            GetString(SI_EZOCOMBAT_CONDITION_INACTIVE),
        },
        {
            ADDON.Priority.CONDITION_SLOTTED,
            ADDON.Priority.CONDITION_ACTIVE,
            ADDON.Priority.CONDITION_INACTIVE,
        },
        tracker and tracker.condition or ADDON.Priority.CONDITION_SLOTTED,
        function(value)
            local selectedTracker = ADDON.Priority.EnsureTracker(entry)
            ADDON.Priority.SetCondition(selectedTracker, value)
            Window.RefreshDetails()
            if ADDON.Settings then
                ADDON.Settings.RequestSettingsRefresh(true)
            end
        end
    )
    local priorityLabels, priorityValues = PriorityChoices()
    local priorityReady = PopulateCombo(
        details.priority,
        priorityLabels,
        priorityValues,
        tracker and tracker.priority or ADDON.Priority.DEFAULT,
        function(value)
            local selectedTracker = ADDON.Priority.EnsureTracker(entry)
            ADDON.Priority.SetPriority(selectedTracker, value)
            Window.RefreshDetails()
            if ADDON.Settings then
                ADDON.Settings.RequestSettingsRefresh(true)
            end
        end
    )
    DebugLog(string.format("details controls condition=%s priority=%s", tostring(conditionReady), tostring(priorityReady)))
    details.toggle:SetText(tracker and tracker.enabled and GetString(SI_EZOCOMBAT_DISABLE_ICON) or GetString(SI_EZOCOMBAT_ENABLE_ICON))
    details:SetHidden(false)
end

function Window.SelectEntry(entry)
    Window.selectedEntry = entry
    DebugLog(string.format(
        "selected ability=%s name=%s",
        tostring(entry and entry.abilityId),
        tostring(entry and entry.name)
    ))
    Window.RefreshSelectionVisuals()
    Window.RefreshDetails()
end

function Window.ToggleEntryDetails(entry)
    entry = entry or {}
    if entry.abilityId == 0 then
        return
    end
    local selected = Window.selectedEntry
    if selected
        and selected.hotbar == entry.hotbar
        and selected.slotIndex == entry.slotIndex then
        Window.selectedEntry = nil
        DebugLog(string.format(
            "close details bar=%s slot=%s ability=%s",
            tostring(entry.hotbar),
            tostring(entry.slotIndex),
            tostring(entry.abilityId)
        ))
        Window.RefreshSelectionVisuals()
        Window.RefreshDetails()
        return
    end
    DebugLog(string.format(
        "open details source=right-click bar=%s slot=%s ability=%s name=%s",
        tostring(entry.hotbar),
        tostring(entry.slotIndex),
        tostring(entry.abilityId),
        tostring(entry.name)
    ))
    Window.SelectEntry(entry)
end

function Window.RefreshSelectionVisuals()
    local selected = Window.selectedEntry
    for _, bar in pairs(Window.bars or {}) do
        for _, slot in ipairs(bar.slots or {}) do
            local entry = slot.entry
            local isSelected = selected
                and entry
                and selected.hotbar == entry.hotbar
                and selected.slotIndex == entry.slotIndex
            if isSelected then
                slot.frame:SetCenterColor(0.28, 0.1, 0.36, 0.96)
            else
                slot.frame:SetCenterColor(0.05, 0.04, 0.07, 0.9)
            end
        end
    end
end

function Window.ToggleSelectedTracker()
    local entry = Window.selectedEntry
    if not entry or entry.abilityId == 0 then
        return
    end
    local tracker = ADDON.Priority.EnsureTracker(entry)
    ADDON.Priority.SetEnabled(tracker, not tracker.enabled)
    DebugLog(string.format("toggle tracker=%s enabled=%s", tostring(tracker.id), tostring(tracker.enabled)))
    Window.RefreshDetails()
    if ADDON.Settings then
        ADDON.Settings.RequestSettingsRefresh(true)
    end
end

function Window.CycleSelectedPriority()
    local entry = Window.selectedEntry
    if not entry or entry.abilityId == 0 then
        return
    end
    local tracker = ADDON.Priority.EnsureTracker(entry)
    local nextPriority = tracker.priority + 1
    if nextPriority > ADDON.Priority.MAX then
        nextPriority = ADDON.Priority.ALWAYS
    end
    ADDON.Priority.SetPriority(tracker, nextPriority)
    DebugLog(string.format("cycle tracker=%s priority=%s", tostring(tracker.id), tostring(tracker.priority)))
    Window.RefreshDetails()
    if ADDON.Settings then
        ADDON.Settings.RequestSettingsRefresh(true)
    end
end

function Window.RefreshBars()
    if not Window.bars then
        return
    end
    local bars = ADDON.ActionBars and ADDON.ActionBars.bars or {}
    for key, bar in pairs(Window.bars) do
        local entries = bars[key] or {}
        for index, slot in ipairs(bar.slots) do
            local entry = entries[index] or { abilityId = 0, isUltimate = index == 6 }
            slot.entry = entry
            slot.icon:SetTexture(entry.icon or "")
            local hasAbility = entry.abilityId and entry.abilityId ~= 0 and entry.icon and entry.icon ~= ""
            slot.icon:SetHidden(not hasAbility)
            slot.target:SetHidden(not hasAbility)
            slot.marker:SetText(entry.isUltimate and "U" or tostring(index))
        end
    end

    -- Rebind the selected entry to the fresh capture. A slot can be replaced
    -- while the window is open; retaining the old table would leave the
    -- details panel editing an ability that is no longer in that slot.
    local selected = Window.selectedEntry
    if selected then
        local selectedBar = Window.bars[selected.hotbar]
        local currentEntry
        for _, slot in ipairs(selectedBar and selectedBar.slots or {}) do
            local entry = slot.entry
            if entry and entry.slotIndex == selected.slotIndex then
                currentEntry = entry
                break
            end
        end
        Window.selectedEntry = currentEntry and currentEntry.abilityId ~= 0 and currentEntry or nil
    end

    Window.RefreshSelectionVisuals()
    Window.RefreshDetails()
end

function Window.Create()
    if Window.control then
        return Window.control
    end
    local saved = SavedWindow() or {}
    local control = WM:CreateTopLevelWindow(WINDOW_NAME)
    control:SetDimensions(WIDTH, HEIGHT)
    if saved.x and saved.y then
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, saved.x, saved.y)
    else
        control:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    control:SetHidden(true)
    control:SetMovable(true)
    control:SetMouseEnabled(true)
    control:SetClampedToScreen(true)
    control:SetHandler("OnMoveStop", Window.SavePosition)
    Window.control = control

    local background = WM:CreateControl(nil, control, CT_BACKDROP)
    background:SetAnchorFill(control)
    background:SetEdgeTexture(nil, 1, 1, 1, 0)
    background:SetCenterColor(0.015, 0.012, 0.02, 0.94)

    local header = WM:CreateControl(nil, control, CT_BACKDROP)
    header:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
    header:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
    header:SetHeight(HEADER_HEIGHT)
    header:SetCenterColor(0.09, 0.05, 0.13, 0.96)
    header:SetMouseEnabled(true)
    header:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            control:StartMoving()
        end
    end)
    header:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            control:StopMovingOrResizing()
            Window.SavePosition()
        end
    end)

    local title = WM:CreateControl(nil, header, CT_LABEL)
    title:SetAnchor(LEFT, header, LEFT, 12, 0)
    title:SetFont("ZoFontGameBold")
    title:SetText("E|c" .. TITLE_COLOR .. "Z|rOCombat")
    -- Title and context sit above the drag surface. They must not consume
    -- pointer input before the header can begin moving the TopLevelWindow.
    title:SetMouseEnabled(false)

    local context = WM:CreateControl(nil, header, CT_LABEL)
    context:SetAnchor(LEFT, title, RIGHT, 16, 0)
    context:SetFont("ZoFontGameSmall")
    context:SetColor(0.75, 0.75, 0.8, 1)
    context:SetMouseEnabled(false)
    Window.contextLabel = context

    local close = WM:CreateControl(nil, header, CT_BUTTON)
    close:SetDimensions(26, 26)
    close:SetAnchor(RIGHT, header, RIGHT, -8, 0)
    close:SetFont("ZoFontGameBold")
    close:SetText("X")
    close:SetNormalFontColor(1, 1, 1, 1)
    close:SetMouseOverFontColor(1, 0.55, 0.55, 1)
    close:SetHandler("OnClicked", Window.Hide)

    local showAllConfigured = CreateControlFromVirtual(
        "EZOCombatShowAllConfigured",
        header,
        "ZO_CheckButton"
    )
    showAllConfigured:SetAnchor(RIGHT, close, LEFT, -180, 0)
    ZO_CheckButton_SetLabelText(showAllConfigured, GetString(SI_EZOCOMBAT_SHOW_ALL_CONFIGURED))
    if showAllConfigured.label then
        showAllConfigured.label:SetWidth(165)
        showAllConfigured.label:SetFont("ZoFontGameSmall")
        showAllConfigured.label:SetColor(0.9, 0.86, 0.94, 1)
    end
    ZO_CheckButton_SetCheckState(showAllConfigured, false)
    ZO_CheckButton_SetToggleFunction(showAllConfigured, function(_, checked)
        Window.SetShowAllConfigured(checked)
    end)
    Window.showAllConfiguredCheck = showAllConfigured

    local body = WM:CreateControl(nil, control, CT_CONTROL)
    body:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 16, 14)
    body:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -16, -16)
    Window.bars = {
        front = CreateBar(body, "front", 0),
        back = CreateBar(body, "back", 118),
    }
    Window.details = CreateDetails(body)
    RegisterFragment()
    Window.RefreshBars()
    return control
end

function Window.Show()
    Window.Create()
    Window.requestedVisible = true
    Window.RefreshContext()
    if ADDON.ActionBars and type(ADDON.ActionBars.Refresh) == "function" then
        ADDON.ActionBars.Refresh("window-show")
    else
        Window.RefreshBars()
    end
    Window.RefreshVisibility()
    if IsHudScene() and SCENE_MANAGER and type(SCENE_MANAGER.SetInUIMode) == "function" then
        SCENE_MANAGER:SetInUIMode(true, false)
    end
end

function Window.Hide()
    Window.SetShowAllConfigured(false)
    Window.requestedVisible = false
    Window.RefreshVisibility()
end

function Window.Toggle()
    if Window.control and not Window.control:IsHidden() then
        Window.Hide()
    else
        Window.Show()
    end
end

function Window.Init()
    Window.Create()
    if SCENE_MANAGER and type(SCENE_MANAGER.RegisterCallback) == "function" then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", Window.RefreshVisibility)
    end
end

function Window.DebugSnapshot()
    local selected = Window.selectedEntry
    local control = Window.control
    local details = Window.details
    DebugLog(string.format(
        "snapshot window=%s hidden=%s requested=%s showAllConfigured=%s selected=%s detailsHidden=%s",
        tostring(control ~= nil),
        tostring(control and control:IsHidden()),
        tostring(Window.requestedVisible),
        tostring(Window.IsShowingAllConfigured()),
        tostring(selected and selected.abilityId),
        tostring(details and details:IsHidden())
    ))
end

function EZOCombat_ToggleWindow()
    if EZOCombat.Window and type(EZOCombat.Window.Toggle) == "function" then
        EZOCombat.Window.Toggle()
    end
end
