local json = require("vendor.json")
local GameConfig = require("src.settings.GameConfig")

local JsonLogger = {}
JsonLogger.__index = JsonLogger

local DIRECTORY = "logs"

local function sessionPath()
	return string.format("%s/session-%s-%06d.json", DIRECTORY,
		os.date("!%Y%m%d-%H%M%S"), love.math.random(0, 999999))
end

function JsonLogger.new(events)
	assert(events and events.on, "JsonLogger requires an event emitter")
	pcall(love.filesystem.createDirectory, DIRECTORY)
	local major, minor, revision = love.getVersion()
	local self = setmetatable({
		path = sessionPath(),
		startedAt = love.timer.getTime(),
		lastError = nil,
		data = {
			formatVersion = 1,
			game = GameConfig.title,
			loveVersion = string.format("%d.%d.%d", major, minor, revision),
			startedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
			events = {},
		},
	}, JsonLogger)
	self.subscription = events:on("*", function(eventName, payload)
		self:record(eventName, payload)
	end)
	return self
end

function JsonLogger:record(eventName, payload)
	local event = {
		at = math.max(0, love.timer.getTime() - self.startedAt),
		name = eventName,
		data = payload or {},
	}
	self.data.events[#self.data.events + 1] = event
	local ok, encoded = pcall(json.encode, self.data)
	if not ok then
		self.lastError = encoded
		return false
	end
	local called, written, err = pcall(love.filesystem.write, self.path, encoded)
	if not called or not written then
		self.lastError = called and err or written
		return false
	end
	self.lastError = nil
	return true
end

function JsonLogger:getPath()
	return love.filesystem.getSaveDirectory() .. "/" .. self.path
end

return JsonLogger
