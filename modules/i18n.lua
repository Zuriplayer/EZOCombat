EZOCombat_Lang = EZOCombat_Lang or {}

local ZO_CreateStringId = ZO_CreateStringId
local pairs = pairs

function EZOCombat_Lang.Apply(language)
    local strings = EZOCombat_Lang[language] or EZOCombat_Lang.en
    if strings == nil then
        return
    end

    for stringId, value in pairs(strings) do
        ZO_CreateStringId(stringId, value)
    end
end
