local Component = require("src.core.Component")
local Animation = require("src.components.Animation")

-- Owns a target's pressed/free state and the one-frame animation for each.
local Target = Component:extend()
Target.componentName = "Target"

function Target:init(board, assets, tileId)
	Component.init(self)
	self.board = board
	self.assets = assets
	self.tileId = tileId or (16 * assets.tileColumns + 9)
	self.state = "free"
	self.components = {}
	self.componentOrder = {}

	local column = self.tileId % assets.tileColumns
	local row = math.floor(self.tileId / assets.tileColumns)
	self.freeAnimation = assets:tileAnimation(column, row)
	self.pressedAnimation = assets:tileAnimation(column + 1, row)
	self:addComponent(Animation(self.freeAnimation))
end

function Target:addComponent(component)
	assert(not self.components[component.componentName],
		"duplicate target component: " .. component.componentName)
	component.owner = self.owner
	self.components[component.componentName] = component
	self.componentOrder[#self.componentOrder + 1] = component
	component:onAttach(self.owner)
	return self
end

function Target:getNestedComponent(componentName)
	return self.components[componentName]
end

function Target:onAttach(owner)
	for _, component in ipairs(self.componentOrder) do
		component.owner = owner
		component:onAttach(owner)
	end
end

function Target:setState(state)
	if state == self.state then return end
	self.state = state
	local animation = self.components.Animation
	animation:set(state == "pressed" and self.pressedAnimation or self.freeAnimation)
end

function Target:refreshState()
	local transform = self.owner:getComponent("Transform")
	local pressed = self.board:isBoxAt(transform.gridX, transform.gridY)
	self:setState(pressed and "pressed" or "free")
end

function Target:update(dt)
	self:refreshState()
	for _, component in ipairs(self.componentOrder) do
		component:update(dt)
	end
end

return Target
