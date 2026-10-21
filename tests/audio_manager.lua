local AudioManager = require("src.audio.AudioManager")

local tests = {}

function tests.mute_toggle_updates_all_audio_sources()
	local previousLove = love
	local createdSources = {}
	_G.love = {
		audio = {
			newSource = function(path, sourceType)
				local source = {
					path = path,
					type = sourceType,
					volume = nil,
					setVolume = function(self, volume) self.volume = volume end,
				}
				createdSources[#createdSources + 1] = source
				return source
			end,
		},
	}

	local manager = AudioManager.new({
		voice = {file = "voice.mp3", volume = 0.6},
	})
	assert(createdSources[1].volume == 0.6)

	manager:setMuted(true)
	assert(createdSources[1].volume == 0, "muting should silence the source")
	manager:setMuted(false)
	assert(createdSources[1].volume == 0.6, "unmuting should restore the source volume")

	_G.love = previousLove
end

function tests.voice_mp3_plays_as_a_stream_and_obeys_mute()
	local previousLove = love
	local createdSources = {}
	_G.love = {
		audio = {
			newSource = function(path, sourceType)
				local source = {
					path = path,
					type = sourceType,
					volume = nil,
					playing = false,
					setVolume = function(self, volume) self.volume = volume end,
					play = function(self) self.playing = true end,
					stop = function(self) self.playing = false end,
				}
				createdSources[#createdSources + 1] = source
				return source
			end,
		},
	}
	local ok, errorMessage = pcall(function()
		local manager = AudioManager.new({click = {file = "click.wav", volume = 0.4}})
		assert(manager:playVoice("assets/voices/line.mp3"))
		local voice = createdSources[2]
		assert(voice.path == "assets/voices/line.mp3" and voice.type == "stream")
		assert(voice.playing and voice.volume == 1)
		manager:setMuted(true)
		assert(voice.volume == 0, "mute should silence a playing voice")
		manager:setMuted(false)
		assert(voice.volume == 1, "unmute should restore a playing voice")
		assert(manager:stopVoice() and not voice.playing)
	end)
	_G.love = previousLove
	assert(ok, errorMessage)
end

return tests
