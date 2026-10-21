local Component = require("src.core.Component")

-- Exposes a state-gated fire radius so objects can react without knowing
-- which kind of object produced the flame.
local FlameSource = Component:extend()
FlameSource.componentName = "FlameSource"

function FlameSource:init(stateComponent, activeState, range)
	Component.init(self)
	self.stateComponent = stateComponent
	self.activeState = activeState
	self.range = range or 1
end

function FlameSource:isActive()
	local stateComponent = self.owner:getComponent(self.stateComponent)
	return stateComponent ~= nil and stateComponent.state == self.activeState
end

function FlameSource:canReach(target)
	local sourceTransform = self.owner:getComponent("Transform")
	local targetTransform = target:getComponent("Transform")
	local distance = math.abs(sourceTransform.gridX - targetTransform.gridX)
		+ math.abs(sourceTransform.gridY - targetTransform.gridY)
	return distance <= self.range
end

function FlameSource:update(_dt)
	if not self:isActive() then return end
	local board = self.owner.parent
	if not board or not board.objects then return end

	for _, target in ipairs(board.objects) do
		local flameable = target:getComponent("Flameable")
		if flameable and self:canReach(target) then
			local component, previousState = flameable:burn(self.owner)
			if component and board.events then
				local objectIndex
				for index, object in ipairs(board.objects) do
					if object == target then
						objectIndex = index
						break
					end
				end
				board.events:emit("component.state_changed", {
					cause = "flame",
					objectIndex = objectIndex,
					component = component.componentName,
					previousState = previousState,
					state = component.state,
				})
			end
		end
	end
end

return FlameSource
