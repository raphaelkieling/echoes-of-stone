local Node = require("src.core.Node")
local UI = require("src.ui.Theme")

local DialogueBox = Node:extend()

function DialogueBox:init(runner)
	Node.init(self, "DialogueBox")
	self.runner = runner
	self.drawSpace = "screen"
end

function DialogueBox:draw()
	local dialogue = self.runner:getDialogue()
	if not dialogue then return end

	local width, height = love.graphics.getDimensions()
	local scale = UI.scale(width, height)
	local textWidth = math.min(width - 64 * scale, 900 * scale)
	local textX = (width - textWidth) / 2
	local textY = height - 112 * scale

	love.graphics.push("all")
	if dialogue.speaker ~= "" then
		UI.setColor("accent")
		UI.setFont(25, width, height)
		love.graphics.printf(dialogue.speaker, textX, textY, textWidth, "center")
	end

	love.graphics.setColor(1, 1, 1, 1)
	UI.setFont(32, width, height)
	love.graphics.printf(dialogue.text, textX, textY + 34 * scale, textWidth, "center")
	love.graphics.pop()
end

return DialogueBox
