local Board = require("src.game.Board")
local Player = require("src.components.Player")
local json = require("vendor.json")

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
    local tiledLevels = {}
    local textLevels = {}
    for _, file in ipairs(files) do
        if file:match("%.tmj$") then
            local name = file:gsub("%.tmj$", ""):gsub("%.tmx$", "")
            tiledLevels[#tiledLevels + 1] = {
                number = tonumber(name:match("(%d+)$")),
                name = name,
                path = "maps/" .. file,
            }
        end
        local number = file:match("^lvl_(%d+)%.txt$")
        if number then
            textLevels[#textLevels + 1] = {
                number = tonumber(number),
                name = file,
                path = "maps/" .. file,
            }
        end
    end
    local levels = #tiledLevels > 0 and tiledLevels or textLevels
    table.sort(levels, function(a, b)
        if a.number and b.number then return a.number < b.number end
        if a.number ~= b.number then return a.number ~= nil end
        return a.name < b.name
    end)
    return levels
end

local function propertiesByName(properties)
    local result = {}
    for _, property in ipairs(properties or {}) do
        result[property.name] = property.value
    end
    return result
end

local function makeTilesetMetadata(map)
    local result = {}
    for _, tileset in ipairs(map.tilesets or {}) do
        for _, tile in ipairs(tileset.tiles or {}) do
            result[tileset.firstgid + tile.id] = {
                id = tile.id,
                properties = propertiesByName(tile.properties),
            }
        end
    end
    return result
end

local function cleanGid(gid)
    -- Tiled reserves the top four bits for horizontal/vertical/diagonal flips.
    return (gid or 0) % 0x10000000
end

local function loadTiled(path, assets)
    local contents, readError = love.filesystem.read(path)
    assert(contents, "failed to read " .. path .. ": " .. tostring(readError))
    local map = json.decode(contents)
    assert(map.orientation == "orthogonal", "only orthogonal Tiled maps are supported: " .. path)
    assert(not map.infinite, "infinite Tiled maps are not supported: " .. path)
    assert(map.width and map.height and map.tilewidth and map.tileheight,
        "Tiled map is missing dimensions: " .. path)

    local board = Board(assets, map.width, map.height)
    board.tiledMap = true
    local metadata = makeTilesetMetadata(map)
    local markedObjects = {}

    for _, layer in ipairs(map.layers or {}) do
        if layer.visible ~= false and layer.type == "tilelayer" then
            assert(type(layer.data) == "table", "expected uncompressed tile data in layer " .. layer.name)
            local layerWidth = layer.width or map.width
            for index, rawGid in ipairs(layer.data) do
                local gid = cleanGid(rawGid)
                if gid ~= 0 then
                    local x = ((index - 1) % layerWidth) + (layer.x or 0)
                    local y = math.floor((index - 1) / layerWidth) + (layer.y or 0)
                    local tileset = metadata[gid]
                    local properties = tileset and tileset.properties or {}
                    local kind = properties.kind
                    local cell = board:getCell(x, y) or {walkable = false, wall = false, target = false}

                    if layer.name == "Ground" and not properties.solid then
                        cell.walkable = true
                    end
                    if properties.solid then
                        cell.walkable = false
                        cell.wall = true
                    end
                    board:setCell(x, y, cell)

                    if kind == "box" or kind == "target" then
                        markedObjects[#markedObjects + 1] = {
                            x = x, y = y, kind = kind, tileId = tileset.id,
                        }
                    elseif kind ~= "player" then
                        board:addMapTile(x, y, tileset and tileset.id or (gid - 1))
                    end
                end
            end
        elseif layer.visible ~= false and layer.type == "objectgroup" then
            for _, object in ipairs(layer.objects or {}) do
                local properties = propertiesByName(object.properties)
                local kind = properties.kind or object.type or object.class or object.name
                local x = math.floor((object.x or 0) / map.tilewidth)
                local y = math.floor((object.y or 0) / map.tileheight)
                if kind == "player" then
                    local classId = properties.characterClass
                    assert(classId, "player object is missing characterClass in " .. path)
                    assert(board:canWalk(x, y), "player must be placed on walkable ground in " .. path)
                    board:spawnPlayer(classId, x, y)
                elseif kind == "box" or kind == "target" then
                    markedObjects[#markedObjects + 1] = {x = x, y = y, kind = kind}
                end
            end
        end
    end

    for _, marker in ipairs(markedObjects) do
        local cell = board:getCell(marker.x, marker.y)
        assert(cell and cell.walkable and not cell.wall,
            marker.kind .. " must be placed on walkable ground in " .. path)
        if marker.kind == "box" then
            board:spawnBox(marker.x, marker.y, marker.tileId)
        else
            cell.target = true
            board.targets[#board.targets + 1] = {x = marker.x, y = marker.y}
            if marker.tileId then
                board:addMapTile(marker.x, marker.y, marker.tileId)
            end
        end
    end

    return board
end

function LevelLoader.load(path, assets)
    if path:match("%.tmj$") then
        return loadTiled(path, assets)
    end

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
