local Class = require("src.core.Class")
local GameObject = require("src.core.GameObject")
local Transform = require("src.components.Transform")
local Animation = require("src.components.Animation")
local InteractiveObject = require("src.components.InteractiveObject")
local Player = require("src.components.Player")
local Box = require("src.components.Box")
local Shake = require("src.components.Shake")
local CharacterFactory = require("src.characters.CharacterFactory")

local Board = Class:extend()

function Board:init(assets, width, height)
    self.assets = assets
    self.width = width
    self.height = height
    self.cells = {}
    self.objects = {}
    self.players = {}
    self.boxes = {}
    self.targets = {}
    self.renderTiles = {}
    self.debugShowSolid = false
    self.debugShowUndoHistory = false
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
        quad = self.assets:tileQuad(tileId),
    }
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
    if object:hasComponent("Player") then
        self.players[#self.players + 1] = object
    elseif object:hasComponent("Box") then
        self.boxes[#self.boxes + 1] = object
    end
    return object
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

function Board:update(dt)
    for _, object in ipairs(self.objects) do
        object:update(dt)
    end
end

function Board:draw(activePlayer)
    if self.tiledMap then
        for _, tile in ipairs(self.renderTiles) do
            love.graphics.draw(self.assets.tiles, tile.quad,
                (tile.x + 0.5) * 64, (tile.y + 0.5) * 64, 0, 2, 2, 16, 16)
        end
    else
        local floorQuad = self.assets.tileGrid(1, 1)[1]
        local wallQuad = self.assets.tileGrid(2, 1)[1]
        local targetQuad = self.assets.tileGrid(10, 17)[1]
        for y = 0, self.height - 1 do
            for x = 0, self.width - 1 do
                local cell = self:getCell(x, y)
                if cell then
                    local screenX, screenY = (x + 0.5) * 64, (y + 0.5) * 64
                    if cell.walkable then
                        love.graphics.draw(self.assets.tiles, floorQuad, screenX, screenY, 0, 2, 2, 16, 16)
                        if cell.target then
                            love.graphics.draw(self.assets.tiles, targetQuad, screenX, screenY, 0, 2, 2, 16, 16)
                        end
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
end

function Board:allBoxesOnTargets()
    if #self.boxes == 0 then
        return false
    end
    local targetPositions = {}
    for _, target in ipairs(self.targets) do
        targetPositions[self:cellKey(target.x, target.y)] = true
    end
    for _, box in ipairs(self.boxes) do
        local transform = box:getComponent("Transform")
        if not targetPositions[self:cellKey(transform.gridX, transform.gridY)] then
            return false
        end
    end
    return true
end

function Board:hasMovingObjects()
    return self:isMoving()
end

return Board
