local Class = require("src.core.Class")

local PlayerSelector = Class:extend()

function PlayerSelector:init()
	self.activeIndex = 1
	self.held = false
	self.usedDirection = false
end

function PlayerSelector:reset()
	self.activeIndex = 1
	self:cancel()
end

function PlayerSelector:cancel()
	self.held = false
	self.usedDirection = false
end

function PlayerSelector:isHeld()
	return self.held
end

function PlayerSelector:begin()
	if self.held then return false end
	self.held = true
	self.usedDirection = false
	return true
end

function PlayerSelector:selectNext(players)
	if #players == 0 then return nil end
	local previousIndex = self.activeIndex
	self.activeIndex = self.activeIndex % #players + 1
	return {from = previousIndex, to = self.activeIndex}
end

function PlayerSelector:selectInDirection(players, direction)
	if not self.held then return nil end
	self.usedDirection = true
	local current = players[self.activeIndex]
	if not current then return nil end
	local currentTransform = current:getComponent("Transform")
	local bestIndex, bestForward, bestSide

	for index, player in ipairs(players) do
		if index ~= self.activeIndex then
			local transform = player:getComponent("Transform")
			local dx = transform.gridX - currentTransform.gridX
			local dy = transform.gridY - currentTransform.gridY
			local forward = dx * direction.x + dy * direction.y
			if forward > 0 then
				local side = math.abs(dx * direction.y - dy * direction.x)
				if not bestForward or side < bestSide or (side == bestSide and forward < bestForward) then
					bestIndex, bestForward, bestSide = index, forward, side
				end
			end
		end
	end

	if not bestIndex then return nil end
	local previousIndex = self.activeIndex
	self.activeIndex = bestIndex
	return {from = previousIndex, to = self.activeIndex}
end

function PlayerSelector:finish(players)
	if not self.held then return nil end
	local shouldSelectNext = not self.usedDirection
	self:cancel()
	if shouldSelectNext then return self:selectNext(players) end
	return nil
end

return PlayerSelector
