local Class = require("src.core.Class")

local CharacterClass = Class:extend()

CharacterClass.id = "character"
CharacterClass.name = "Character"
CharacterClass.sprite = {x = 0, y = 0, scale = 2.25}

function CharacterClass:move(_movement, _actor, _direction, _destination)
    error(self.name .. " must implement its movement behavior")
end

function CharacterClass:playMovementEffect(effects, actor, changes)
    for _, change in ipairs(changes) do
        if change.object == actor then
            local cellSize = actor:getComponent("Transform").cellSize
            effects:dust(change.fromX, change.fromY, cellSize, {0.82, 0.66, 0.43})
            return
        end
    end
end

return CharacterClass
