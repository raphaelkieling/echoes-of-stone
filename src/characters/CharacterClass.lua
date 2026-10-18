local Class = require("src.core.Class")

local CharacterClass = Class:extend()

CharacterClass.id = "character"
CharacterClass.name = "Character"
CharacterClass.sprite = {x = 0, y = 0, scale = 2.25}

function CharacterClass:move(context, actor, direction, destination)
    return context:walkOrPush(actor, direction, destination, 1)
end

return CharacterClass
