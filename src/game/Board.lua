local Class = require("src.core.Class")
local GameObject = require("src.core.GameObject")
local Transform = require("src.components.Transform")
local SpriteRenderer = require("src.components.SpriteRenderer")
local InteractiveObject = require("src.components.InteractiveObject")
local Player = require("src.components.Player")
local Box = require("src.components.Box")

local Board = Class:extend()

local PLAYER_SPRITES = {
    [Player.Classes.DWARF] = {0, 0},
    [Player.Classes.WIZARD] = {1, 4},
    [Player.Classes.WARRIOR] = {4, 1},
    [Player.Classes.TELEKINETIC] = {2, 0},
    [Player.Classes.SORCERER] = {3, 4},
}

function Board:init(assets, width, height)
    self.assets = assets
    self.width = width
    self.height = height
    self.cells = {}
    self.objects = {}
    self.players = {}
    self.boxes = {}
    self.targets = {}
end

function Board:cellKey(x, y)
    return x .. ":" .. y
end

function Board:setCell(x, y, cell)
    self.cells[self:cellKey(x, y)] = cell
end

function Board:getCell(x, y)
    return self.cells[self:cellKey(x, y)]
end

function Board:canWalk(x, y)
    local cell = self:getCell(x, y)
    return cell ~= nil and cell.walkable == true and not cell.wall
end

function Board:addObject(object)
    self.objects[#self.objects + 1] = object
    if object:hasComponent("Player") then
        self.players[#self.players + 1] = object
    elseif object:hasComponent("Box") then
        self.boxes[#self.boxes + 1] = object
    end
    return object
end

function Board:spawnPlayer(className, x, y)
    local spriteCoords = assert(PLAYER_SPRITES[className], "unknown player class: " .. tostring(className))
    local object = GameObject("Player " .. className)
    object:addComponent(Transform(x, y, 64, 3))
    object:addComponent(InteractiveObject())
    object:addComponent(Player(className))
    object:addComponent(self.assets:playerRenderer(spriteCoords[1], spriteCoords[2]))
    return self:addObject(object)
end

function Board:spawnBox(x, y)
    local object = GameObject("Box")
    object:addComponent(Transform(x, y, 64, 2))
    object:addComponent(InteractiveObject())
    object:addComponent(Box())
    object:addComponent(self.assets:tileRenderer(6, 17, 2, 2))
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
                    -- Wall uses tiles.png at column 1, row 0 (zero-based).
                    love.graphics.draw(self.assets.tiles, wallQuad, screenX, screenY, 0, 2, 2, 16, 16)
                end
            end
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
