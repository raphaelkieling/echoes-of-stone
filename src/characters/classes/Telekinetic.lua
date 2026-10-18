local CharacterClass = require("src.characters.CharacterClass")

local Telekinetic = CharacterClass:extend()
Telekinetic.id = "telekinetic"
Telekinetic.name = "Telekinetic"
Telekinetic.sprite = {x = 2, y = 0, scale = 2.25}

function Telekinetic:move(context, actor, direction, destination)
    return context:pushFirstInRay(actor, direction, destination)
end

return Telekinetic
