local GameObject = require("src.core.GameObject")
local Bonfire = require("src.components.Bonfire")
local Board = require("src.game.Board")
local MovementSession = require("src.game.MovementSession")
local SpriteRenderer = require("src.components.SpriteRenderer")

local tests = {}

function tests.bonfire_switches_between_lit_animation_and_static_unlit_frame()
	local tileset = {name = "animated tiles"}
	local assets = {
		bonfireAnimation = function(_, _, state)
			return {state = state, update = function() end}
		end,
	}
	local object = GameObject("test-bonfire")
	local bonfire = Bonfire(assets, tileset)
	object:addComponent(bonfire)

	local animation = object:getComponent("Animation")
	assert(bonfire.state == "lit")
	assert(animation.current.state == "lit")
	assert(bonfire.tileset == tileset)

	bonfire:setState("unlit")
	assert(bonfire.state == "unlit")
	assert(animation.current.state == "unlit")

	bonfire:setState("lit")
	assert(bonfire.state == "lit")
	assert(animation.current.state == "lit")
end

function tests.board_registers_bonfire_as_a_pushable_interactive_object()
	local assets = {
		bonfireAnimation = function()
			return {update = function() end}
		end,
		tilesetRenderer = function()
			return SpriteRenderer({}, 2, 1)
		end,
	}
	local board = Board(assets, 8, 8)
	local tileset = {name = "animated tiles"}
	local bonfire = board:addBonfire(3, 4, tileset)
	local movement = MovementSession.new(board)

	assert(bonfire:hasComponent("InteractiveObject"))
	assert(movement:objectAt(3, 4) == bonfire)
end

return tests
