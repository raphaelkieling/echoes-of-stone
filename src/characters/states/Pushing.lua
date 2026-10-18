local Class = require("src.core.Class")

local Pushing = Class:extend()

function Pushing:init(owner, stateMachine)
    self.owner = owner
    self.stateMachine = stateMachine
end

function Pushing:update(_dt)
    if not self.owner:getComponent("Transform"):isMoving() then
        self.stateMachine:change("idle")
    end
end

return Pushing
