local Class = require("src.core.Class")

local LevelTransition = Class:extend()

function LevelTransition:init(scene, machine)
	self.scene = scene
	self.machine = machine
	self.elapsed = 0
	self.duration = 0.55
end

function LevelTransition:enter()
	self.scene.transition = {elapsed = 0, duration = self.duration}
	self.scene:loadNextLevel()
	self.scene:beginCameraIntro()
end

function LevelTransition:update(dt)
	self.elapsed = self.elapsed + dt
	self.scene.transition.elapsed = self.elapsed
	self.scene:updateCamera(dt)
	if self.elapsed >= self.duration then
		self.scene.transition = nil
		self.machine:change("playing")
	end
end

return LevelTransition
