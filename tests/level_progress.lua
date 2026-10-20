local LevelProgress = require("src.game.LevelProgress")

local tests = {}

local function memoryStorage(contents)
	local storage = {contents = contents}
	storage.read = function(_path) return storage.contents end
	storage.write = function(_path, value)
			storage.contents = value
			return true, #value
	end
	return storage
end

function tests.completed_levels_are_saved_and_restored()
	local storage = memoryStorage()
	local progress = LevelProgress.new(storage)

	assert(progress:markCompleted("maps/level1.tmj"))
	assert(progress:isCompleted("maps/level1.tmj"))

	local loadedProgress = LevelProgress.new(storage)
	assert(loadedProgress:isCompleted("maps/level1.tmj"))
	assert(not loadedProgress:isCompleted("maps/level2.tmj"))
end

function tests.invalid_save_data_is_ignored()
	local progress = LevelProgress.new(memoryStorage("not json"))
	assert(not progress:isCompleted("maps/level1.tmj"))
end

return tests
