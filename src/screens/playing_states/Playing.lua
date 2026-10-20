local Class = require("src.core.Class")

local Playing = Class:extend()

function Playing:init(scene, machine)
	self.scene = scene
	self.machine = machine
end

function Playing:update(dt)
	self.scene:updatePlaying(dt)
end

function Playing:keypressed(key)
	self.scene:handlePlayingKey(key)
end

return Playing
