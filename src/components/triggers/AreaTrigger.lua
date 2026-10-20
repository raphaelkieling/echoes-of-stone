local NarrativeTrigger = require("src.components.triggers.NarrativeTrigger")

local AreaTrigger = NarrativeTrigger:extend()
AreaTrigger.componentName = "AreaTrigger"

function AreaTrigger:init(narrativeId, x, y, width, height, tileWidth, tileHeight, options)
	NarrativeTrigger.init(self, narrativeId, options)
	self.x = x
	self.y = y
	self.width = width
	self.height = height
	self.tileWidth = tileWidth
	self.tileHeight = tileHeight
end

function AreaTrigger:contains(gridX, gridY)
	local centerX = (gridX + 0.5) * self.tileWidth
	local centerY = (gridY + 0.5) * self.tileHeight
	return centerX >= self.x and centerX < self.x + self.width
		and centerY >= self.y and centerY < self.y + self.height
end

function AreaTrigger:getDebugCells()
	local cells = {}
	local minX = math.floor(self.x / self.tileWidth)
	local maxX = math.ceil((self.x + self.width) / self.tileWidth) - 1
	local minY = math.floor(self.y / self.tileHeight)
	local maxY = math.ceil((self.y + self.height) / self.tileHeight) - 1
	for gridY = minY, maxY do
		for gridX = minX, maxX do
			if self:contains(gridX, gridY) then
				cells[#cells + 1] = {x = gridX, y = gridY}
			end
		end
	end
	return cells
end

function AreaTrigger:getDebugLabelPosition(cellSize)
	local scaleX = cellSize / self.tileWidth
	local scaleY = cellSize / self.tileHeight
	return self.x * scaleX, self.y * scaleY
end

return AreaTrigger
