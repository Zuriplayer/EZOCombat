EZOCombat = EZOCombat or {}
EZOCombat.Layout = EZOCombat.Layout or {}

local ADDON = EZOCombat
local Layout = ADDON.Layout

Layout.MODE_MANUAL = "manual"
Layout.MODE_VERTICAL = "vertical"
Layout.MODE_HORIZONTAL = "horizontal"
Layout.ALIGN_START = "start"
Layout.ALIGN_CENTER = "center"
Layout.ALIGN_END = "end"
Layout.DEFAULT_ICON_SPACING = 8
Layout.DEFAULT_PRIORITY_SPACING = 18
Layout.MIN_SPACING = 0
Layout.MAX_ICON_SPACING = 40
Layout.MAX_PRIORITY_SPACING = 80

local DEFAULT_ANCHOR_X = 0.60
local DEFAULT_ANCHOR_Y = 0.42
local SCREEN_MARGIN = 20
local layoutSurfaceEditMode = false

local function DebugLog(message)
    if ADDON.DebugLog then
        ADDON.DebugLog("[Layout] " .. tostring(message))
    end
end

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function NormalizeSpacing(value, defaultValue, maximum)
    value = tonumber(value) or defaultValue
    return Clamp(math.floor(value + 0.5), Layout.MIN_SPACING, maximum)
end

local function GetSettings()
    local sv = ADDON.sv
    if not sv then
        return nil
    end
    sv.layout = type(sv.layout) == "table" and sv.layout or {}
    sv.layout.anchors = type(sv.layout.anchors) == "table" and sv.layout.anchors or {}
    return sv.layout
end

local function GetAnchorStore()
    local profile = ADDON.Priority
        and type(ADDON.Priority.GetProfile) == "function"
        and ADDON.Priority.GetProfile()
    if profile then
        profile.layoutAnchors = type(profile.layoutAnchors) == "table" and profile.layoutAnchors or {}
        return profile.layoutAnchors
    end
    local settings = GetSettings()
    return settings and settings.anchors or nil
end

local function IsKnownMode(mode)
    return mode == Layout.MODE_MANUAL
        or mode == Layout.MODE_VERTICAL
        or mode == Layout.MODE_HORIZONTAL
end

local function IsKnownAlignment(alignment)
    return alignment == Layout.ALIGN_START
        or alignment == Layout.ALIGN_CENTER
        or alignment == Layout.ALIGN_END
end

local function AreEquivalent(leftAbilityId, rightAbilityId)
    if leftAbilityId == rightAbilityId then
        return true
    end
    return ADDON.AbilityState
        and type(ADDON.AbilityState.AreAbilityIdsEquivalent) == "function"
        and ADDON.AbilityState.AreAbilityIdsEquivalent(leftAbilityId, rightAbilityId)
        or false
end

local function FindTrackerForAbility(trackers, abilityId)
    for _, tracker in ipairs(trackers) do
        if AreEquivalent(tracker.abilityId, abilityId) then
            return tracker
        end
    end
    return nil
end

local function GetConfiguredTrackers()
    local configured = {}
    if not (ADDON.Priority and type(ADDON.Priority.ListTrackers) == "function") then
        return configured
    end
    for _, tracker in ipairs(ADDON.Priority.ListTrackers()) do
        if tracker.enabled == true
            and ADDON.ActionBars
            and type(ADDON.ActionBars.IsAbilitySlotted) == "function"
            and ADDON.ActionBars.IsAbilitySlotted(tracker.abilityId) then
            configured[#configured + 1] = tracker
        end
    end
    return configured
end

local function GetOrderedTrackers()
    local configured = GetConfiguredTrackers()
    local ordered = {}
    local seen = {}
    local bars = ADDON.ActionBars and ADDON.ActionBars.bars or {}

    for _, barKey in ipairs({ "front", "back" }) do
        for _, entry in ipairs(bars[barKey] or {}) do
            local tracker = FindTrackerForAbility(configured, entry.abilityId)
            if tracker and not seen[tracker.id] then
                seen[tracker.id] = true
                ordered[#ordered + 1] = tracker
            end
        end
    end

    local remaining = {}
    for _, tracker in ipairs(configured) do
        if not seen[tracker.id] then
            remaining[#remaining + 1] = tracker
        end
    end
    table.sort(remaining, function(left, right)
        local leftAbilityId = tonumber(left.abilityId) or 0
        local rightAbilityId = tonumber(right.abilityId) or 0
        if leftAbilityId == rightAbilityId then
            return tostring(left.id) < tostring(right.id)
        end
        return leftAbilityId < rightAbilityId
    end)
    for _, tracker in ipairs(remaining) do
        ordered[#ordered + 1] = tracker
    end
    return ordered
end

local function BuildGroups()
    local buckets = {}
    local priorities = { ADDON.Priority.ALWAYS }
    for priority = ADDON.Priority.MIN, ADDON.Priority.MAX do
        priorities[#priorities + 1] = priority
    end
    for _, priority in ipairs(priorities) do
        buckets[priority] = {}
    end
    for _, tracker in ipairs(GetOrderedTrackers()) do
        local bucket = buckets[tracker.priority]
        if bucket then
            bucket[#bucket + 1] = tracker
        end
    end

    local groups = {}
    for _, priority in ipairs(priorities) do
        if #buckets[priority] > 0 then
            groups[#groups + 1] = {
                priority = priority,
                trackers = buckets[priority],
            }
        end
    end
    return groups
end

local function AlignmentOffset(containerExtent, groupExtent, alignment)
    if alignment == Layout.ALIGN_CENTER then
        return (containerExtent - groupExtent) * 0.5
    end
    if alignment == Layout.ALIGN_END then
        return containerExtent - groupExtent
    end
    return 0
end

local function CalculateVertical(groups, iconSize, cellWidth, cellHeight, iconSpacing, prioritySpacing, availableWidth)
    local maxColumns = math.max(1, math.floor((availableWidth + iconSpacing) / (cellWidth + iconSpacing)))
    local width = 0
    local height = 0

    for _, group in ipairs(groups) do
        group.columns = math.min(#group.trackers, maxColumns)
        group.rows = math.ceil(#group.trackers / maxColumns)
        group.width = group.columns * cellWidth + math.max(0, group.columns - 1) * iconSpacing
        group.height = group.rows * cellHeight + math.max(0, group.rows - 1) * iconSpacing
        width = math.max(width, group.width)
        height = height + group.height
    end
    height = height + math.max(0, #groups - 1) * prioritySpacing

    local positions = {}
    local groupY = 0
    local alignment = Layout.GetAlignment()
    for _, group in ipairs(groups) do
        local groupX = AlignmentOffset(width, group.width, alignment)
        for index, tracker in ipairs(group.trackers) do
            local column = (index - 1) % maxColumns
            local row = math.floor((index - 1) / maxColumns)
            positions[tracker.id] = {
                x = groupX + column * (cellWidth + iconSpacing) + (cellWidth - iconSize) * 0.5,
                y = groupY + row * (cellHeight + iconSpacing),
            }
        end
        groupY = groupY + group.height + prioritySpacing
    end
    return width, height, positions
end

local function CalculateHorizontal(groups, iconSize, cellWidth, cellHeight, iconSpacing, prioritySpacing, availableHeight)
    local maxRows = math.max(1, math.floor((availableHeight + iconSpacing) / (cellHeight + iconSpacing)))
    local width = 0
    local height = 0

    for _, group in ipairs(groups) do
        group.rows = math.min(#group.trackers, maxRows)
        group.columns = math.ceil(#group.trackers / maxRows)
        group.width = group.columns * cellWidth + math.max(0, group.columns - 1) * iconSpacing
        group.height = group.rows * cellHeight + math.max(0, group.rows - 1) * iconSpacing
        width = width + group.width
        height = math.max(height, group.height)
    end
    width = width + math.max(0, #groups - 1) * prioritySpacing

    local positions = {}
    local groupX = 0
    local alignment = Layout.GetAlignment()
    for _, group in ipairs(groups) do
        local groupY = AlignmentOffset(height, group.height, alignment)
        for index, tracker in ipairs(group.trackers) do
            local column = math.floor((index - 1) / maxRows)
            local row = (index - 1) % maxRows
            positions[tracker.id] = {
                x = groupX + column * (cellWidth + iconSpacing) + (cellWidth - iconSize) * 0.5,
                y = groupY + row * (cellHeight + iconSpacing),
            }
        end
        groupX = groupX + group.width + prioritySpacing
    end
    return width, height, positions
end

function Layout.GetMode()
    local settings = GetSettings()
    local mode = settings and settings.mode
    return IsKnownMode(mode) and mode or Layout.MODE_MANUAL
end

function Layout.SetMode(mode)
    local settings = GetSettings()
    if not settings or not IsKnownMode(mode) then
        return false
    end
    settings.mode = mode
    if mode == Layout.MODE_MANUAL then
        layoutSurfaceEditMode = false
    end
    DebugLog("mode=" .. tostring(mode))
    if ADDON.Overlays then
        ADDON.Overlays.Refresh()
    end
    return true
end

function Layout.IsAutomatic()
    return Layout.GetMode() ~= Layout.MODE_MANUAL
end

function Layout.GetAlignment()
    local settings = GetSettings()
    local alignment = settings and settings.alignment
    return IsKnownAlignment(alignment) and alignment or Layout.ALIGN_START
end

function Layout.SetAlignment(alignment)
    local settings = GetSettings()
    if not settings or not IsKnownAlignment(alignment) then
        return false
    end
    settings.alignment = alignment
    if ADDON.Overlays then
        ADDON.Overlays.Refresh()
    end
    return true
end

function Layout.GetIconSpacing()
    local settings = GetSettings()
    return NormalizeSpacing(
        settings and settings.iconSpacing,
        Layout.DEFAULT_ICON_SPACING,
        Layout.MAX_ICON_SPACING
    )
end

function Layout.SetIconSpacing(value)
    local settings = GetSettings()
    if not settings then
        return false
    end
    settings.iconSpacing = NormalizeSpacing(value, Layout.DEFAULT_ICON_SPACING, Layout.MAX_ICON_SPACING)
    if ADDON.Overlays then
        ADDON.Overlays.Refresh()
    end
    return true
end

function Layout.GetPrioritySpacing()
    local settings = GetSettings()
    return NormalizeSpacing(
        settings and settings.prioritySpacing,
        Layout.DEFAULT_PRIORITY_SPACING,
        Layout.MAX_PRIORITY_SPACING
    )
end

function Layout.SetPrioritySpacing(value)
    local settings = GetSettings()
    if not settings then
        return false
    end
    settings.prioritySpacing = NormalizeSpacing(value, Layout.DEFAULT_PRIORITY_SPACING, Layout.MAX_PRIORITY_SPACING)
    if ADDON.Overlays then
        ADDON.Overlays.Refresh()
    end
    return true
end

function Layout.Calculate(iconSize, keybindHeight)
    iconSize = math.max(1, tonumber(iconSize) or 1)
    keybindHeight = math.max(0, tonumber(keybindHeight) or 0)
    local rootWidth = GuiRoot and GuiRoot:GetWidth() or 1920
    local rootHeight = GuiRoot and GuiRoot:GetHeight() or 1080
    local availableWidth = math.max(1, rootWidth - SCREEN_MARGIN * 2)
    local availableHeight = math.max(1, rootHeight - SCREEN_MARGIN * 2)
    local groups = BuildGroups()
    local cellWidth = math.max(80, iconSize)
    local cellHeight = iconSize + keybindHeight
    local iconSpacing = Layout.GetIconSpacing()
    local prioritySpacing = Layout.GetPrioritySpacing()
    local width, height, positions

    if Layout.GetMode() == Layout.MODE_HORIZONTAL then
        width, height, positions = CalculateHorizontal(
            groups,
            iconSize,
            cellWidth,
            cellHeight,
            iconSpacing,
            prioritySpacing,
            availableHeight
        )
    else
        width, height, positions = CalculateVertical(
            groups,
            iconSize,
            cellWidth,
            cellHeight,
            iconSpacing,
            prioritySpacing,
            availableWidth
        )
    end

    return {
        width = math.max(1, width),
        height = math.max(1, height),
        positions = positions,
        groups = groups,
    }
end

local function GetManualAnchor()
    local iconSize = ADDON.Overlays and ADDON.Overlays.GetIconSize and ADDON.Overlays.GetIconSize() or 54
    local minX
    local minY
    local maxX
    local maxY
    for _, tracker in ipairs(GetConfiguredTrackers()) do
        local x = tonumber(tracker.x)
        local y = tonumber(tracker.y)
        if x and y then
            minX = minX and math.min(minX, x) or x
            minY = minY and math.min(minY, y) or y
            maxX = maxX and math.max(maxX, x + iconSize) or x + iconSize
            maxY = maxY and math.max(maxY, y + iconSize + 20) or y + iconSize + 20
        end
    end

    local rootWidth = GuiRoot and GuiRoot:GetWidth() or 1920
    local rootHeight = GuiRoot and GuiRoot:GetHeight() or 1080
    if minX and rootWidth > 0 and rootHeight > 0 then
        return Clamp((minX + maxX) * 0.5 / rootWidth, 0, 1),
            Clamp((minY + maxY) * 0.5 / rootHeight, 0, 1)
    end
    return DEFAULT_ANCHOR_X, DEFAULT_ANCHOR_Y
end

function Layout.GetAnchor(mode)
    local anchors = GetAnchorStore()
    mode = IsKnownMode(mode) and mode or Layout.GetMode()
    if not anchors or mode == Layout.MODE_MANUAL then
        return DEFAULT_ANCHOR_X, DEFAULT_ANCHOR_Y
    end
    local anchor = anchors[mode]
    if type(anchor) ~= "table" or tonumber(anchor.x) == nil or tonumber(anchor.y) == nil then
        local x, y = GetManualAnchor()
        anchor = { x = x, y = y }
        anchors[mode] = anchor
    end
    return Clamp(tonumber(anchor.x), 0, 1), Clamp(tonumber(anchor.y), 0, 1)
end

function Layout.SetAnchorFromPixels(mode, centerX, centerY)
    local anchors = GetAnchorStore()
    local rootWidth = GuiRoot and GuiRoot:GetWidth() or 0
    local rootHeight = GuiRoot and GuiRoot:GetHeight() or 0
    if not anchors or mode == Layout.MODE_MANUAL or rootWidth <= 0 or rootHeight <= 0 then
        return false
    end
    anchors[mode] = {
        x = Clamp((tonumber(centerX) or 0) / rootWidth, 0, 1),
        y = Clamp((tonumber(centerY) or 0) / rootHeight, 0, 1),
    }
    DebugLog(string.format(
        "anchor mode=%s x=%.4f y=%.4f",
        tostring(mode),
        anchors[mode].x,
        anchors[mode].y
    ))
    return true
end

function Layout.ResetAnchor()
    local anchors = GetAnchorStore()
    local mode = Layout.GetMode()
    if not anchors or mode == Layout.MODE_MANUAL then
        return false
    end
    anchors[mode] = nil
    if ADDON.Overlays then
        ADDON.Overlays.Refresh()
    end
    return true
end

function Layout.IsEditMode()
    return layoutSurfaceEditMode == true
end

function Layout.SetEditMode(enabled)
    enabled = enabled == true
    if enabled and not Layout.IsAutomatic() then
        return false
    end
    layoutSurfaceEditMode = enabled
    if ADDON.Overlays then
        ADDON.Overlays.Refresh()
    end
    return Layout.IsEditMode() == enabled
end

function Layout.DebugSnapshot()
    local result = Layout.Calculate(
        ADDON.Overlays and ADDON.Overlays.GetIconSize and ADDON.Overlays.GetIconSize() or 54,
        20
    )
    local x, y = Layout.GetAnchor(Layout.GetMode())
    local groups = {}
    for _, group in ipairs(result.groups) do
        local label = group.priority == ADDON.Priority.ALWAYS and "always" or "P" .. tostring(group.priority)
        groups[#groups + 1] = label .. "=" .. tostring(#group.trackers)
    end
    DebugLog(string.format(
        "mode=%s alignment=%s spacing=%s prioritySpacing=%s anchor=%.4f,%.4f size=%.0fx%.0f groups=%s editMode=%s",
        tostring(Layout.GetMode()),
        tostring(Layout.GetAlignment()),
        tostring(Layout.GetIconSpacing()),
        tostring(Layout.GetPrioritySpacing()),
        x,
        y,
        result.width,
        result.height,
        #groups > 0 and table.concat(groups, ",") or "none",
        tostring(Layout.IsEditMode())
    ))
end

function Layout.Init()
    if EVENT_MANAGER and EVENT_SCREEN_RESIZED then
        EVENT_MANAGER:RegisterForEvent(ADDON.name .. "LayoutScreen", EVENT_SCREEN_RESIZED, function()
            if ADDON.Overlays then
                ADDON.Overlays.Refresh()
            end
        end)
    end
end
