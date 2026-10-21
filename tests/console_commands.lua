local ConsoleCommands = require("src.dev.ConsoleCommands")

local tests = {}

function tests.muted_console_toggle_changes_audio_state()
	local commands = {}
	local console = {}
	function console:registerCommand(name, description, callback)
		commands[name] = {description = description, callback = callback}
	end
	function console:registerToggleCommand(name, description, callback)
		self:registerCommand(name, description, callback)
		commands[name].toggle = true
	end

	ConsoleCommands.register(console)
	local command = assert(commands.muted, "muted command should be registered")
	assert(command.toggle, "muted should use the console toggle behavior")

	local muted
	local context = {game = {audio = {setMuted = function(_, enabled) muted = enabled end}}}
	assert(command.callback(context, true) == "Audio muted.")
	assert(muted == true)
	assert(command.callback(context, false) == "Audio unmuted.")
	assert(muted == false)
end

return tests
