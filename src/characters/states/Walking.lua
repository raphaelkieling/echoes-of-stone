local Class = require("src.core.Class")

local Walking = Class:extend()

function Walking:init(owner, stateMachine)
    self.owner = owner
    self.stateMachine = stateMachine
end

function Walking:update(_dt)
    if not self.owner:getComponent("Transform"):isMoving() then
        self.stateMachine:change("idle")
    end
end

return Walking
