local cameraLib = require("vendor.hump.camera")
local Scene = require("src.core.Scene")
local StateMachine = require("src.core.StateMachine")
local ActionHistory = require("src.game.ActionHistory")
local LevelLoader = require("src.game.LevelLoader")
local Keymap = require("src.settings.Keymap")
local UndoHistoryOverlay = require("src.dev.UndoHistoryOverlay")
local PlayingHud = require("src.screens.PlayingHud")
local NarrativeCatalog = require("src.game.narratives.NarrativeCatalog")
local SequenceRunner = require("src.game.narratives.SequenceRunner")
local PlayingStates = {
	entering = require("src.screens.playing_states.Entering"),
	playing = require("src.screens.playing_states.Playing"),
	paused = require("src.screens.playing_states.Paused"),
	transitioning = require("src.screens.playing_states.LevelTransition"),
	completed = require("src.screens.playing_states.Completed"),
	narrative = require("src.screens.playing_states.Narrative"),
}

local PlayingScene = Scene:extend()
local FOLLOW_ZOOM = 1.8
local CAMERA_SMOOTHING = 9
local MOVE_REPEAT_DELAY = 0.3
local MOVE_REPEAT_INTERVAL = 0.12
local UNDO_REPEAT_INTERVAL = 0.6

local function boxesOnTargets(board)
	local boxes = {}
	for _, box in ipairs(board.boxes) do
		local transform = box:getComponent("Transform")
		local cell = board:getCell(transform.gridX, transform.gridY)
		if cell and cell.target then boxes[box] = true end
	end
	return boxes
end

local function hasBoxArrivedOnTarget(board, previousBoxesOnTargets)
	for _, box in ipairs(board.boxes) do
		if not previousBoxesOnTargets[box] then
			local transform = box:getComponent("Transform")
			local cell = board:getCell(transform.gridX, transform.gridY)
			if cell and cell.target then return true end
		end
	end
	return false
end

function PlayingScene:init(game)
	Scene.init(self, "PlayingScene", game)
	self.mobileControls = game.mobileControls
	self.camera = cameraLib(0, 0, 1)
	self.history = ActionHistory()
	self.componentStateSubscription = self.game.events:on("component.state_changed", function(payload)
		if payload.cause ~= "flame" then return end
		local object = self.board and self.board.objects[payload.objectIndex]
		if object and payload.component then
			self.history:appendToLatest({{
				object = object,
				component = payload.component,
				state = payload.previousState,
			}})
		end
	end)
	self.levelIndex = 1
	self.transition = nil
	self.cameraIntro = nil
	self.heldMoveKey = nil
	self.moveRepeatTimer = 0
	self.heldUndoKey = nil
	self.undoRepeatTimer = 0
	self.pauseSelection = 1
	self.states = StateMachine(self, PlayingStates)
	self.narratives = self:addChild(SequenceRunner(self.game.events, NarrativeCatalog.load(), {
		onBlockingStarted = function(narrative) self:onNarrativeStarted(narrative) end,
		onBlockingFinished = function(narrative) self:onNarrativeFinished(narrative) end,
	}))
	self.hud = self:addChild(PlayingHud(self))
end

function PlayingScene:enter(levelIndex)
    self.levels = LevelLoader.listLevels()
    self.levelIndex = levelIndex or 1
    self.cameraMode = "map"
    self.mobileControls:resetTouches()
    self:loadLevel()
    self.states:change("entering")
end

function PlayingScene:leave()
	self:clearHeldMovement()
	self.mobileControls:resetTouches()
	self.narratives:onDetach()
	self.game.events:off(self.componentStateSubscription)
end

function PlayingScene:loadLevel()
    local level = assert(self.levels[self.levelIndex], "level index out of range")
    self.heldMoveKey = nil
    self.pendingDirection = nil
    self.mobileMoveDirection = nil
    self.moveRepeatTimer = 0
    self.levelPath = level.path
    if self.board then self:removeChild(self.board) end
    self.board = LevelLoader.load(level.path, self.game.assets, self.game.events)
    self.board.drawSpace = "world"
    self:addChild(self.board)
    if self.game.console then
        self.game.console:applyToggles({game = self.game, scene = self, board = self.board})
    end
    self.game.events:emit("level.started", {
		level = level.name,
		path = level.path,
		index = self.levelIndex,
		players = #self.board.players,
	})
    self.history:clear()
    self.activeIndex = 1
    self:snapCameraToTarget()
end

function PlayingScene:beginCameraIntro()
    local _, _, targetZoom = self:cameraTarget()
    local startZoom = targetZoom * 1.12
    self.camera.scale = startZoom
    self.cameraIntro = {
        elapsed = 0,
        duration = 0.5,
        startZoom = startZoom,
        targetZoom = targetZoom,
    }
end

function PlayingScene:mapCameraTarget()
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

function PlayingScene:cameraTarget()
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

function PlayingScene:snapCameraToTarget()
    local x, y, zoom = self:cameraTarget()
    self.camera:lookAt(x, y)
    self.camera.scale = zoom
end

function PlayingScene:currentPlayer()
    if #self.board.players == 0 then return nil end
    return self.board.players[self.activeIndex]
end

function PlayingScene:loadNextLevel()
	self.levelIndex = self.levelIndex + 1
	self:loadLevel()
end

function PlayingScene:jumpToLevel(index, levels)
	self.levels = levels or self.levels
	self.levelIndex = index
	self.transition = nil
	self:loadLevel()
	self.states:change("entering")
end

function PlayingScene:completeLevel()
    self.game.levelProgress:markCompleted(self.levelPath)
	self.game.events:emit("level.completed", {level = self.levelPath, index = self.levelIndex})
    if self.levelIndex < #self.levels then
        self.states:change("transitioning")
    else
        self.states:change("completed")
    end
end

function PlayingScene:onNarrativeStarted(_narrative)
	if self.states:is("narrative") then return end
	self.narrativeReturnState = self.states.currentName or "playing"
	self:clearHeldMovement()
	self.mobileControls:resetTouches()
	self.states:change("narrative")
end

function PlayingScene:onNarrativeFinished(_narrative)
	if not self.states:is("narrative") then return end
	local returnState = self.narrativeReturnState or "playing"
	self.narrativeReturnState = nil
	self.states:change(returnState)
end

function PlayingScene:update(dt)
	self.states:update(dt)
	self:updateChildren(dt)
end

function PlayingScene:updatePlaying(dt)
	self:updateCamera(dt)
	self:updateBufferedMovement()
	if not self.states:is("playing") then return end
    self:updateHeldMovement(dt)
	if not self.states:is("playing") then return end
    self:updateHeldUndo(dt)
	if self.states:is("playing") and self.board and not self.board:isMoving()
		and self.board:allTargetsCovered() then
        self:completeLevel()
    end
end

function PlayingScene:updateCamera(dt)
	local targetX, targetY, targetZoom = self:cameraTarget()
	local smooth = 1 - math.exp(-CAMERA_SMOOTHING * dt)
	self.camera.x = self.camera.x + (targetX - self.camera.x) * smooth
	self.camera.y = self.camera.y + (targetY - self.camera.y) * smooth
	if self.cameraIntro then
		local intro = self.cameraIntro
		intro.elapsed = intro.elapsed + dt
		local progress = math.min(intro.elapsed / intro.duration, 1)
		local eased = 1 - (1 - progress) ^ 3
		self.camera.scale = intro.startZoom + (intro.targetZoom - intro.startZoom) * eased
		if progress >= 1 then self.cameraIntro = nil end
	else
		self.camera.scale = self.camera.scale + (targetZoom - self.camera.scale) * smooth
	end
end

function PlayingScene:movePlayer(direction)
	local player = self:currentPlayer()
	if not player then return false end
	local class = player:getComponent("CharacterClass")
	local previousBoxesOnTargets = boxesOnTargets(self.board)
	local moved, changes = player:getComponent("CharacterMovement"):move(
		self.board, direction, self.history)
	self.game.events:emit("player.moved", {
		level = self.levelPath,
		playerIndex = self.activeIndex,
		characterClass = class.id,
		directionX = direction.x,
		directionY = direction.y,
		moved = moved,
	})
	if moved then self.board:processMovement(changes) end
	self.game.audio:play(moved and "move" or "invalidMovement")
	if moved and hasBoxArrivedOnTarget(self.board, previousBoxesOnTargets) then
		self.game.audio:play("target")
	end
	return moved
end

function PlayingScene:undo()
	local undone = self.history:undo()
	if undone then self.game.audio:play("undo") end
	self.game.events:emit("player.undo", {level = self.levelPath, undone = undone})
	return undone
end

function PlayingScene:selectNextPlayer()
	if #self.board.players == 0 then return end
	local previousIndex = self.activeIndex
	self.activeIndex = self.activeIndex % #self.board.players + 1
	self.game.events:emit("player.switched", {from = previousIndex, to = self.activeIndex})
end

function PlayingScene:updateBufferedMovement()
	if not self.pendingDirection or self.states:is("transitioning") or self.board:isMoving() then return end
	local direction = self.pendingDirection
	self.pendingDirection = nil
	self:movePlayer(direction)
	self.moveRepeatTimer = MOVE_REPEAT_INTERVAL
end

function PlayingScene:updateHeldMovement(dt)
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

function PlayingScene:updateKeyboardMovement(dt)
	self.moveRepeatTimer = self.moveRepeatTimer - dt
	if self.moveRepeatTimer > 0 or self.states:is("transitioning") or self.board:isMoving() then return end

    local direction = Keymap.direction(self.heldMoveKey)
	if direction then self:movePlayer(direction) end
	self.moveRepeatTimer = MOVE_REPEAT_INTERVAL
end

function PlayingScene:updateMobileMovement(dt)
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
		if not self.states:is("transitioning") and not self.board:isMoving() then
			self:movePlayer(direction)
		elseif self.board:isMoving() and not self.states:is("transitioning") then
			self.pendingDirection = direction
		end
		return
	end
	self.moveRepeatTimer = self.moveRepeatTimer - dt
	if self.moveRepeatTimer > 0 or self.states:is("transitioning") or self.board:isMoving() then return end
	self:movePlayer(direction)
	self.moveRepeatTimer = MOVE_REPEAT_INTERVAL
end

function PlayingScene:updateHeldUndo(dt)
	if not self.heldUndoKey then return end
	if not love.keyboard.isDown(self.heldUndoKey) then
		self.heldUndoKey = nil
		self.undoRepeatTimer = 0
		return
	end

	if #self.history.actions == 0 then
		self.heldUndoKey = nil
		self.undoRepeatTimer = 0
		return
	end

	self.undoRepeatTimer = self.undoRepeatTimer - dt
	if self.undoRepeatTimer > 0 or self.board:isMoving() then return end

	if not self:undo() then
		self.heldUndoKey = nil
		self.undoRepeatTimer = 0
		return
	end
	self.undoRepeatTimer = UNDO_REPEAT_INTERVAL
end

function PlayingScene:clearHeldMovement()
    self.heldMoveKey = nil
    self.moveRepeatTimer = 0
	self.pendingDirection = nil
	self.mobileMoveDirection = nil
	self.heldUndoKey = nil
	self.undoRepeatTimer = 0
end

function PlayingScene:draw()
    if not self.board then return end
    self.camera:attach()
    self:drawChildren("world", self)
    local undoPaths
    if self.board.debugShowUndoHistory then
        undoPaths = UndoHistoryOverlay.drawWorld(self.board, self.history.actions)
    end
    self.camera:detach()

    if self.transition then
        local progress = self.transition.elapsed / self.transition.duration
        local alpha = math.sin(math.min(progress, 1) * math.pi)
        love.graphics.setColor(0, 0, 0, alpha * 0.35)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    end
    self:drawChildren("screen", self)
    if undoPaths then UndoHistoryOverlay.drawLegend(undoPaths) end
end

function PlayingScene:mobileAction(action)
	if self.states:is("paused") or self.states:is("completed") then
		self.states:dispatch("mobileAction", action)
		return
	end
	if self.states:is("narrative") then
		self.states:dispatch("mobileAction", action)
		return
	end
	if not self.states:is("playing") then return end
	if action == "b" then
		if not self.board:isMoving() then self:undo() end
		return
	end
	self.game.audio:play("uiClick")
	if action == "a" then
		if not self.board:isMoving() and #self.board.players > 0 then
			self:selectNextPlayer()
		end
	end
end

function PlayingScene:touchpressed(id, x, y)
	local action = self.mobileControls:touchpressed(id, x, y)
	if action then self:mobileAction(action) end
end

function PlayingScene:touchmoved(id, x, y)
	self.mobileControls:touchmoved(id, x, y)
end

function PlayingScene:touchreleased(id)
	self.mobileControls:touchreleased(id)
end

function PlayingScene:getPauseOptions(completed)
    if completed == nil then completed = self.states:is("completed") end
    if completed then return {"Replay level", "Level select", "Main menu", "Quit"} end
    return {"Resume", "Restart level", "Level select", "Main menu", "Quit"}
end

function PlayingScene:choosePauseOption(completed)
    if completed then
        if self.pauseSelection == 1 then
            self:loadLevel()
            self.states:change("entering")
        elseif self.pauseSelection == 2 then
            self.game.scenes:switch("levels")
        elseif self.pauseSelection == 3 then
            self.game.scenes:switch("menu")
        else
            love.event.quit()
        end
        return
    end
    if self.pauseSelection == 1 then
        self.states:change("playing")
    elseif self.pauseSelection == 2 then
        self:loadLevel()
        self.states:change("entering")
    elseif self.pauseSelection == 3 then
        self.game.scenes:switch("levels")
    elseif self.pauseSelection == 4 then
        self.game.scenes:switch("menu")
    else
        love.event.quit()
    end
end

function PlayingScene:handlePauseKey(key, completed)
    local optionCount = #self:getPauseOptions(completed)
    if Keymap.matches("menuUp", key) then
        self.pauseSelection = (self.pauseSelection - 2) % optionCount + 1
        self.game.audio:play("uiClick")
    elseif Keymap.matches("menuDown", key) then
        self.pauseSelection = self.pauseSelection % optionCount + 1
        self.game.audio:play("uiClick")
    elseif Keymap.matches("confirm", key) then
        self.game.audio:play("uiClick")
        self:choosePauseOption(completed)
    elseif Keymap.matches("cancel", key) then
        self.game.audio:play("uiClick")
        if completed then self.game.scenes:switch("levels")
        else self.states:change("playing") end
    end
end

function PlayingScene:handlePauseAction(action, completed)
	self.game.audio:play("uiClick")
	if action == "a" then
		self:choosePauseOption(completed)
	elseif action == "b" then
		if completed then self.game.scenes:switch("levels")
		else self.states:change("playing") end
	end
end

function PlayingScene:handleCameraKey(key)
    if not Keymap.matches("toggleMapView", key) then return false end
    self.cameraIntro = nil
    self.cameraMode = self.cameraMode == "map" and "follow" or "map"
    return true
end

function PlayingScene:handlePlayingKey(key)
    if Keymap.matches("pause", key) then
		self:clearHeldMovement()
        self.game.audio:play("uiClick")
        self.states:change("paused")
        return
    end
    if self:handleCameraKey(key) then return end
    local direction = Keymap.direction(key)
    if direction then
        self.heldMoveKey = key
        self.moveRepeatTimer = MOVE_REPEAT_DELAY
        if self.states:is("transitioning") then return end
        if self.board:isMoving() then
			self.pendingDirection = direction
		else
			self.pendingDirection = nil
			self:movePlayer(direction)
        end
        return
    end
    if self.board:isMoving() or self.states:is("transitioning") then return end
    if Keymap.matches("switchPlayer", key) then
        self:selectNextPlayer()
    elseif Keymap.matches("undo", key) then
		if self.heldUndoKey ~= key then
			self.heldUndoKey = key
			self.undoRepeatTimer = UNDO_REPEAT_INTERVAL
			self:undo()
		end
    end
end

function PlayingScene:keypressed(key)
	self.states:dispatch("keypressed", key)
end

return PlayingScene
