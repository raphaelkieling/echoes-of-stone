local Class = require("src.core.Class")

-- Reusable state lifecycle. States receive a context and this machine.
local StateMachine = Class:extend()

function StateMachine:init(context, states, initialState)
	self.context = context
	self.states = assert(states, "StateMachine needs a state registry")
	self.currentName = nil
	self.current = nil
	if initialState then self:change(initialState) end
end

function StateMachine:change(name, data)
	local State = assert(self.states[name], "unknown state: " .. tostring(name))
	if self.current and self.currentName == name then return false end
	if self.current and self.current.exit then self.current:exit(data) end
	self.currentName = name
	self.current = State(self.context, self)
	if self.current.enter then self.current:enter(data) end
	return true
end

function StateMachine:is(name)
	return self.currentName == name
end

function StateMachine:update(dt)
	if self.current and self.current.update then self.current:update(dt) end
end

function StateMachine:dispatch(methodName, ...)
	local handler = self.current and self.current[methodName]
	if not handler then return false end
	return handler(self.current, ...)
end

return StateMachine
