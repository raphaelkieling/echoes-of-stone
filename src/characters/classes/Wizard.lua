local CharacterClass = require("src.characters.CharacterClass")

local Wizard = CharacterClass:extend()
Wizard.id = "wizard"
Wizard.name = "Wizard"
Wizard.sprite = {x = 1, y = 4, scale = 2.25}

function Wizard:move(context, actor, direction, destination)
    return context:swapWithFirstInRay(actor, direction, destination)
end

return Wizard
