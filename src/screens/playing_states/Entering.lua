local Class = require("src.core.Class")

local Entering = Class:extend()

function Entering:init(scene, machine)
	self.scene = scene
	self.machine = machine
	self.elapsed = 0
	self.duration = 0.5
end

function Entering:enter()
	self.scene:clearHeldMovement()
	self.scene:beginCameraIntro()
end

function Entering:update(dt)
	self.scene:updateCamera(dt)
	self.elapsed = self.elapsed + dt
	if self.elapsed >= self.duration then self.machine:change("playing") end
end

function Entering:keypressed(key)
	if self.scene:handleCameraKey(key) then self.machine:change("playing") end
end

return Entering
