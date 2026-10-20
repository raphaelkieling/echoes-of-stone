local Component = require("src.core.Component")

-- A character is a composite component: its behavior, state, animation and
-- effects live together, while still being discoverable through its GameObject.
local Character = Component:extend()
Character.componentName = "Character"

function Character:init()
	Component.init(self)
	self.components = {}
	self.componentOrder = {}
end

function Character:addComponent(component)
	assert(component.componentName, "components must declare componentName")
	assert(not self.owner:getComponent(component.componentName),
		"duplicate component: " .. component.componentName)
	component.owner = self.owner
	self.components[component.componentName] = component
	self.componentOrder[#self.componentOrder + 1] = component
	component:onAttach(self.owner)
	return self
end

function Character:replaceComponent(componentName, component)
	local previous = self.components[componentName]
	if not previous then return self:addComponent(component) end
	assert(component.componentName == componentName,
		"replacement component must keep the same componentName")
	for index, child in ipairs(self.componentOrder) do
		if child == previous then
			table.remove(self.componentOrder, index)
			break
		end
	end
	self.components[componentName] = nil
	previous:onDetach(self.owner)
	previous.owner = nil
	return self:addComponent(component)
end

function Character:getNestedComponent(componentName)
	return self.components[componentName]
end

function Character:update(dt)
	for _, component in ipairs(self.componentOrder) do
		component:update(dt)
	end
end

function Character:draw(context)
	for _, component in ipairs(self.componentOrder) do
		component:draw(context)
	end
end

return Character
