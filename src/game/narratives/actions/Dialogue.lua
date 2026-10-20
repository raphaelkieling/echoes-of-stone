local Class = require("src.core.Class")
local Keymap = require("src.settings.Keymap")

local Dialogue = Class:extend()

function Dialogue:init(definition)
	self.speaker = definition.speaker or ""
	self.text = assert(definition.text, "dialogue step needs text")
end

function Dialogue:keypressed(key)
	return Keymap.matches("confirm", key)
end

function Dialogue:advance()
	return true
end

return Dialogue
