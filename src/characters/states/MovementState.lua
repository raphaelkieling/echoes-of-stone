local Class = require("src.core.Class")

local MovementState = Class:extend()

function MovementState:init(owner, stateMachine)
    self.owner = owner
    self.stateMachine = stateMachine
end

function MovementState:onMovement(data)
    if not data or not data.effects then return end

    local characterClass = self.owner:getComponent("CharacterClass")
    if characterClass then
        characterClass:playMovementEffect(
            data.effects,
            self.owner,
            data.changes,
            data.direction
        )
    end
end

function MovementState:update(_dt)
    if not self.owner:getComponent("Transform"):isMoving() then
        self.stateMachine:change("idle")
    end
end

return MovementState
