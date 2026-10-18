local ConsoleCommands = {}

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
end

return ConsoleCommands
