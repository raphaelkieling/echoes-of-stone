local Class = require("src.core.Class")
local Keymap = require("src.settings.Keymap")

local Narrative = Class:extend()

function Narrative:init(scene, machine)
	self.scene = scene
	self.machine = machine
end

function Narrative:enter()
	self.scene:clearHeldMovement()
end

function Narrative:update(dt)
	self.scene:updateCamera(dt)
end

function Narrative:keypressed(key)
	if Keymap.matches("cancel", key) then
		self.scene.game.audio:play("uiClick")
		self.scene.narratives:cancel()
		return
	end
	if self.scene.narratives:keypressed(key) then
		self.scene.game.audio:play("uiClick")
	end
end

function Narrative:mobileAction(action)
	if action == "a" and self.scene.narratives:advance() then
		self.scene.game.audio:play("uiClick")
	elseif action == "b" then
		self.scene.game.audio:play("uiClick")
		self.scene.narratives:cancel()
	end
end

return Narrative
