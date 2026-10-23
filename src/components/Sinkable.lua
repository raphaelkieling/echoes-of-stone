local Component = require("src.core.Component")

-- Marks an interactive object that disappears when pushed into a passthrough cell.
local Sinkable = Component:extend()
Sinkable.componentName = "Sinkable"

function Sinkable:init()
	Component.init(self)
	self.state = "active"
end

function Sinkable:setState(state)
	assert(state == "active" or state == "lost", "Sinkable state must be active or lost")
	if self.state == state then return false end
	self.state = state
	if self.owner then self.owner.active = state == "active" end
	return true
end

function Sinkable:onAttach(owner)
	owner.active = self.state == "active"
end

return Sinkable
