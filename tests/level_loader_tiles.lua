local LevelLoader = require("src.game.LevelLoader")
local GameObject = require("src.core.GameObject")
local Transform = require("src.components.Transform")
local InteractiveObject = require("src.components.InteractiveObject")
local MovementSession = require("src.game.MovementSession")
local SpriteRenderer = require("src.components.SpriteRenderer")

local tests = {}

local function withTiledFiles(files, callback)
	local previousLove = love
	_G.love = {filesystem = {read = function(path) return files[path] end}}
	local ok, result = pcall(callback)
	_G.love = previousLove
	assert(ok, result)
end

local function makeAssets()
	local assets = {mapTiles = {}}
	function assets:mapTile(tileset, tileId)
		local tile = {image = tileset.image, id = tileId}
		self.mapTiles[#self.mapTiles + 1] = tile
		return tile.image, tile, tileset.tilewidth, tileset.tileheight
	end
	function assets:tileAnimation(tileX, tileY)
		return {x = tileX, y = tileY, update = function() end}
	end
	function assets:tileRenderer()
		return SpriteRenderer({}, 2, 1)
	end
	return assets
end

local function testMap()
	return [[{
		"orientation":"orthogonal", "infinite":false,
		"width":5, "height":2, "tilewidth":32, "tileheight":32,
		"layers":[
			{"name":"Visual", "type":"tilelayer", "width":5, "height":2,
				"data":[1,1,1,1,1,1,1,1,1,1]},
			{"name":"Terrain", "type":"tilelayer", "width":5, "height":2,
				"data":[0,2,0,0,3,0,0,4,0,0]},
			{"name":"Overlay", "type":"tilelayer", "width":5, "height":2,
				"data":[0,0,0,0,0,0,0,1,0,0]}
		],
		"tilesets":[
			{"firstgid":1, "name":"floor", "tilewidth":32, "tileheight":32,
				"tilecount":1, "columns":1, "image":"floor.png",
				"imagewidth":32, "imageheight":32},
			{"firstgid":2, "source":"terrain.tsx"}
		]
	}]]
end

local function terrainTileset()
	return [[<tileset name="terrain" tilewidth="32" tileheight="32" tilecount="3" columns="3">
		<image source="terrain-atlas.png" width="96" height="32"/>
		<tile id="0"><properties><property name="kind" value="water"/></properties></tile>
		<tile id="1"><properties><property name="kind" value="solid"/></properties></tile>
		<tile id="2"><properties><property name="kind" value="tall_grass"/></properties></tile>
	</tileset>]]
end

function tests.loader_renders_normal_tiles_from_their_own_tilesets_and_uses_kind_without_layer_rules()
	withTiledFiles({
		["maps/fixture.tmj"] = testMap(),
		["maps/terrain.tsx"] = terrainTileset(),
	}, function()
		local assets = makeAssets()
		local board = LevelLoader.load("maps/fixture.tmj", assets)

		assert(#board.renderTiles == 13, "terrain and untyped overlay tiles should remain visible")
		assert(assets.mapTiles[1].image == "maps/floor.png")
		assert(assets.mapTiles[11].image == "maps/terrain-atlas.png",
			"visual tiles should use the image from the Tiled tileset they came from")
		assert(board:getCell(0, 0).walkable)
		assert(not board:getCell(1, 0).walkable and board:getCell(1, 0).water,
			"water should block walking without becoming a solid wall")
		assert(not board:getCell(4, 0).walkable and board:getCell(4, 0).wall,
			"kind=solid should block walking regardless of layer name")
		local grass
		for _, object in ipairs(board.objects) do
			local transform = object:getComponent("Transform")
			if object:hasComponent("Grass") and transform.gridX == 2 and transform.gridY == 1 then
				grass = object
			end
		end
		assert(grass and grass:getComponent("Grass").state == "tall")
		assert(not board:canWalk(2, 1),
			"an untyped visual tile on a later layer must not make tall grass walkable")
		local grassApproach = GameObject("grass-approach")
		grassApproach:addComponent(Transform(1, 1))
		grassApproach:addComponent(InteractiveObject())
		board:addObject(grassApproach)
		assert(not MovementSession.new(board):enter(grassApproach, 2, 1),
			"movement must not enter tall grass after loading the map")

		local actor, object = GameObject("actor"), GameObject("object")
		actor:addComponent(Transform(0, 0))
		actor:addComponent(InteractiveObject())
		object:addComponent(Transform(3, 0))
		object:addComponent(InteractiveObject())
		board:addObject(actor)
		board:addObject(object)
		local movement = MovementSession.new(board)
		assert(not movement:canWalk(1, 0), "characters should not enter water")
		assert(movement:findInRay(1, 0, {x = 1, y = 0}, actor) == object,
			"water should not hide objects from a ray-searching ability")
	end)
end

return tests
