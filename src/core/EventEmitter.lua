local EventEmitter = {}
EventEmitter.__index = EventEmitter

function EventEmitter.new()
	return setmetatable({listeners = {}, nextId = 0}, EventEmitter)
end

function EventEmitter:on(eventName, callback)
	assert(type(eventName) == "string" and type(callback) == "function",
		"event name and callback are required")
	self.nextId = self.nextId + 1
	local listener = {id = self.nextId, callback = callback}
	self.listeners[eventName] = self.listeners[eventName] or {}
	table.insert(self.listeners[eventName], listener)
	return {eventName = eventName, id = listener.id}
end

function EventEmitter:off(subscription)
	if not subscription then return end
	local listeners = self.listeners[subscription.eventName]
	if not listeners then return end
	for index, listener in ipairs(listeners) do
		if listener.id == subscription.id then
			table.remove(listeners, index)
			return
		end
	end
end

local function notify(listeners, ...)
	for _, listener in ipairs(listeners or {}) do
		pcall(listener.callback, ...)
	end
end

function EventEmitter:emit(eventName, payload)
	notify(self.listeners[eventName], payload or {})
	if eventName ~= "*" then
		notify(self.listeners["*"], eventName, payload or {})
	end
end

return EventEmitter
