local NarrativeTrigger = require("src.components.triggers.NarrativeTrigger")

local PointTrigger = NarrativeTrigger:extend()
PointTrigger.componentName = "PointTrigger"

function PointTrigger:init(narrativeId, x, y, options)
	NarrativeTrigger.init(self, narrativeId, options)
	self.x = x
	self.y = y
end

function PointTrigger:contains(x, y)
	return x == self.x and y == self.y
end

function PointTrigger:getDebugCells()
	return {{x = self.x, y = self.y}}
end

function PointTrigger:getDebugLabelPosition(cellSize)
	return self.x * cellSize, self.y * cellSize
end

return PointTrigger
