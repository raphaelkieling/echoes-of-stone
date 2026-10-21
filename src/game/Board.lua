local Node = require("src.core.Node")
local GameObject = require("src.core.GameObject")
local Transform = require("src.components.Transform")
local Animation = require("src.components.Animation")
local InteractiveObject = require("src.components.InteractiveObject")
local Player = require("src.components.Player")
local Box = require("src.components.Box")
local Target = require("src.components.Target")
local Bonfire = require("src.components.Bonfire")
local Shake = require("src.components.Shake")
local CharacterFactory = require("src.characters.CharacterFactory")

local DEBUG_CELL_SIZE = 64
local narrativeTriggerFont

local Board = Node:extend()

function Board:init(assets, width, height)
    Node.init(self, "Board")
    self.assets = assets
    self.width = width
    self.height = height
    self.cells = {}
    self.objects = {}
    self.players = {}
    self.boxes = {}
    self.targets = {}
    self.targetObjects = {}
    self.triggers = {}
    self.renderTiles = {}
    self.debugShowSolid = false
    self.debugShowUndoHistory = false
    self.debugShowNarrativeTriggers = false
    self.tiledMap = false
end

function Board:cellKey(x, y)
    return x .. ":" .. y
end

function Board:setCell(x, y, cell)
    self.cells[self:cellKey(x, y)] = cell
end

function Board:addMapTile(x, y, tileId)
    self.renderTiles[#self.renderTiles + 1] = {
        x = x,
        y = y,
        tileId = tileId,
        quad = self.assets:tileQuad(tileId),
    }
end

function Board:addTarget(x, y, tileId)
    local object = GameObject("Target")
    object:addComponent(Transform(x, y, 64, 1))
    object:addComponent(Target(self, self.assets, tileId))
    object:addComponent(self.assets:tileRenderer(2, 1))
    self.targets[#self.targets + 1] = {x = x, y = y, object = object}
    self.targetObjects[#self.targetObjects + 1] = object
    self:addChild(object)
    return object
end

function Board:addBonfire(x, y, tileset, state)
    local object = GameObject("Bonfire")
    object:addComponent(Transform(x, y, 64, 1))
    object:addComponent(InteractiveObject())
    object:addComponent(Bonfire(self.assets, tileset, state))
    object:addComponent(self.assets:tilesetRenderer(tileset, 2, 1))
    return self:addObject(object)
end

function Board:refreshTargetStates()
    for _, object in ipairs(self.targetObjects) do
        object:getComponent("Target"):refreshState()
    end
end

function Board:getCell(x, y)
    return self.cells[self:cellKey(x, y)]
end

function Board:getFilledBounds()
    local minX, minY, maxX, maxY
    for key in pairs(self.cells) do
        local x, y = key:match("^(-?%d+):(-?%d+)$")
        x, y = tonumber(x), tonumber(y)
        minX = minX and math.min(minX, x) or x
        minY = minY and math.min(minY, y) or y
        maxX = maxX and math.max(maxX, x) or x
        maxY = maxY and math.max(maxY, y) or y
    end
    if not minX then return nil end
    return minX, minY, maxX, maxY
end

function Board:canWalk(x, y)
    local cell = self:getCell(x, y)
    return cell ~= nil and cell.walkable == true and not cell.wall
end

function Board:addObject(object)
    if object:hasComponent("InteractiveObject")
        and object:hasComponent("SpriteRenderer")
        and not object:hasComponent("Shake") then
        object:addComponent(Shake())
    end
    self.objects[#self.objects + 1] = object
    self:addChild(object)
    if object:hasComponent("Player") then
        self.players[#self.players + 1] = object
    elseif object:hasComponent("Box") then
        self.boxes[#self.boxes + 1] = object
    end
    return object
end

function Board:addTrigger(object, trigger)
    self.triggers[#self.triggers + 1] = {object = object, component = trigger}
    self:addChild(object)
    return object
end

function Board:processMovement(changes)
    if not self.events then return end
    for _, change in ipairs(changes or {}) do
        for _, entry in ipairs(self.triggers) do
            entry.component:onObjectMoved(change, self.events)
        end
    end
end

function Board:spawnPlayer(classId, x, y)
    return self:addObject(CharacterFactory.create(classId, x, y, self.assets))
end

function Board:spawnBox(x, y, tileId)
    tileId = tileId or (6 + 17 * 17)
    local tileX = tileId % 17
    local tileY = math.floor(tileId / 17)
    local object = GameObject("Box")
    object:addComponent(Transform(x, y, 64, 2))
    object:addComponent(InteractiveObject())
    object:addComponent(Box())
    object:addComponent(Animation(self.assets:tileAnimation(tileX, tileY)))
    object:addComponent(self.assets:tileRenderer(2, 2))
    return self:addObject(object)
end

function Board:getInteractiveAt(x, y, positions, except)
    for _, object in ipairs(self.objects) do
        if object ~= except and object:hasComponent("InteractiveObject") then
            local position = positions and positions[object]
            if not position then
                local transform = object:getComponent("Transform")
                position = {x = transform.gridX, y = transform.gridY}
            end
            if position.x == x and position.y == y then
                return object
            end
        end
    end
    return nil
end

function Board:isMoving()
    for _, object in ipairs(self.objects) do
        if object:getComponent("Transform"):isMoving() then
            return true
        end
    end
    return false
end

function Board:isBoxAt(x, y)
    for _, box in ipairs(self.boxes) do
        local transform = box:getComponent("Transform")
        if transform.gridX == x and transform.gridY == y then
            return true
        end
    end
    return false
end

function Board:update(dt)
    self:updateChildren(dt)
end

function Board:draw(activePlayer)
	local sceneContext = activePlayer
    if activePlayer and type(activePlayer.currentPlayer) == "function" then
        activePlayer = activePlayer:currentPlayer()
    end
    if self.tiledMap then
        for _, tile in ipairs(self.renderTiles) do
            love.graphics.draw(self.assets.tiles, tile.quad,
                (tile.x + 0.5) * 64, (tile.y + 0.5) * 64, 0, 2, 2, 16, 16)
        end
    else
        local floorQuad = self.assets.tileGrid(1, 1)[1]
        local wallQuad = self.assets.tileGrid(2, 1)[1]
        for y = 0, self.height - 1 do
            for x = 0, self.width - 1 do
                local cell = self:getCell(x, y)
                if cell then
                    local screenX, screenY = (x + 0.5) * 64, (y + 0.5) * 64
                    if cell.walkable then
                        love.graphics.draw(self.assets.tiles, floorQuad, screenX, screenY, 0, 2, 2, 16, 16)
                    elseif cell.wall then
                        love.graphics.draw(self.assets.tiles, wallQuad, screenX, screenY, 0, 2, 2, 16, 16)
                    end
                end
            end
        end
    end

    if activePlayer then
        local characterClass = activePlayer:getComponent("CharacterClass")
        if characterClass and characterClass.id == Player.Classes.MYSTERIOUS_PRIEST then
            local transform = activePlayer:getComponent("Transform")
            local pulse = (math.sin(love.timer.getTime() * 3.2) + 1) / 2
            local auraSize = transform.cellSize * 3 * (0.96 + pulse * 0.04)
            local cornerRadius = transform.cellSize * (0.12 + pulse * 0.02)
            love.graphics.push("all")
            love.graphics.setColor(0.35, 0.9, 1, 0.5 + pulse * 0.28)
            love.graphics.setLineWidth(1.5 + pulse * 1.1)
            love.graphics.rectangle("line",
                transform.x - auraSize / 2,
                transform.y - auraSize / 2,
                auraSize,
                auraSize,
                cornerRadius,
                cornerRadius,
                8)
            love.graphics.pop()
        end
    end

    local drawOrder = {}
    for _, object in ipairs(self.objects) do
        drawOrder[#drawOrder + 1] = object
    end
    for _, object in ipairs(self.targetObjects) do
        drawOrder[#drawOrder + 1] = object
    end
    table.sort(drawOrder, function(a, b)
        return a:getComponent("SpriteRenderer").renderLayer < b:getComponent("SpriteRenderer").renderLayer
    end)

    self.activePlayer = activePlayer or self.activePlayer
    for _, object in ipairs(drawOrder) do
        object:draw({selected = object == activePlayer})
    end

    if self.debugShowSolid then
        love.graphics.push("all")
        love.graphics.setColor(1, 0.24, 0.18, 0.9)
        love.graphics.setLineWidth(2)
        for key, cell in pairs(self.cells) do
            if cell.wall then
                local x, y = key:match("^(-?%d+):(-?%d+)$")
                love.graphics.rectangle("line", tonumber(x) * 64 + 2, tonumber(y) * 64 + 2, 60, 60)
            end
        end
        for _, object in ipairs(self.objects) do
            if object:hasComponent("InteractiveObject") then
                local transform = object:getComponent("Transform")
                local size = transform.cellSize - 4
                love.graphics.rectangle("line", transform.x - size / 2, transform.y - size / 2, size, size)
            end
        end
        love.graphics.pop()
    end

	if self.debugShowNarrativeTriggers then
		self:drawNarrativeTriggers(sceneContext and sceneContext.camera)
	end
end

function Board:drawNarrativeTriggers(camera)
	if #self.triggers == 0 then return end
	narrativeTriggerFont = narrativeTriggerFont or love.graphics.newFont(14)
	local zoom = camera and camera.scale or 1
	local inverseZoom = zoom > 0 and 1 / zoom or 1
	local labelPadding = 3 * inverseZoom
	local cellSize = self.objects[1]
		and self.objects[1]:getComponent("Transform").cellSize or DEBUG_CELL_SIZE

	love.graphics.push("all")
	love.graphics.setFont(narrativeTriggerFont)
	love.graphics.setLineWidth(2 * inverseZoom)
	for _, entry in ipairs(self.triggers) do
		local trigger = entry.component
		local red, green, blue = trigger.debugColor[1], trigger.debugColor[2], trigger.debugColor[3]
		love.graphics.setColor(red, green, blue, 0.92)
		for _, cell in ipairs(trigger:getDebugCells()) do
			love.graphics.rectangle("line", cell.x * cellSize + 2, cell.y * cellSize + 2,
				cellSize - 4, cellSize - 4)
		end

		local labelX, labelY = trigger:getDebugLabelPosition(cellSize)
		local labelWidth = narrativeTriggerFont:getWidth(trigger.narrativeId) * inverseZoom
		local labelHeight = narrativeTriggerFont:getHeight() * inverseZoom
		labelY = labelY - labelHeight - 4 * inverseZoom
		love.graphics.setColor(0, 0, 0, 0.88)
		love.graphics.rectangle("fill", labelX, labelY,
			labelWidth + labelPadding * 2, labelHeight + labelPadding * 2)
		love.graphics.setColor(red, green, blue, 1)
		love.graphics.print(trigger.narrativeId, labelX + labelPadding,
			labelY + labelPadding, 0, inverseZoom, inverseZoom)
	end
	love.graphics.pop()
end

function Board:allTargetsCovered()
    if #self.targets == 0 then return false end

    local occupiedPositions = {}
    for _, box in ipairs(self.boxes) do
        local transform = box:getComponent("Transform")
        occupiedPositions[self:cellKey(transform.gridX, transform.gridY)] = true
    end

    for _, target in ipairs(self.targets) do
        if not occupiedPositions[self:cellKey(target.x, target.y)] then
            return false
        end
    end
    return true
end

function Board:hasMovingObjects()
    return self:isMoving()
end

return Board
