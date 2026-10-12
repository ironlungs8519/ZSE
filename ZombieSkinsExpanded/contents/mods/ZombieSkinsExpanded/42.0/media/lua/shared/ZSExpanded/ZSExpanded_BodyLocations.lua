require "NPCs/BodyLocations"

local ok, err = pcall(function()
    local group = BodyLocations.getGroup("Human")
    local suit = ItemBodyLocation.FULL_SUIT
    for _, location in ipairs({ ItemBodyLocation.BANDAGE, ItemBodyLocation.WOUND, ItemBodyLocation.ZED_DMG }) do
        group:setHideModel(suit, location)
    end
end)
if not ok then
    print("[ZSExpanded] could not hide bandage/wound models under FullSuit: " .. tostring(err))
end
