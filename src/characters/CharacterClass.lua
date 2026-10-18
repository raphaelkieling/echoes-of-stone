local Class = require("src.core.Class")

local CharacterClass = Class:extend()

CharacterClass.id = "character"
CharacterClass.name = "Character"
CharacterClass.sprite = {x = 0, y = 0, scale = 2.25}

function CharacterClass:move(_movement, _actor, _direction, _destination)
    error(self.name .. " must implement its movement behavior")
end

return CharacterClass
