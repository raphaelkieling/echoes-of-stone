local Component = require("src.core.Component")

local NarrativeTrigger = Component:extend()
NarrativeTrigger.componentName = "NarrativeTrigger"

local function randomDebugColor()
	if love and love.math and love.math.random then
		return {
			0.35 + love.math.random() * 0.65,
			0.35 + love.math.random() * 0.65,
			0.35 + love.math.random() * 0.65,
		}
	end
	return {1, 0.8, 0.25}
end

function NarrativeTrigger:init(narrativeId, options)
	Component.init(self)
	assert(type(narrativeId) == "string" and narrativeId ~= "",
		"narrative trigger needs a narrative ID")
	options = options or {}
	self.narrativeId = narrativeId
	self.once = options.once ~= false
	self.fired = false
	self.debugColor = randomDebugColor()
end

function NarrativeTrigger:contains(_x, _y)
	return false
end

function NarrativeTrigger:getDebugCells()
	return {}
end

function NarrativeTrigger:getDebugLabelPosition(_cellSize)
	return 0, 0
end

function NarrativeTrigger:entered(change)
	return not self:contains(change.fromX, change.fromY)
		and self:contains(change.toX, change.toY)
end

function NarrativeTrigger:onObjectMoved(change, events)
	-- Triggers are activated by players only; pushed objects such as boxes
	-- must not consume one-shot triggers or start a narrative.
	if not change.object or not change.object:hasComponent("Player") then return false end
	if self.fired or not self:entered(change) then return false end
	if self.once then self.fired = true end

	local characterClass = change.object:getComponent("CharacterClass")
	events:emit("narrative.triggered", {
		id = self.narrativeId,
		actor = change.object.name,
		characterClass = characterClass and characterClass.id or nil,
		x = change.toX,
		y = change.toY,
	})
	return true
end

return NarrativeTrigger
