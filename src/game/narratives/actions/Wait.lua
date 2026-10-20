local Class = require("src.core.Class")

local Wait = Class:extend()

function Wait:init(definition)
	self.duration = math.max(0, definition.duration or 0)
	self.elapsed = 0
end

function Wait:update(dt)
	self.elapsed = self.elapsed + dt
	return self.elapsed >= self.duration
end

return Wait
