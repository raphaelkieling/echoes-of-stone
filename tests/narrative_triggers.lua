local GameObject = require("src.core.GameObject")
local EventEmitter = require("src.core.EventEmitter")
local Player = require("src.components.Player")
local Box = require("src.components.Box")
local PointTrigger = require("src.components.triggers.PointTrigger")

local tests = {}

local function makeObject(name, component)
	local object = GameObject(name)
	object:addComponent(component())
	return object
end

local function movement(object, fromX, fromY, toX, toY)
	return {object = object, fromX = fromX, fromY = fromY, toX = toX, toY = toY}
end

function tests.box_entering_point_trigger_does_not_fire_or_consume_it()
	local trigger = PointTrigger("tutorial_audio", 2, 1)
	local box = makeObject("test-box", Box)
	local player = makeObject("test-player", Player)
	local events = EventEmitter.new()
	local firedCount = 0
	events:on("narrative.triggered", function() firedCount = firedCount + 1 end)

	assert(not trigger:onObjectMoved(movement(box, 1, 1, 2, 1), events))
	assert(not trigger.fired, "a box must not consume a one-shot trigger")
	assert(firedCount == 0, "a box must not start the trigger narrative/audio")

	assert(trigger:onObjectMoved(movement(player, 1, 1, 2, 1), events))
	assert(trigger.fired)
	assert(firedCount == 1, "the player should still activate the trigger")
end

return tests
