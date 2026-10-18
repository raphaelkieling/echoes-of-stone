local cameraLib = require("vendor.hump.camera")
local CharacterMovement = require("src.game.CharacterMovement")
local ActionHistory = require("src.game.ActionHistory")
local LevelLoader = require("src.game.LevelLoader")
local Keymap = require("src.settings.Keymap")
local BuildConfig = require("src.settings.BuildConfig")
local UI = require("src.ui.Theme")

local Playing = {}
Playing.__index = Playing
local FOLLOW_ZOOM = 1.8
local CAMERA_SMOOTHING = 9
local MOVE_REPEAT_DELAY = 0.3
local MOVE_REPEAT_INTERVAL = 0.12

function Playing.new(game)
    return setmetatable({
        game = game,
        mobileControls = game.mobileControls,
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
    self.mobileControls:resetTouches()
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
    self.game.completedLevels[self.levelPath] = true
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
	if self.paused then return end
	if self.heldMoveKey then
		if not love.keyboard.isDown(self.heldMoveKey) then
			self.heldMoveKey = nil
			self.moveRepeatTimer = 0
		else
			self:updateKeyboardMovement(dt)
			return
		end
	end
	self:updateMobileMovement(dt)
end

function Playing:updateKeyboardMovement(dt)
	self.moveRepeatTimer = self.moveRepeatTimer - dt
	if self.moveRepeatTimer > 0 or self.transition or self.board:isMoving() then return end

    local direction = Keymap.direction(self.heldMoveKey)
    local player = self:currentPlayer()
    if direction and player then
        CharacterMovement.move(self.board, player, direction, self.history)
    end
	self.moveRepeatTimer = MOVE_REPEAT_INTERVAL
end

function Playing:updateMobileMovement(dt)
	local direction = self.mobileControls:getDirection()
	if not direction then
		self.mobileMoveDirection = nil
		self.moveRepeatTimer = 0
		return
	end
	local directionKey = direction.x .. ":" .. direction.y
	if directionKey ~= self.mobileMoveDirection then
		self.mobileMoveDirection = directionKey
		self.moveRepeatTimer = MOVE_REPEAT_DELAY
		if not self.transition and not self.board:isMoving() then
			local player = self:currentPlayer()
			if player then CharacterMovement.move(self.board, player, direction, self.history) end
		end
		return
	end
	self.moveRepeatTimer = self.moveRepeatTimer - dt
	if self.moveRepeatTimer > 0 or self.transition or self.board:isMoving() then return end
	local player = self:currentPlayer()
	if player then CharacterMovement.move(self.board, player, direction, self.history) end
	self.moveRepeatTimer = MOVE_REPEAT_INTERVAL
end

function Playing:clearHeldMovement()
    self.heldMoveKey = nil
    self.moveRepeatTimer = 0
end

function Playing:draw()
    if not self.board then return end
    self.camera:attach()
    self.board:draw(self:currentPlayer())
    self.camera:detach()

    local width, height = love.graphics.getDimensions()
    local scale = UI.scale(width, height)

    if self.transition then
        local progress = self.transition.elapsed / self.transition.duration
        local alpha = math.sin(math.min(progress, 1) * math.pi)
        love.graphics.setColor(0, 0, 0, alpha * 0.35)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    end
    if not self.paused then self:drawLevelTimeline() end
    if self.paused then self:drawPause() end
    self:drawDevelopmentFilename(width, height, scale)
    self.mobileControls:draw()
end

function Playing:mobileAction(action)
	if action == "a" then
		if self.paused then
			self:choosePauseOption()
		elseif not self.board:isMoving() and not self.transition and #self.board.players > 0 then
			self.activeIndex = self.activeIndex % #self.board.players + 1
		end
	elseif action == "b" then
		if self.paused then
			if self.completed then
				self.game.scenes:switch("levels")
			else
				self.paused = false
			end
		elseif not self.board:isMoving() and not self.transition then
			self.history:undo()
		end
	end
end

function Playing:touchpressed(id, x, y)
	local action = self.mobileControls:touchpressed(id, x, y)
	if action then self:mobileAction(action) end
end

function Playing:touchmoved(id, x, y)
	self.mobileControls:touchmoved(id, x, y)
end

function Playing:touchreleased(id)
	self.mobileControls:touchreleased(id)
end

function Playing:drawDevelopmentFilename(width, height, scale)
    if not BuildConfig.developmentMode or not self.levelPath then return end
    local filename = self.levelPath:match("([^/]+)$") or self.levelPath
    UI.setColor("muted", 0.8)
    UI.setFont(16, width, height)
    love.graphics.printf(filename, 16 * scale, height - 34 * scale,
        width - 32 * scale, "right")
end

function Playing:drawLevelTimeline()
    local count = #self.levels
    if count == 0 then return end

    local width, height = love.graphics.getDimensions()
    local availableWidth = math.max(0, width - 64)
    local spacing = count > 1 and math.min(28, availableWidth / (count - 1)) or 0
    local firstX = (width - spacing * (count - 1)) / 2
    local y = height - 26
    local radius = math.min(6, spacing > 0 and spacing * 0.24 or 6)

    love.graphics.push("all")
    if count > 1 then
        love.graphics.setColor(0.43, 0.40, 0.34, 0.85)
        love.graphics.setLineWidth(3)
        love.graphics.line(firstX, y, firstX + spacing * (count - 1), y)
    end

    for index, level in ipairs(self.levels) do
        local x = firstX + spacing * (index - 1)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.circle("fill", x, y, radius + 2)
        if self.game.completedLevels[level.path] then
            UI.setColor("accent")
            love.graphics.circle("fill", x, y, radius)
        else
            local alpha = index == self.levelIndex and 1 or 0.58
            UI.setColor("text", alpha)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", x, y, radius)
        end
    end
    love.graphics.pop()
end

function Playing:drawPause()
    local width, height = love.graphics.getDimensions()
    local scale = UI.scale(width, height)
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, width, height)
    local panelWidth = math.min(width - 36 * scale, 620 * scale)
    local panelHeight = 300 * scale
    local panelX, panelY = (width - panelWidth) / 2, (height - panelHeight) / 2
    UI.drawPanel(panelX, panelY, panelWidth, panelHeight)

    UI.setColor("accent")
    UI.setFont(self.completed and 33 or 42, width, height)
    love.graphics.printf(self.completed and "ALL LEVELS COMPLETE" or "PAUSED",
        panelX + 20 * scale, panelY + 25 * scale, panelWidth - 40 * scale, "center")
    UI.drawDivider(panelX + 28 * scale, panelY + 78 * scale, panelWidth - 56 * scale)

    local options = self:getPauseOptions()
    local rowHeight = 43 * scale
    local firstRowY = panelY + 93 * scale
    for index, label in ipairs(options) do
        local y = firstRowY + (index - 1) * rowHeight
        if index == self.pauseSelection then
            UI.drawSelection(panelX + 22 * scale, y - 3 * scale, panelWidth - 44 * scale, 38 * scale)
        end
        UI.setColor(index == self.pauseSelection and "accent" or "text")
        UI.setFont(28, width, height)
        love.graphics.print((index == self.pauseSelection and "> " or "  ") .. label,
            panelX + 48 * scale, y)
    end

end

function Playing:getPauseOptions()
    if self.completed then return {"Replay level", "Level select", "Quit"} end
    return {"Resume", "Restart level", "Level select", "Quit"}
end

function Playing:choosePauseOption()
    if self.completed then
        if self.pauseSelection == 1 then
            self:loadLevel()
            self.paused, self.completed = false, false
        elseif self.pauseSelection == 2 then
            self.game.scenes:switch("levels")
        else
            love.event.quit()
        end
        return
    end
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
        local optionCount = #self:getPauseOptions()
        if Keymap.matches("menuUp", key) then self.pauseSelection = (self.pauseSelection - 2) % optionCount + 1
        elseif Keymap.matches("menuDown", key) then self.pauseSelection = self.pauseSelection % optionCount + 1
        elseif Keymap.matches("confirm", key) then self:choosePauseOption()
        elseif Keymap.matches("cancel", key) then
            if self.completed then self.game.scenes:switch("levels") else self.paused = false end
        end
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
