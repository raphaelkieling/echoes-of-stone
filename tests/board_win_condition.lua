local Board = require("src.game.Board")
local GameObject = require("src.core.GameObject")
local Transform = require("src.components.Transform")
local Box = require("src.components.Box")

local tests = {}

local function addBox(board, x, y)
	local box = GameObject("test-box")
	box:addComponent(Transform(x, y, 64, 2))
	box:addComponent(Box())
	board:addObject(box)
	return box
end

function tests.level_wins_when_every_target_is_occupied_even_with_extra_boxes()
	local board = Board(nil, 12, 2)
	board.targets = {{x = 1, y = 0}, {x = 2, y = 0}}

	addBox(board, 1, 0)
	addBox(board, 2, 0)
	for x = 3, 10 do
		addBox(board, x, 1)
	end

	assert(#board.boxes == 10)
	assert(board:allTargetsCovered())
end

function tests.level_does_not_win_while_any_target_is_unoccupied()
	local board = Board(nil, 4, 1)
	board.targets = {{x = 1, y = 0}, {x = 2, y = 0}}
	addBox(board, 1, 0)
	addBox(board, 3, 0)

	assert(not board:allTargetsCovered())
end

function tests.level_without_targets_does_not_win_automatically()
	local board = Board(nil, 4, 1)
	addBox(board, 1, 0)

	assert(not board:allTargetsCovered())
end

return tests
