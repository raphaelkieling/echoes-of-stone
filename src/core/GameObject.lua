local Node = require("src.core.Node")

local GameObject = Node:extend()

function GameObject:init(name)
    Node.init(self, name or "GameObject")
    self.components = {}
    self.componentOrder = {}
end

function GameObject:addComponent(component)
    assert(component.componentName, "components must declare componentName")
    assert(not self:getComponent(component.componentName), "duplicate component: " .. component.componentName)

    component.owner = self
    self.components[component.componentName] = component
    self.componentOrder[#self.componentOrder + 1] = component
    component:onAttach(self)
    return self
end

function GameObject:getComponent(componentName)
	local component = self.components[componentName]
	if component then return component end
	for _, child in ipairs(self.componentOrder) do
		if child.getNestedComponent then
			component = child:getNestedComponent(componentName)
			if component then return component end
		end
	end
	return nil
end

function GameObject:hasComponent(componentName)
	return self:getComponent(componentName) ~= nil
end

function GameObject:update(dt)
    for _, component in ipairs(self.componentOrder) do
        component:update(dt)
    end
    self:updateChildren(dt)
end

function GameObject:draw(context)
    for _, component in ipairs(self.componentOrder) do
        component:draw(context)
    end
    self:drawChildren(nil, context)
end

return GameObject
