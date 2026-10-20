local json = require("vendor.json")

local LevelProgress = {}
LevelProgress.__index = LevelProgress

local SAVE_PATH = "level-progress.json"

local function loveStorage()
	return {
		read = function(path) return love.filesystem.read(path) end,
		write = function(path, contents) return love.filesystem.write(path, contents) end,
	}
end

function LevelProgress.new(storage)
	local self = setmetatable({
		storage = storage or loveStorage(),
		completedLevels = {},
	}, LevelProgress)
	self:load()
	return self
end

function LevelProgress:load()
	local ok, contents = pcall(self.storage.read, SAVE_PATH)
	if not ok or type(contents) ~= "string" then return end

	local decoded, data = pcall(json.decode, contents)
	if not decoded or type(data) ~= "table" or type(data.completedLevels) ~= "table" then return end

	for path, completed in pairs(data.completedLevels) do
		if type(path) == "string" and completed == true then
			self.completedLevels[path] = true
		end
	end
end

function LevelProgress:isCompleted(levelPath)
	return self.completedLevels[levelPath] == true
end

function LevelProgress:markCompleted(levelPath)
	if type(levelPath) ~= "string" or levelPath == "" then return false end
	self.completedLevels[levelPath] = true
	local ok, contents = pcall(json.encode, {
		formatVersion = 1,
		completedLevels = self.completedLevels,
	})
	if not ok then return false end
	local wrote, success = pcall(self.storage.write, SAVE_PATH, contents)
	return wrote and success == true
end

return LevelProgress
