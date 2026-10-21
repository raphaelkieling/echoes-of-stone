local Node = require("src.core.Node")
local Dialogue = require("src.game.narratives.actions.Dialogue")
local Wait = require("src.game.narratives.actions.Wait")

local ACTIONS = {
	dialogue = Dialogue,
	wait = Wait,
}

local SequenceRunner = Node:extend()

function SequenceRunner:init(events, catalog, callbacks)
	Node.init(self, "SequenceRunner")
	self.events = events
	self.catalog = catalog
	self.callbacks = callbacks or {}
	self.queue = {}
	self.active = nil
	self.subscription = events:on("narrative.triggered", function(payload)
		self:queueNarrative(payload)
	end)
end

function SequenceRunner:onDetach()
	local action = self.active and self.active.action
	if action and action.onExit then action:onExit() end
	self.events:off(self.subscription)
	self.subscription = nil
end

function SequenceRunner:queueNarrative(payload)
	local narrative = self.catalog.get(payload.id)
	if not narrative then
		self.events:emit("narrative.missing", {id = payload.id})
		print("Narrative trigger has no matching definition: " .. tostring(payload.id))
		return false
	end
	for index, step in ipairs(narrative.steps) do
		local invalid = not ACTIONS[step.type]
		if step.type == "dialogue" and type(step.text) ~= "string" then invalid = true end
		if step.type == "dialogue" and step.voice ~= nil and type(step.voice) ~= "string" then
			invalid = true
		end
		if step.type == "wait" and step.duration ~= nil and type(step.duration) ~= "number" then
			invalid = true
		end
		if invalid then
			self.events:emit("narrative.invalid", {
				id = payload.id, step = index, action = step.type,
			})
			print(string.format("Narrative '%s' has an invalid action at step %d (%s)",
				payload.id, index, tostring(step.type)))
			return false
		end
	end
	local request = {narrative = narrative, trigger = payload}
	if self.active then
		self.queue[#self.queue + 1] = request
	else
		self:start(request)
	end
	return true
end

function SequenceRunner:start(request)
	self.active = {
		narrative = request.narrative,
		trigger = request.trigger,
		stepIndex = 0,
		blocking = request.narrative.blocking,
	}
	self.events:emit("narrative.started", {id = request.narrative.id})
	if self.active.blocking and self.callbacks.onBlockingStarted then
		self.callbacks.onBlockingStarted(request.narrative)
	end
	self:advanceStep()
end

function SequenceRunner:advanceStep()
	if not self.active then return end
	local previousAction = self.active.action
	if previousAction and previousAction.onExit then previousAction:onExit() end
	self.active.stepIndex = self.active.stepIndex + 1
	local definition = self.active.narrative.steps[self.active.stepIndex]
	if not definition then
		self:finish()
		return
	end
	local Action = ACTIONS[definition.type]
	assert(Action, "unknown narrative action: " .. tostring(definition.type))
	self.active.action = Action(definition, {audio = self.callbacks.audio})
end

function SequenceRunner:update(dt)
	local action = self.active and self.active.action
	if action and action.update and action:update(dt) then
		self:advanceStep()
	end
end

function SequenceRunner:keypressed(key)
	local action = self.active and self.active.action
	if action and action.keypressed and action:keypressed(key) then
		self:advanceStep()
		return true
	end
	return false
end

function SequenceRunner:advance()
	local action = self.active and self.active.action
	if action and action.advance and action:advance() then
		self:advanceStep()
		return true
	end
	return false
end

function SequenceRunner:cancel()
	if not self.active then return false end
	self.queue = {}
	self:finish()
	return true
end

function SequenceRunner:finish()
	local completed = self.active
	if not completed then return end
	local action = completed.action
	if action and action.onExit then action:onExit() end
	self.active = nil
	self.events:emit("narrative.completed", {id = completed.narrative.id})
	if completed.blocking and self.callbacks.onBlockingFinished then
		self.callbacks.onBlockingFinished(completed.narrative)
	end
	local nextRequest = table.remove(self.queue, 1)
	if nextRequest then self:start(nextRequest) end
end

function SequenceRunner:getDialogue()
	local action = self.active and self.active.action
	if action and action.text then
		return {speaker = action.speaker, text = action.text}
	end
	return nil
end

return SequenceRunner
