local Class = require("src.core.Class")
local Keymap = require("src.settings.Keymap")

local Dialogue = Class:extend()

function Dialogue:init(definition, services)
	self.speaker = definition.speaker or ""
	self.text = assert(definition.text, "dialogue step needs text")
	self.voice = definition.voice
	self.audio = services and services.audio
	if self.voice and self.audio then
		local played, playError = self.audio:playVoice(self.voice)
		if not played then
			print("Could not play narrative voice '" .. self.voice .. "': " .. tostring(playError))
		end
	end
end

function Dialogue:keypressed(key)
	if not Keymap.matches("confirm", key) then return false end
	self:onExit()
	return true
end

function Dialogue:advance()
	self:onExit()
	return true
end

function Dialogue:onExit()
	if self.voice and self.audio then
		self.audio:stopVoice()
		self.voice = nil
	end
end

return Dialogue
