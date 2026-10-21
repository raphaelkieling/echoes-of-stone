local Component = require("src.core.Component")

local CharacterClass = Component:extend()
CharacterClass.componentName = "CharacterClass"

CharacterClass.id = "character"
CharacterClass.name = "Character"
CharacterClass.sprite = {x = 0, y = 0, scale = 2.25}

function CharacterClass:move(_movement, _actor, _direction, _destination)
    error(self.name .. " must implement its movement behavior")
end

function CharacterClass:canEnterBlockedTile(_movement, _destination)
	return false
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

function CharacterClass:init()
	Component.init(self)
end

function CharacterClass:getId()
	return self.id
end

return CharacterClass
