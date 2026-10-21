local EventEmitter = require("src.core.EventEmitter")
local SequenceRunner = require("src.game.narratives.SequenceRunner")

local tests = {}

function tests.dialogue_action_plays_voice_and_stops_it_when_advanced()
	local events = EventEmitter.new()
	local audio = {played = {}, stopped = 0}
	function audio:playVoice(path) self.played[#self.played + 1] = path; return true end
	function audio:stopVoice() self.stopped = self.stopped + 1 end
	local narrative = {steps = {
		{type = "dialogue", speaker = "Dwarf", text = "Hello", voice = "assets/voices/line.mp3"},
	}}
	local catalog = {get = function(id) return id == "voice_test" and narrative end}
	local runner = SequenceRunner(events, catalog, {audio = audio})

	events:emit("narrative.triggered", {id = "voice_test"})
	assert(audio.played[1] == "assets/voices/line.mp3", "dialogue should start its configured voice")
	assert(runner:getDialogue().text == "Hello")
	assert(runner:advance())
	assert(audio.stopped == 1, "advancing the dialogue should stop its voice")
	assert(runner.active == nil, "the narrative should finish after its only line")
end

function tests.cancelled_dialogue_stops_its_voice()
	local events = EventEmitter.new()
	local stopped = 0
	local audio = {
		playVoice = function() return true end,
		stopVoice = function() stopped = stopped + 1 end,
	}
	local catalog = {get = function()
		return {steps = {{type = "dialogue", text = "Hello", voice = "voice.mp3"}}}
	end}
	local runner = SequenceRunner(events, catalog, {audio = audio})
	events:emit("narrative.triggered", {id = "voice_test"})
	assert(runner:cancel())
	assert(stopped == 1, "cancelling the narrative should stop its voice")
end

return tests
