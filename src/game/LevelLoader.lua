local Board = require("src.game.Board")
local GameObject = require("src.core.GameObject")
local Player = require("src.components.Player")
local CharacterClasses = require("src.characters.Classes")
local PointTrigger = require("src.components.triggers.PointTrigger")
local AreaTrigger = require("src.components.triggers.AreaTrigger")
local json = require("vendor.json")

local LevelLoader = {}

local PLAYER_MARKERS = {
    ["1"] = Player.Classes.DWARF,
    ["2"] = Player.Classes.WIZARD,
    ["3"] = Player.Classes.WARRIOR,
    ["4"] = Player.Classes.TELEKINETIC,
    ["5"] = Player.Classes.SORCERER,
    ["6"] = Player.Classes.MYSTERIOUS_PRIEST,
    ["7"] = Player.Classes.FARMER,
}

local PLAYER_CLASS_IDS = {
    Player.Classes.DWARF,
    Player.Classes.WIZARD,
    Player.Classes.WARRIOR,
    Player.Classes.TELEKINETIC,
    Player.Classes.SORCERER,
    Player.Classes.MYSTERIOUS_PRIEST,
    Player.Classes.FARMER,
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

local function xmlAttributes(source)
	local attributes = {}
	for name, value in source:gmatch('([%w_:%-]+)%s*=%s*"([^"]*)"') do
		attributes[name] = value
	end
	for name, value in source:gmatch("([%w_:%-]+)%s*=%s*'([^']*)'") do
		attributes[name] = value
	end
	return attributes
end

local function typedProperty(attributes, body)
	local value = attributes.value
	if value == nil then value = (body or ""):match("^%s*(.-)%s*$") end
	if attributes.type == "bool" then return value == "true" end
	if attributes.type == "int" or attributes.type == "float" then
		return tonumber(value) or value
	end
	return value
end

local function propertiesFromXml(source)
	local properties = {}
	local propertyBlock = source:match("<properties[^>]*>(.-)</properties>") or source
	for rawAttributes, body in propertyBlock:gmatch("<property%s+([^>]-)>(.-)</property>") do
		local attributes = xmlAttributes(rawAttributes)
		properties[#properties + 1] = {
			name = attributes.name,
			value = typedProperty(attributes, body),
		}
	end
	for rawAttributes in propertyBlock:gmatch("<property%s+([^>]-)/%s*>") do
		local attributes = xmlAttributes(rawAttributes)
		properties[#properties + 1] = {
			name = attributes.name,
			value = typedProperty(attributes),
		}
	end
	return properties
end

local function normalizePath(path)
	local parts = {}
	for part in (path:gsub("\\", "/")):gmatch("[^/]+") do
		if part == ".." then
			if #parts > 0 then table.remove(parts) end
		elseif part ~= "." then
			parts[#parts + 1] = part
		end
	end
	return table.concat(parts, "/")
end

local function resolveRelativePath(filePath, relativePath)
	local directory = filePath:match("^(.*)/[^/]+$") or ""
	return normalizePath(directory ~= "" and (directory .. "/" .. relativePath) or relativePath)
end

local function parseTsxTileset(sourcePath, firstgid)
	local contents, readError = love.filesystem.read(sourcePath)
	assert(contents, "failed to read external tileset " .. sourcePath .. ": " .. tostring(readError))
	local root = contents:match("<tileset%s+([^>]-)>")
	assert(root, "invalid TSX tileset: " .. sourcePath)
	local attributes = xmlAttributes(root)
	local imageTag = contents:match("<image%s+([^>]-)/?%s*>")
	local image = imageTag and xmlAttributes(imageTag) or {}
	local tiles = {}
	for rawTileAttributes, body in contents:gmatch("<tile%s+([^>]-)>(.-)</tile>") do
		local tileAttributes = xmlAttributes(rawTileAttributes)
		local id = tonumber(tileAttributes.id)
		if id then
			tiles[#tiles + 1] = {id = id, properties = propertiesFromXml(body)}
		end
	end

	local tileWidth = tonumber(attributes.tilewidth)
	local tileHeight = tonumber(attributes.tileheight)
	local imageWidth = tonumber(image.width)
	local imageHeight = tonumber(image.height)
	local columns = tonumber(attributes.columns)
	return {
		firstgid = firstgid,
		name = attributes.name,
		tilewidth = tileWidth,
		tileheight = tileHeight,
		tilecount = tonumber(attributes.tilecount)
			or (imageWidth and imageHeight and tileWidth and tileHeight
				and math.floor(imageWidth / tileWidth) * math.floor(imageHeight / tileHeight)),
		columns = columns or (imageWidth and tileWidth and math.floor(imageWidth / tileWidth)),
		objectalignment = attributes.objectalignment,
		image = image.source and resolveRelativePath(sourcePath, image.source),
		imagewidth = imageWidth,
		imageheight = imageHeight,
		tiles = tiles,
		source = sourcePath,
	}
end

local function resolveTilesets(mapPath, tilesets)
	local mapDirectory = mapPath:match("^(.*)/[^/]+$") or ""
	local resolved = {}
	for _, tileset in ipairs(tilesets or {}) do
		if not tileset.source then
			if tileset.image then
				tileset.image = resolveRelativePath(mapPath, tileset.image)
			end
			resolved[#resolved + 1] = tileset
		else
			local sourcePath = mapDirectory ~= "" and (mapDirectory .. "/" .. tileset.source) or tileset.source
			local lowerPath = sourcePath:lower()
			if lowerPath:match("%.tsx$") then
				resolved[#resolved + 1] = parseTsxTileset(sourcePath, tileset.firstgid)
			elseif lowerPath:match("%.tsj$") or lowerPath:match("%.json$") then
				local contents, readError = love.filesystem.read(sourcePath)
				assert(contents, "failed to read external tileset " .. sourcePath .. ": " .. tostring(readError))
				local external = json.decode(contents)
				external.firstgid = tileset.firstgid
				external.source = sourcePath
				if external.image then
					external.image = resolveRelativePath(sourcePath, external.image)
				end
				resolved[#resolved + 1] = external
			else
				assert(false, "unsupported external tileset format: " .. sourcePath)
			end
		end
	end
	return resolved
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

local function tilesetForGid(map, gid)
    if gid <= 0 then return nil end
    for index = #(map.tilesets or {}), 1, -1 do
        local tileset = map.tilesets[index]
        if gid >= tileset.firstgid and gid < tileset.firstgid + (tileset.tilecount or 0) then
            return tileset
        end
    end
end

local function isRoguesTileset(tileset)
    if not tileset then return false end
    local imageName = (tileset.image or ""):match("[^/\\]+$") or ""
    return (tileset.name or ""):lower() == "rogues" or imageName:lower() == "rogues.png"
end

local function classForRogueTile(tileset, gid)
    if not isRoguesTileset(tileset) then return nil end
    local columns = tileset.columns or math.floor(tileset.imagewidth / tileset.tilewidth)
    local tileId = gid - tileset.firstgid
    local tileX = tileId % columns
    local tileY = math.floor(tileId / columns)
    for _, classId in ipairs(PLAYER_CLASS_IDS) do
        local sprite = CharacterClasses.create(classId).sprite
        if sprite.x == tileX and sprite.y == tileY then
            return classId, tileX, tileY
        end
    end
    return nil, tileX, tileY
end

local function objectGridPosition(object, map, tileset)
    local x, y = object.x or 0, object.y or 0
    if not object.gid then
        return math.floor(x / map.tilewidth), math.floor(y / map.tileheight)
    end

    local width = object.width or (tileset and tileset.tilewidth) or map.tilewidth
    local height = object.height or (tileset and tileset.tileheight) or map.tileheight
    local alignment = (tileset and tileset.objectalignment) or "unspecified"
    if alignment == "unspecified" then alignment = "bottomleft" end

    local left = x
    if alignment:find("right", 1, true) then
        left = x - width
    elseif alignment == "center" or alignment == "top" or alignment == "bottom" then
        left = x - width / 2
    end

    local top = y
    if alignment:find("bottom", 1, true) then
        top = y - height
    elseif alignment == "center" or alignment == "left" or alignment == "right" then
        top = y - height / 2
    end
    return math.floor(left / map.tilewidth), math.floor(top / map.tileheight)
end

local function loadTiled(path, assets, events)
    local contents, readError = love.filesystem.read(path)
    assert(contents, "failed to read " .. path .. ": " .. tostring(readError))
    local map = json.decode(contents)
    assert(map.orientation == "orthogonal", "only orthogonal Tiled maps are supported: " .. path)
    assert(not map.infinite, "infinite Tiled maps are not supported: " .. path)
    assert(map.width and map.height and map.tilewidth and map.tileheight,
        "Tiled map is missing dimensions: " .. path)
    map.tilesets = resolveTilesets(path, map.tilesets)

    local board = Board(assets, map.width, map.height)
    board.tiledMap = true
    board.events = events
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
                    local tileset = tilesetForGid(map, gid)
                    assert(tileset, string.format("tile GID %d in layer %s has no tileset in %s", gid, layer.name, path))
                    local tileMetadata = metadata[gid]
                    local properties = tileMetadata and tileMetadata.properties or {}
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

                    if kind == "grass" or kind == "tall_grass" then
                        board:addGrass(x, y, kind)
                    elseif kind == "bonfire" then
                        board:addBonfire(x, y, tileset, properties.state)
                    elseif kind == "box" or kind == "target" then
                        markedObjects[#markedObjects + 1] = {
                            x = x, y = y, kind = kind,
                            tileId = tileMetadata and tileMetadata.id or (gid - tileset.firstgid),
                        }
                    elseif kind == "player" or isRoguesTileset(tileset) then
                        local classId = properties.characterClass or classForRogueTile(tileset, gid)
                        assert(classId, string.format(
                            "player tile in %s does not match a configured character sprite (tile %d)",
                            path, gid - tileset.firstgid))
                        assert(board:canWalk(x, y), "player must be placed on walkable ground in " .. path)
                        board:spawnPlayer(classId, x, y)
                    elseif kind ~= "player" then
                        board:addMapTile(x, y, tileMetadata and tileMetadata.id or (gid - tileset.firstgid))
                    end
                end
            end
        elseif layer.visible ~= false and layer.type == "objectgroup" then
            for _, object in ipairs(layer.objects or {}) do
                local properties = propertiesByName(object.properties)
                local gid = cleanGid(object.gid)
                local tileset = tilesetForGid(map, gid)
                local tileMetadata = metadata[gid]
                local classIdFromSprite = classForRogueTile(tileset, gid)
                local kind = properties.kind
                    or (tileMetadata and tileMetadata.properties.kind)
                    or (isRoguesTileset(tileset) and "player")
                    or object.type or object.class or object.name
                if type(kind) == "string" then kind = kind:lower() end
                local x, y = objectGridPosition(object, map, tileset)

                local narrativeId = properties.narrative_trigger

                if narrativeId and narrativeId ~= "" then
                    local triggerObject = GameObject("Narrative trigger: " .. narrativeId)
                    local trigger
                    local options = {once = properties.trigger_once}
                    if object.point then
                        trigger = PointTrigger(narrativeId, x, y, options)
                    elseif object.width and object.height and object.width > 0 and object.height > 0
                        and not object.ellipse and not object.polygon and not object.polyline then
                        trigger = AreaTrigger(narrativeId, object.x or 0, object.y or 0,
                            object.width, object.height, map.tilewidth, map.tileheight, options)
                    else
                        assert(false, string.format(
                            "narrative trigger '%s' in %s must be a Tiled point or rectangle",
                            narrativeId, path))
                    end
                    triggerObject:addComponent(trigger)
                    board:addTrigger(triggerObject, trigger)
                end

                if kind == "player" then
                    local classId = properties.characterClass or classIdFromSprite
                    assert(classId, string.format(
                        "player tile in %s does not match a configured character sprite (tile %d)",
                        path, gid - (tileset and tileset.firstgid or 1)))
                    assert(board:canWalk(x, y), "player must be placed on walkable ground in " .. path)
                    board:spawnPlayer(classId, x, y)
                elseif kind == "bonfire" then
                    board:addBonfire(x, y, tileset, properties.state)
                elseif kind == "grass" or kind == "tall_grass" then
                    board:addGrass(x, y, kind)
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
            board:addTarget(marker.x, marker.y, marker.tileId)
        end
    end

    board:refreshTargetStates()
    return board
end

function LevelLoader.load(path, assets, events)
    if path:match("%.tmj$") then
        return loadTiled(path, assets, events)
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
                    board:addTarget(x, y)
                end
                board:spawnBox(x, y)
            elseif marker == "F" then
                board:setCell(x, y, {walkable = true, target = true})
                board:addTarget(x, y)
            elseif PLAYER_MARKERS[marker] then
                board:setCell(x, y, {walkable = true})
                board:spawnPlayer(PLAYER_MARKERS[marker], x, y)
            elseif marker == " " then
                board:setCell(x, y, {walkable = true})
            end
        end
    end

    board:refreshTargetStates()
    return board
end

return LevelLoader
