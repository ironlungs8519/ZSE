-- The alien skins have a bald head: no hair, beard or stubble. Does nothing if this table differs in some build.
require "Definitions/HairOutfitDefinitions"

local defs = HairOutfitDefinitions and HairOutfitDefinitions.haircutOutfitDefinition
if type(defs) == "table" then
    local function has(outfit)
        for _, e in ipairs(defs) do
            if e.outfit == outfit then return true end
        end
        return false
    end
    if not has("AAGrey01_Costume") then
        table.insert(defs, { outfit = "AAGrey01_Costume", haircut = "None:100", beard = "None:100", stubble = "None:100" })
    end
    if not has("AASkinnyBob01_Costume") then
        table.insert(defs, { outfit = "AASkinnyBob01_Costume", haircut = "None:100", beard = "None:100", stubble = "None:100" })
    end
end
