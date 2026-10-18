local cameraLib = require("vendor.hump.camera")
local CharacterMovement = require("src.game.CharacterMovement")
local ActionHistory = require("src.game.ActionHistory")
local LevelLoader = require("src.game.LevelLoader")
local Keymap = require("src.settings.Keymap")

local Playing = {}
Playing.__index = Playing
local FOLLOW_ZOOM = 1.8
local CAMERA_SMOOTHING = 9
local MOVE_REPEAT_DELAY = 0.3
local MOVE_REPEAT_INTERVAL = 0.12

function Playing.new(game)
    return setmetatable({
        game = game,
        camera = cameraLib(0, 0, 1),
        history = ActionHistory(),
        levelIndex = 1,
        transition = nil,
        heldMoveKey = nil,
        moveRepeatTimer = 0,
    }, Playing)
end

function Playing:enter(levelIndex)
    self.levels = LevelLoader.listLevels()
    self.levelIndex = levelIndex or 1
    self.cameraMode = "map"
    self:loadLevel()
    self.paused = false
    self.pauseSelection = 1
end

function Playing:loadLevel()
    local level = assert(self.levels[self.levelIndex], "level index out of range")
    self.heldMoveKey = nil
    self.moveRepeatTimer = 0
    self.levelPath = level.path
    self.board = LevelLoader.load(level.path, self.game.assets)
    self.history:clear()
    self.activeIndex = 1
    self:snapCameraToTarget()
end

function Playing:mapCameraTarget()
    if not self.board then return 0, 0, 1 end
    local width, height = love.graphics.getDimensions()
    local minX, minY, maxX, maxY = self.board:getFilledBounds()
    minX, minY = minX or 0, minY or 0
    maxX, maxY = maxX or (self.board.width - 1), maxY or (self.board.height - 1)
    local worldWidth = (maxX - minX + 1) * 64
    local worldHeight = (maxY - minY + 1) * 64
    local zoom = math.min((width - 80) / worldWidth, (height - 130) / worldHeight) * 0.94
    return (minX + maxX + 1) * 32, (minY + maxY + 1) * 32, math.max(0.25, zoom)
end

function Playing:cameraTarget()
    if self.cameraMode == "map" then
        return self:mapCameraTarget()
    end
    local player = self:currentPlayer()
    if player then
        local transform = player:getComponent("Transform")
        return transform.x, transform.y, FOLLOW_ZOOM
    end
    return self:mapCameraTarget()
end

function Playing:snapCameraToTarget()
    local x, y, zoom = self:cameraTarget()
    self.camera:lookAt(x, y)
    self.camera.scale = zoom
end

function Playing:currentPlayer()
    if #self.board.players == 0 then return nil end
    return self.board.players[self.activeIndex]
end

function Playing:advanceLevel()
    if self.levelIndex < #self.levels then
        self.levelIndex = self.levelIndex + 1
        self:loadLevel()
        self.transition = {elapsed = 0, duration = 0.55}
    else
        self.completed = true
        self.paused = true
    end
end

function Playing:update(dt)
    if self.transition then
        self.transition.elapsed = self.transition.elapsed + dt
        if self.transition.elapsed >= self.transition.duration then self.transition = nil end
    end
    if self.board then self.board:update(dt) end
    self:updateHeldMovement(dt)
    if self.board then
        local targetX, targetY, targetZoom = self:cameraTarget()
        local smooth = 1 - math.exp(-CAMERA_SMOOTHING * dt)
        self.camera.x = self.camera.x + (targetX - self.camera.x) * smooth
        self.camera.y = self.camera.y + (targetY - self.camera.y) * smooth
        self.camera.scale = self.camera.scale + (targetZoom - self.camera.scale) * smooth
    end
    if not self.paused and self.board and not self.board:isMoving() and self.board:allBoxesOnTargets() then
        self:advanceLevel()
    end
end

function Playing:updateHeldMovement(dt)
    if not self.heldMoveKey then return end
    if not love.keyboard.isDown(self.heldMoveKey) then
        self.heldMoveKey = nil
        self.moveRepeatTimer = 0
        return
    end
    if self.paused then return end
    self.moveRepeatTimer = self.moveRepeatTimer - dt
    if self.moveRepeatTimer > 0 or self.transition or self.board:isMoving() then return end

    local direction = Keymap.direction(self.heldMoveKey)
    local player = self:currentPlayer()
    if direction and player then
        CharacterMovement.move(self.board, player, direction, self.history)
    end
    self.moveRepeatTimer = MOVE_REPEAT_INTERVAL
end

function Playing:draw()
    if not self.board then return end
    self.camera:attach()
    self.board:draw(self:currentPlayer())
    self.camera:detach()

    love.graphics.setColor(0.93, 0.93, 0.9, 1)
    local player = self:currentPlayer()
    if player then
        local characterClass = player:getComponent("CharacterClass").behavior
        love.graphics.print("Player: " .. characterClass.name .. "  (" .. Keymap.gameplayHint() .. ")", 16, 14)
    end
    love.graphics.print(self.levelPath or "", 16, 36)

    if self.paused then self:drawPause() end
    if self.transition then
        local progress = self.transition.elapsed / self.transition.duration
        local alpha = math.sin(math.min(progress, 1) * math.pi)
        love.graphics.setColor(0, 0, 0, alpha * 0.35)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    end
end

function Playing:drawPause()
    local width, height = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", width * 0.25, height * 0.2, width * 0.5, height * 0.6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self.completed and "All levels complete" or "Paused", 0, height * 0.27, width, "center")
    local options = {"Continue", "Restart", "Levels", "Quit"}
    for index, label in ipairs(options) do
        love.graphics.printf((index == self.pauseSelection and "> " or "  ") .. label, 0, height * 0.38 + (index - 1) * 32, width, "center")
    end
end

function Playing:choosePauseOption()
    if self.pauseSelection == 1 then
        self.paused, self.completed = false, false
    elseif self.pauseSelection == 2 then
        self:loadLevel()
        self.paused, self.completed = false, false
    elseif self.pauseSelection == 3 then
        self.game.scenes:switch("levels")
    else
        love.event.quit()
    end
end

function Playing:keypressed(key)
    if self.paused then
        if Keymap.matches("menuUp", key) then self.pauseSelection = (self.pauseSelection - 2) % 4 + 1
        elseif Keymap.matches("menuDown", key) then self.pauseSelection = self.pauseSelection % 4 + 1
        elseif Keymap.matches("confirm", key) then self:choosePauseOption()
        elseif Keymap.matches("cancel", key) and not self.completed then self.paused = false end
        return
    end
    if Keymap.matches("pause", key) then
        self.heldMoveKey = nil
        self.moveRepeatTimer = 0
        self.paused, self.pauseSelection = true, 1
        return
    end
    if Keymap.matches("toggleMapView", key) then
        self.cameraMode = self.cameraMode == "map" and "follow" or "map"
        return
    end
    local direction = Keymap.direction(key)
    if direction then
        self.heldMoveKey = key
        self.moveRepeatTimer = MOVE_REPEAT_DELAY
        if not self.board:isMoving() and not self.transition then
            local player = self:currentPlayer()
            if player then CharacterMovement.move(self.board, player, direction, self.history) end
        end
        return
    end
    if self.board:isMoving() or self.transition then return end
    if Keymap.matches("switchPlayer", key) then
        if #self.board.players > 0 then self.activeIndex = self.activeIndex % #self.board.players + 1 end
    elseif Keymap.matches("undo", key) then
        self.history:undo()
    end
end

return Playing
