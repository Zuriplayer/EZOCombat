EZOCombat = EZOCombat or {}
EZOCombat.AbilityState = EZOCombat.AbilityState or {}

local ADDON = EZOCombat
local AbilityState = ADDON.AbilityState

AbilityState.PHASE_ACTIVE_TIMED = "active_timed"
AbilityState.PHASE_ACTIVE_TOGGLED = "active_toggled"
AbilityState.PHASE_READY = "ready"
AbilityState.PHASE_INACTIVE = "inactive"
AbilityState.PHASE_UNKNOWN = "unknown"

AbilityState.SOURCE_SLOT_TIMER = "slot_timer"
AbilityState.SOURCE_TOGGLE = "toggle"
AbilityState.SOURCE_UNIT_EFFECT = "unit_effect"
AbilityState.SOURCE_ULTIMATE_RESOURCE = "ultimate_resource"
AbilityState.SOURCE_PREDICTED = "predicted"
AbilityState.SOURCE_UNKNOWN = "unknown"

AbilityState.activeEffects = AbilityState.activeEffects or {}
AbilityState.predictions = AbilityState.predictions or {}
AbilityState.effectsReadable = AbilityState.effectsReadable == true

local PROVIDERS = {
    [86156] = { source = AbilityState.SOURCE_SLOT_TIMER }, -- Arctic Blast
    [117690] = { source = AbilityState.SOURCE_SLOT_TIMER }, -- Blighted Blastbones; zero is valid inactive evidence from first load
    [92163] = { source = AbilityState.SOURCE_TOGGLE }, -- Warden bear ultimate
    [217699] = { source = AbilityState.SOURCE_TOGGLE }, -- Banner Bearer
    [86019] = { source = AbilityState.SOURCE_PREDICTED, durationMs = 6000 },
    [93778] = { source = AbilityState.SOURCE_PREDICTED, durationMs = 9000 },
}

-- ESO can expose different IDs for the same slotted ability family while a
-- chained or greyed-out state is displayed. Keep these families explicit and
-- conservative: names and icons are not reliable identity keys, and an
-- unverified grouping could merge two different skills. The first ID is the
-- stable tracker identity; the other IDs are native state/effect variants.
local ABILITY_FAMILIES = {
    { 114860, 117330, 114861 }, -- Blastbones
    { 117690, 117693, 117691 }, -- Blighted Blastbones
    { 117749, 117773, 117750 }, -- Stalking Blastbones
}
local ABILITY_FAMILY_BY_ID = {}
for _, family in ipairs(ABILITY_FAMILIES) do
    local stableId = tonumber(family[1]) or 0
    if stableId ~= 0 then
        for _, abilityId in ipairs(family) do
            ABILITY_FAMILY_BY_ID[tonumber(abilityId) or 0] = stableId
        end
    end
end

function AbilityState.NormalizeAbilityId(abilityId)
    abilityId = tonumber(abilityId) or 0
    return ABILITY_FAMILY_BY_ID[abilityId] or abilityId
end

function AbilityState.AreAbilityIdsEquivalent(firstAbilityId, secondAbilityId)
    return AbilityState.NormalizeAbilityId(firstAbilityId)
        == AbilityState.NormalizeAbilityId(secondAbilityId)
end

local function DebugLog(message)
    if ADDON.DebugLog then
        ADDON.DebugLog("[AbilityState] " .. tostring(message))
    end
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

local function GetNowSeconds()
    if type(GetFrameTimeSeconds) == "function" then
        return GetFrameTimeSeconds()
    end
    return GetNowMilliseconds() / 1000
end

local function GetCapabilities(abilityId)
    local state = ADDON.sv and ADDON.sv.abilityState
    if not state then
        return {}
    end
    state.capabilities = state.capabilities or {}
    local key = tostring(AbilityState.NormalizeAbilityId(abilityId))
    state.capabilities[key] = state.capabilities[key] or {}
    return state.capabilities[key]
end

local function MarkCapability(abilityId, capability)
    local capabilities = GetCapabilities(abilityId)
    if capabilities[capability] == true then
        return
    end
    capabilities[capability] = true
    DebugLog(string.format("learned ability=%s capability=%s", tostring(abilityId), tostring(capability)))
end

function AbilityState.RegisterProvider(abilityId, provider)
    abilityId = AbilityState.NormalizeAbilityId(abilityId)
    if abilityId == 0 or type(provider) ~= "table" or type(provider.source) ~= "string" then
        return false
    end
    PROVIDERS[abilityId] = provider
    return true
end

local function ReadSlotSample(entry)
    local sample = {
        hotbar = entry.hotbar,
        category = entry.hotbarCategory,
        slotIndex = entry.slotIndex,
        remainingMs = 0,
        durationMs = 0,
        stacks = 0,
        toggled = nil,
        cooldownRemainingMs = nil,
        cooldownDurationMs = nil,
        cooldownGlobal = nil,
    }

    if type(GetActionSlotEffectTimeRemaining) == "function" then
        local ok, value = pcall(GetActionSlotEffectTimeRemaining, entry.slotIndex, entry.hotbarCategory)
        if ok then
            sample.remainingMs = tonumber(value) or 0
            sample.timerReadable = true
        end
    end
    if type(GetActionSlotEffectDuration) == "function" then
        local ok, value = pcall(GetActionSlotEffectDuration, entry.slotIndex, entry.hotbarCategory)
        if ok then
            sample.durationMs = tonumber(value) or 0
            sample.durationReadable = true
        end
    end
    if type(GetActionSlotEffectStackCount) == "function" then
        local ok, value = pcall(GetActionSlotEffectStackCount, entry.slotIndex, entry.hotbarCategory)
        if ok then
            sample.stacks = tonumber(value) or 0
        end
    end
    if type(IsSlotToggled) == "function" then
        local ok, value = pcall(IsSlotToggled, entry.slotIndex, entry.hotbarCategory)
        if ok then
            sample.toggled = value == true
        end
    end
    if type(GetSlotCooldownInfo) == "function" then
        local ok, remaining, duration, isGlobal = pcall(GetSlotCooldownInfo, entry.slotIndex, entry.hotbarCategory)
        if ok then
            sample.cooldownRemainingMs = tonumber(remaining) or 0
            sample.cooldownDurationMs = tonumber(duration) or 0
            sample.cooldownGlobal = isGlobal == true
        end
    end
    return sample
end

local function IsToggleAbility(abilityId)
    if type(IsAbilityDurationToggled) ~= "function" then
        return nil
    end
    local ok, value = pcall(IsAbilityDurationToggled, abilityId, "player")
    if not ok then
        return nil
    end
    return value
end

local function IsEffectCurrent(effect)
    if not effect then
        return false
    end
    local endTime = tonumber(effect.endTime) or 0
    return endTime == 0 or endTime > GetNowSeconds()
end

local function FindActiveEffect(abilityId, provider)
    local acceptedIds = { [abilityId] = true }
    for _, effectId in ipairs(provider and provider.effectIds or {}) do
        acceptedIds[AbilityState.NormalizeAbilityId(effectId)] = true
    end

    for _, effect in pairs(AbilityState.activeEffects) do
        if acceptedIds[AbilityState.NormalizeAbilityId(effect.abilityId)]
            and effect.castByPlayer ~= false
            and IsEffectCurrent(effect) then
            return effect
        end
    end
    return nil
end

local function GetPrediction(abilityId)
    abilityId = AbilityState.NormalizeAbilityId(abilityId)
    local provider = PROVIDERS[abilityId]
    if not provider or provider.source ~= AbilityState.SOURCE_PREDICTED then
        return nil
    end

    local expiresAt = tonumber(AbilityState.predictions[abilityId])
    if not expiresAt then
        return nil
    end

    local remaining = expiresAt - GetNowMilliseconds()
    if remaining > 0 then
        return true, remaining, provider.durationMs
    end
    AbilityState.predictions[abilityId] = nil
    return false, 0, provider.durationMs
end

local function ReadUltimate(entry)
    if type(GetUnitPower) ~= "function"
        or type(GetSlotAbilityCost) ~= "function"
        or COMBAT_MECHANIC_FLAGS_ULTIMATE == nil then
        return nil
    end

    local powerOk, current = pcall(GetUnitPower, "player", COMBAT_MECHANIC_FLAGS_ULTIMATE)
    if not powerOk then
        return nil
    end
    local costOk, cost = pcall(
        GetSlotAbilityCost,
        entry.slotIndex,
        COMBAT_MECHANIC_FLAGS_ULTIMATE,
        entry.hotbarCategory
    )
    cost = tonumber(cost) or 0
    if not costOk or cost <= 0 then
        costOk, cost = pcall(GetSlotAbilityCost, entry.slotIndex, COMBAT_MECHANIC_FLAGS_ULTIMATE)
        cost = tonumber(cost) or 0
    end
    if not costOk or cost <= 0 then
        return nil
    end
    current = tonumber(current) or 0
    return current >= cost, current, cost
end

local function NewState(abilityId, entries)
    return {
        abilityId = abilityId,
        slotted = #entries > 0,
        active = nil,
        timing = false,
        ready = nil,
        remainingMs = 0,
        durationMs = 0,
        stacks = 0,
        phase = AbilityState.PHASE_UNKNOWN,
        source = AbilityState.SOURCE_UNKNOWN,
        confidence = "none",
        samples = {},
    }
end

function AbilityState.Resolve(abilityId, entries)
    abilityId = AbilityState.NormalizeAbilityId(abilityId)
    entries = entries or {}
    local state = NewState(abilityId, entries)
    if abilityId == 0 or #entries == 0 then
        return state
    end

    local isUltimate = false
    for _, entry in ipairs(entries) do
        state.samples[#state.samples + 1] = ReadSlotSample(entry)
        isUltimate = isUltimate or entry.isUltimate == true
    end

    local provider = PROVIDERS[abilityId]
    local capabilities = GetCapabilities(abilityId)
    local hasToggleSample = false
    for _, sample in ipairs(state.samples) do
        if sample.toggled ~= nil then
            hasToggleSample = true
            if sample.toggled then
                MarkCapability(abilityId, "toggle")
                state.active = true
                state.phase = AbilityState.PHASE_ACTIVE_TOGGLED
                state.source = AbilityState.SOURCE_TOGGLE
                state.confidence = "observed"
                return state
            end
        end
    end
    local isToggleProvider = IsToggleAbility(abilityId) == true
        or (provider and provider.source == AbilityState.SOURCE_TOGGLE)
        or capabilities.toggle == true
    if isToggleProvider and hasToggleSample then
        state.active = false
        state.phase = AbilityState.PHASE_INACTIVE
        state.source = AbilityState.SOURCE_TOGGLE
        state.confidence = "observed"
        return state
    end

    -- Explicit predicted providers cover abilities whose native slot signal
    -- is incomplete or represents a different cycle. They must win while a
    -- cast prediction exists, and when it expires, before the partial native
    -- timer can classify the ability as active again.
    local predicted, predictedRemaining, predictedDuration = GetPrediction(abilityId)
    if predicted == true then
        state.active = true
        state.timing = true
        state.remainingMs = predictedRemaining
        state.durationMs = predictedDuration
        state.phase = AbilityState.PHASE_ACTIVE_TIMED
        state.source = AbilityState.SOURCE_PREDICTED
        state.confidence = "predicted"
        return state
    end
    if predicted == false then
        state.active = false
        state.phase = AbilityState.PHASE_INACTIVE
        state.source = AbilityState.SOURCE_PREDICTED
        state.confidence = "predicted"
        return state
    end

    if isUltimate then
        local hasResourceSample = false
        for _, entry in ipairs(entries) do
            local ready, current, cost = ReadUltimate(entry)
            if ready ~= nil then
                hasResourceSample = true
                state.currentResource = current
                state.requiredResource = cost
                if ready then
                    state.active = true
                    state.ready = true
                    state.phase = AbilityState.PHASE_READY
                    state.source = AbilityState.SOURCE_ULTIMATE_RESOURCE
                    state.confidence = "observed"
                    return state
                end
            end
        end
        if hasResourceSample then
            state.active = false
            state.ready = false
            state.phase = AbilityState.PHASE_INACTIVE
            state.source = AbilityState.SOURCE_ULTIMATE_RESOURCE
            state.confidence = "observed"
        end
        return state
    end

    local hasTimerReader = false
    for _, sample in ipairs(state.samples) do
        hasTimerReader = hasTimerReader or sample.timerReadable == true
        if sample.remainingMs > 0 then
            MarkCapability(abilityId, "slotTimer")
            state.active = true
            state.timing = true
            state.remainingMs = sample.remainingMs
            state.durationMs = sample.durationMs > 0 and sample.durationMs or sample.remainingMs
            state.stacks = sample.stacks
            state.phase = AbilityState.PHASE_ACTIVE_TIMED
            state.source = AbilityState.SOURCE_SLOT_TIMER
            state.confidence = "observed"
            return state
        end
        if sample.durationMs > 0 then
            MarkCapability(abilityId, "slotTimer")
        end
    end

    local effect = FindActiveEffect(abilityId, provider)
    if effect then
        MarkCapability(abilityId, "unitEffect")
        state.active = true
        state.timing = (tonumber(effect.endTime) or 0) > 0
        state.remainingMs = state.timing and math.max(0, (effect.endTime - GetNowSeconds()) * 1000) or 0
        state.durationMs = math.max(0, ((tonumber(effect.endTime) or 0) - (tonumber(effect.beginTime) or 0)) * 1000)
        state.stacks = tonumber(effect.stackCount) or 0
        state.phase = state.timing and AbilityState.PHASE_ACTIVE_TIMED or AbilityState.PHASE_ACTIVE_TOGGLED
        state.source = AbilityState.SOURCE_UNIT_EFFECT
        state.confidence = "observed"
        state.effectAbilityId = effect.abilityId
        return state
    end

    if hasTimerReader
        and (capabilities.slotTimer == true or (provider and provider.source == AbilityState.SOURCE_SLOT_TIMER)) then
        state.active = false
        state.phase = AbilityState.PHASE_INACTIVE
        state.source = AbilityState.SOURCE_SLOT_TIMER
        state.confidence = "observed"
    elseif AbilityState.effectsReadable
        and (capabilities.unitEffect == true or (provider and provider.source == AbilityState.SOURCE_UNIT_EFFECT)) then
        state.active = false
        state.phase = AbilityState.PHASE_INACTIVE
        state.source = AbilityState.SOURCE_UNIT_EFFECT
        state.confidence = "observed"
    end
    return state
end

function AbilityState.StartPrediction(abilityId)
    abilityId = AbilityState.NormalizeAbilityId(abilityId)
    local provider = PROVIDERS[abilityId]
    if not provider or provider.source ~= AbilityState.SOURCE_PREDICTED then
        return false
    end

    local now = GetNowMilliseconds()
    local expiresAt = tonumber(AbilityState.predictions[abilityId]) or 0
    if expiresAt <= now then
        AbilityState.predictions[abilityId] = now + provider.durationMs
    end
    DebugLog(string.format(
        "prediction start ability=%s durationMs=%s",
        tostring(abilityId),
        tostring(provider.durationMs)
    ))
    return true
end

function AbilityState.ExpirePredictions()
    local now = GetNowMilliseconds()
    local changed = false
    for abilityId, expiresAt in pairs(AbilityState.predictions) do
        if (tonumber(expiresAt) or 0) <= now then
            AbilityState.predictions[abilityId] = nil
            changed = true
        end
    end
    return changed
end

function AbilityState.HandleEffectChanged(changeType, effectSlot, beginTime, endTime, stackCount, abilityId, sourceType)
    AbilityState.effectsReadable = true
    if changeType == EFFECT_RESULT_FADED then
        AbilityState.activeEffects[effectSlot] = nil
        return
    end
    abilityId = tonumber(abilityId) or 0
    if abilityId == 0 then
        return
    end
    local castByPlayer
    if COMBAT_UNIT_TYPE_PLAYER ~= nil then
        castByPlayer = sourceType == COMBAT_UNIT_TYPE_PLAYER
    end
    AbilityState.activeEffects[effectSlot] = {
        abilityId = abilityId,
        beginTime = tonumber(beginTime) or 0,
        endTime = tonumber(endTime) or 0,
        stackCount = tonumber(stackCount) or 0,
        castByPlayer = castByPlayer,
    }
end

function AbilityState.RebuildPlayerEffects()
    AbilityState.activeEffects = {}
    AbilityState.effectsReadable = false
    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then
        return false
    end

    local countOk, count = pcall(GetNumBuffs, "player")
    if not countOk then
        return false
    end
    for index = 1, tonumber(count) or 0 do
        local ok, _, beginTime, endTime, effectSlot, stackCount, _, _, _, _, _, abilityId, _, castByPlayer = pcall(
            GetUnitBuffInfo,
            "player",
            index
        )
        abilityId = tonumber(abilityId) or 0
        if ok and abilityId ~= 0 then
            AbilityState.activeEffects[effectSlot or index] = {
                abilityId = abilityId,
                beginTime = tonumber(beginTime) or 0,
                endTime = tonumber(endTime) or 0,
                stackCount = tonumber(stackCount) or 0,
                castByPlayer = castByPlayer == true,
            }
        end
    end
    AbilityState.effectsReadable = true
    return true
end

function AbilityState.Describe(state)
    local parts = {
        "phase=" .. tostring(state.phase),
        "active=" .. tostring(state.active),
        "source=" .. tostring(state.source),
        "confidence=" .. tostring(state.confidence),
        "timing=" .. tostring(state.timing),
        "remainingMs=" .. tostring(math.floor(tonumber(state.remainingMs) or 0)),
        "durationMs=" .. tostring(math.floor(tonumber(state.durationMs) or 0)),
        "stacks=" .. tostring(state.stacks),
    }
    if state.ready ~= nil then
        parts[#parts + 1] = "ready=" .. tostring(state.ready)
        parts[#parts + 1] = "resource=" .. tostring(state.currentResource)
        parts[#parts + 1] = "cost=" .. tostring(state.requiredResource)
    end
    for _, sample in ipairs(state.samples or {}) do
        parts[#parts + 1] = string.format(
            "%s:slot=%s,bar=%s,remaining=%s,duration=%s,stacks=%s,toggled=%s,cooldown=%s/%s,global=%s",
            tostring(sample.hotbar),
            tostring(sample.slotIndex),
            tostring(sample.category),
            tostring(sample.remainingMs),
            tostring(sample.durationMs),
            tostring(sample.stacks),
            tostring(sample.toggled),
            tostring(sample.cooldownRemainingMs),
            tostring(sample.cooldownDurationMs),
            tostring(sample.cooldownGlobal)
        )
    end
    return table.concat(parts, "; ")
end

function AbilityState.DebugSnapshot()
    local effects = {}
    for slot, effect in pairs(AbilityState.activeEffects) do
        if IsEffectCurrent(effect) then
            effects[#effects + 1] = string.format(
                "slot=%s ability=%s begin=%.3f end=%.3f stacks=%s player=%s",
                tostring(slot),
                tostring(effect.abilityId),
                tonumber(effect.beginTime) or 0,
                tonumber(effect.endTime) or 0,
                tostring(effect.stackCount),
                tostring(effect.castByPlayer)
            )
        end
    end
    table.sort(effects)
    DebugLog("player effects count=" .. tostring(#effects))
    for _, effect in ipairs(effects) do
        DebugLog("player effect " .. effect)
    end
end

function AbilityState.Init()
    AbilityState.RebuildPlayerEffects()
end
