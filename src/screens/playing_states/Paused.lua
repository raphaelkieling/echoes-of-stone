local Class = require("src.core.Class")

local Paused = Class:extend()

function Paused:init(scene, machine)
	self.scene = scene
	self.machine = machine
	self.completed = false
end

function Paused:enter()
	self.scene:clearHeldMovement()
	self.scene.pauseSelection = 1
end

function Paused:update(dt)
	self.scene:updateCamera(dt)
end

function Paused:keypressed(key)
	self.scene:handlePauseKey(key, self.completed)
end

function Paused:mobileAction(action)
	self.scene:handlePauseAction(action, self.completed)
end

return Paused
