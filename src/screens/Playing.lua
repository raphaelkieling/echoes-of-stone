local cameraLib = require("vendor.hump.camera")
local CharacterMovement = require("src.game.CharacterMovement")
local ActionHistory = require("src.game.ActionHistory")
local LevelLoader = require("src.game.LevelLoader")

local Playing = {}
Playing.__index = Playing

local DIRECTIONS = {
    up = {x = 0, y = -1}, w = {x = 0, y = -1},
    down = {x = 0, y = 1}, s = {x = 0, y = 1},
    left = {x = -1, y = 0}, a = {x = -1, y = 0},
    right = {x = 1, y = 0}, d = {x = 1, y = 0},
}

function Playing.new(game)
    return setmetatable({game = game, camera = cameraLib(0, 0, 1), history = ActionHistory(), levelIndex = 1, transition = nil}, Playing)
end

function Playing:enter(levelIndex)
    self.levels = LevelLoader.listLevels()
    self.levelIndex = levelIndex or 1
    self:loadLevel()
    self.paused = false
    self.pauseSelection = 1
end

function Playing:loadLevel()
    local level = assert(self.levels[self.levelIndex], "level index out of range")
    self.levelPath = level.path
    self.board = LevelLoader.load(level.path, self.game.assets)
    self.history:clear()
    self.activeIndex = 1
    self:fitCamera()
end

function Playing:fitCamera()
    if not self.board then return end
    local width, height = love.graphics.getDimensions()
    local zoom = math.min((width - 80) / (self.board.width * 64), (height - 130) / (self.board.height * 64)) * 1.12
    self.camera:lookAt(self.board.width * 32, self.board.height * 32)
    self.camera.scale = math.max(0.25, zoom)
end

function Playing:resize()
    self:fitCamera()
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
    if not self.paused and self.board and not self.board:isMoving() and self.board:allBoxesOnTargets() then
        self:advanceLevel()
    end
end

function Playing:draw()
    if not self.board then return end
    self.camera:attach()
    self.board:draw(self:currentPlayer())
    self.camera:detach()

    love.graphics.setColor(0.93, 0.93, 0.9, 1)
    local player = self:currentPlayer()
    if player then
        love.graphics.print("Player: " .. player:getComponent("Player").className .. "  (G switch, Z undo, Esc menu)", 16, 14)
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
        if key == "up" or key == "w" then self.pauseSelection = (self.pauseSelection - 2) % 4 + 1
        elseif key == "down" or key == "s" then self.pauseSelection = self.pauseSelection % 4 + 1
        elseif key == "return" or key == "kpenter" then self:choosePauseOption()
        elseif key == "escape" and not self.completed then self.paused = false end
        return
    end
    if key == "escape" then self.paused, self.pauseSelection = true, 1; return end
    if self.board:isMoving() or self.transition then return end
    if key == "g" then
        if #self.board.players > 0 then self.activeIndex = self.activeIndex % #self.board.players + 1 end
    elseif key == "z" then
        self.history:undo()
    elseif DIRECTIONS[key] then
        local player = self:currentPlayer()
        if player then CharacterMovement.move(self.board, player, DIRECTIONS[key], self.history) end
    end
end

return Playing
