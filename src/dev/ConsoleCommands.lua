local LevelLoader = require("src.game.LevelLoader")

local ConsoleCommands = {}

local function findLevelIndex(levels, query)
    local normalized = query:lower()
    if normalized == "p" then normalized = "playground" end

    local numericLevel = tonumber(normalized)
    for index, level in ipairs(levels) do
        if numericLevel and level.number == numericLevel then
            return index, level
        end
    end

    for index, level in ipairs(levels) do
        local name = (level.name or ""):lower()
        local shortName = name:gsub("^level[_%-]?", "")
        if normalized == name or normalized == shortName
            or name:find(normalized, 1, true) then
            return index, level
        end
    end
end

local function shellQuote(value)
	return "'" .. value:gsub("'", "'\\''") .. "'"
end

function ConsoleCommands.register(console)
	console:registerCommand("copy-logger-path", "copy the current JSON log path", function(context)
		local game = context and context.game
		local logger = game and game.logger
		if not logger then return "Logger is unavailable." end
		if logger.lastError then
			return "Logger write failed: " .. tostring(logger.lastError)
		end
		if not love.filesystem.getInfo(logger.path) then
			return "Logger file has not been created: " .. logger:getPath()
		end

		local path = logger:getPath()
		local quotedPath = shellQuote(path)
		local copied, err = pcall(love.system.setClipboardText, quotedPath)
		if not copied then return "Could not copy logger path: " .. tostring(err) end
		return "Shell-quoted logger path copied: " .. quotedPath
	end)

	console:registerCommand("show-undo-history", "show player paths for each undo", function(context, args)
		local board = context and context.board
		if not board then return "No active board." end

		local mode = (args[1] or "toggle"):lower()
		if mode == "on" then
			board.debugShowUndoHistory = true
		elseif mode == "off" then
			board.debugShowUndoHistory = false
		elseif mode == "toggle" then
			board.debugShowUndoHistory = not board.debugShowUndoHistory
		else
			return "Usage: show-undo-history [on|off|toggle]"
		end
		return "Undo history " .. (board.debugShowUndoHistory and "on" or "off") .. "."
	end)

	console:registerCommand("show-narrative-triggers", "show outlines and IDs for Tiled narrative triggers", function(context, args)
		local board = context and context.board
		if not board then return "No active board." end

		local mode = (args[1] or "toggle"):lower()
		if mode == "on" then
			board.debugShowNarrativeTriggers = true
		elseif mode == "off" then
			board.debugShowNarrativeTriggers = false
		elseif mode == "toggle" then
			board.debugShowNarrativeTriggers = not board.debugShowNarrativeTriggers
		else
			return "Usage: show-narrative-triggers [on|off|toggle]"
		end
		return "Narrative trigger outlines "
			.. (board.debugShowNarrativeTriggers and "on" or "off") .. "."
	end)

	console:registerCommand("mobile-controls", "show or hide mobile touch controls", function(context, args)
		local game = context and context.game
		if not game or not game.mobileControls then return "Mobile controls are unavailable." end
		local mode = (args[1] or "toggle"):lower()
		if mode == "on" then
			game.mobileControls.enabled = true
		elseif mode == "off" then
			game.mobileControls.enabled = false
			game.mobileControls:resetTouches()
		elseif mode == "toggle" then
			game.mobileControls.enabled = not game.mobileControls.enabled
			if not game.mobileControls.enabled then game.mobileControls:resetTouches() end
		else
			return "Usage: mobile-controls [on|off|toggle]"
		end
		return "Mobile controls " .. (game.mobileControls.enabled and "on" or "off") .. "."
	end)

	console:registerCommand("force reload", "restart the game and reload assets and levels", function(context)
		if not context or not context.game or not love then
			return "Game reload is unavailable."
		end

		local Game = require("src.game.Game")
		love.game = Game.new()
	end)

	console:registerCommand("show-solid", "toggle outlines for solid cells and objects", function(context, args)
        local board = context and context.board
        if not board then return "No active board." end

        local mode = (args[1] or "toggle"):lower()
        if mode == "on" then
            board.debugShowSolid = true
        elseif mode == "off" then
            board.debugShowSolid = false
        elseif mode == "toggle" then
            board.debugShowSolid = not board.debugShowSolid
        else
            return "Usage: show-solid [on|off|toggle]"
        end
        return "Solid outlines " .. (board.debugShowSolid and "on" or "off") .. "."
    end)

    console:registerCommand("help", "list available commands", function(_, _, activeConsole)
        local names = {}
        for name in pairs(activeConsole.commands) do names[#names + 1] = name end
        table.sort(names)
        return "Commands: " .. table.concat(names, ", ")
    end)

    console:registerCommand("jump-to", "load a level by number or name (p = playground)", function(context, args)
        local query = args[1]
        if not query then return "Usage: jump-to <level number|name|p>" end

        local levels = LevelLoader.listLevels()
        local index, level = findLevelIndex(levels, query)
        if not index then return "Level not found: " .. query end

        local game = context and context.game
        if not game or not game.scenes then return "No game scene manager available." end
        local currentScene = context.scene
		if currentScene and currentScene.jumpToLevel then
			currentScene:jumpToLevel(index, levels)
        else
            game.scenes:switch("playing", index)
        end
        return "Jumped to " .. level.name .. "."
    end)
end

return ConsoleCommands
