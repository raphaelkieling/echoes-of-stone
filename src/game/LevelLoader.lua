local Board = require("src.game.Board")
local Player = require("src.components.Player")

local LevelLoader = {}

local PLAYER_MARKERS = {
    ["1"] = Player.Classes.DWARF,
    ["2"] = Player.Classes.WIZARD,
    ["3"] = Player.Classes.WARRIOR,
    ["4"] = Player.Classes.TELEKINETIC,
    ["5"] = Player.Classes.SORCERER,
}

function LevelLoader.listLevels()
    local files = love.filesystem.getDirectoryItems("maps")
    local levels = {}
    for _, file in ipairs(files) do
        local number = file:match("^lvl_(%d+)%.txt$")
        if number then
            levels[#levels + 1] = {number = tonumber(number), path = "maps/" .. file}
        end
    end
    table.sort(levels, function(a, b)
        return a.number < b.number
    end)
    return levels
end

function LevelLoader.load(path, assets)
    local contents, readError = love.filesystem.read(path)
    assert(contents, "failed to read " .. path .. ": " .. tostring(readError))

    local rows = {}
    local width = 0
    for line in contents:gmatch("([^\r\n]+)") do
        rows[#rows + 1] = line
        width = math.max(width, #line)
    end
    assert(#rows > 0 and width > 0, "level is empty: " .. path)

    local board = Board(assets, width, #rows)
    for row, line in ipairs(rows) do
        local y = row - 1
        for x = 0, width - 1 do
            local marker = line:sub(x + 1, x + 1)
            if marker == "W" then
                board:setCell(x, y, {walkable = false, wall = true})
            elseif marker == "#" or marker == "*" then
                board:setCell(x, y, {walkable = true, target = marker == "*"})
                if marker == "*" then
                    board.targets[#board.targets + 1] = {x = x, y = y}
                end
                board:spawnBox(x, y)
            elseif marker == "F" then
                board:setCell(x, y, {walkable = true, target = true})
                board.targets[#board.targets + 1] = {x = x, y = y}
            elseif PLAYER_MARKERS[marker] then
                board:setCell(x, y, {walkable = true})
                board:spawnPlayer(PLAYER_MARKERS[marker], x, y)
            elseif marker == " " then
                board:setCell(x, y, {walkable = true})
            end
        end
    end

    return board
end

return LevelLoader
