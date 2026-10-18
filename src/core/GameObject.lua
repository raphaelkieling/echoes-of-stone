local Class = require("src.core.Class")

local GameObject = Class:extend()

function GameObject:init(name)
    self.name = name or "GameObject"
    self.components = {}
    self.componentOrder = {}
end

function GameObject:addComponent(component)
    assert(component.componentName, "components must declare componentName")
    assert(not self.components[component.componentName], "duplicate component: " .. component.componentName)

    component.owner = self
    self.components[component.componentName] = component
    self.componentOrder[#self.componentOrder + 1] = component
    component:onAttach(self)
    return self
end

function GameObject:getComponent(componentName)
    return self.components[componentName]
end

function GameObject:hasComponent(componentName)
    return self.components[componentName] ~= nil
end

function GameObject:update(dt)
    for _, component in ipairs(self.componentOrder) do
        component:update(dt)
    end
end

function GameObject:draw(context)
    for _, component in ipairs(self.componentOrder) do
        component:draw(context)
    end
end

return GameObject
