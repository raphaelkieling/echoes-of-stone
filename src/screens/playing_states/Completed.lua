local Paused = require("src.screens.playing_states.Paused")

local Completed = Paused:extend()

function Completed:init(scene, machine)
	Paused.init(self, scene, machine)
	self.completed = true
end

return Completed
