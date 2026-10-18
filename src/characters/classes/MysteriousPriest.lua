local CharacterClass = require("src.characters.CharacterClass")

local MysteriousPriest = CharacterClass:extend()
MysteriousPriest.id = "mysterious_priest"
MysteriousPriest.name = "Mysterious Priest"
MysteriousPriest.sprite = {x = 6, y = 2, scale = 2.25}

function MysteriousPriest:move(context, actor, direction, destination)
    return context:moveAuraAndEnter(actor, direction, destination, 1)
end

return MysteriousPriest
