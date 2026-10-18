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

function ConsoleCommands.register(console)
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
        if currentScene and currentScene.loadLevel and currentScene.levels then
            currentScene.levels = levels
            currentScene.levelIndex = index
            currentScene:loadLevel()
            currentScene.paused = false
            currentScene.completed = false
            currentScene.transition = {elapsed = 0, duration = 0.55}
        else
            game.scenes:switch("playing", index)
        end
        return "Jumped to " .. level.name .. "."
    end)
end

return ConsoleCommands
