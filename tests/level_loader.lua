local json = require("vendor.json")
local LevelLoader = require("src.game.LevelLoader")

local tests = {}

function tests.passthrough_entity_marks_a_cell_and_overrides_collision_wall()
	local project = {
		defs = {
			layers = {
				{
					uid = 1,
					identifier = "Collision",
					type = "IntGrid",
					intGridValuesGroups = {{uid = 1, identifier = "Collision"}},
					intGridValues = {{value = 1, identifier = "Wall", groupUid = 1}},
				},
				{uid = 2, identifier = "Ground", type = "Tiles"},
				{uid = 3, identifier = "Entities", type = "Entities"},
			},
			tilesets = {},
		},
		levels = {{
			identifier = "Fixture",
			layerInstances = {
				{
					layerDefUid = 3,
					__identifier = "Entities",
					__type = "Entities",
					__cWid = 3,
					__cHei = 1,
					__gridSize = 32,
					entityInstances = {{__identifier = "Passthrough", px = {32, 0}}},
				},
				{
					layerDefUid = 2,
					__identifier = "Ground",
					__type = "Tiles",
					__cWid = 3,
					__cHei = 1,
					__gridSize = 32,
					gridTiles = {{px = {0, 0}}},
				},
				{
					layerDefUid = 1,
					__identifier = "Collision",
					__type = "IntGrid",
					__cWid = 3,
					__cHei = 1,
					__gridSize = 32,
					intGridCsv = {0, 1, 0},
				},
			},
		}},
	}

	local previousLove = rawget(_G, "love")
	_G.love = {filesystem = {read = function() return json.encode(project) end}}
	local ok, board = pcall(LevelLoader.load, "fixture.ldtk", {}, nil, "Fixture")
	_G.love = previousLove
	assert(ok, board)

	assert(board:canWalk(0, 0), "Ground tiles should remain walkable")
	local passthrough = board:getCell(1, 0)
	assert(passthrough and passthrough.passthrough, "Passthrough entity should mark its cell")
	assert(not passthrough.walkable and not passthrough.wall,
		"Passthrough should be blocked for walking and override the collision wall")
	assert(board:getCell(2, 0) == nil,
		"an empty Ground cell without a Passthrough entity should remain void")
end

return tests
