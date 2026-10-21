local Component = require("src.core.Component")

-- Marks an object as burnable and delegates the result to its own behavior.
local Flameable = Component:extend()
Flameable.componentName = "Flameable"

function Flameable:init(stateComponent, burnedState)
	Component.init(self)
	self.stateComponent = assert(stateComponent, "Flameable needs a state component name")
	self.burnedState = assert(burnedState, "Flameable needs a burned state")
end

function Flameable:burn(source)
	local component = self.owner:getComponent(self.stateComponent)
	if not component or component.state == self.burnedState or not component.setState then
		return nil
	end
	local previousState = component.state
	if component:setState(self.burnedState) then
		return component, previousState
	end
end

return Flameable
