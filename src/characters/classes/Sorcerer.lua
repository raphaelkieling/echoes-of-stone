local CharacterClass = require("src.characters.CharacterClass")

local Sorcerer = CharacterClass:extend()
Sorcerer.id = "sorcerer"
Sorcerer.name = "Sorcerer"
Sorcerer.sprite = {x = 3, y = 4, scale = 2.25}

function Sorcerer:move(context, actor, direction, destination)
    return context:pullFirstInRay(actor, direction, destination)
end

return Sorcerer
