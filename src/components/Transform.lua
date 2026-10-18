local Component = require("src.core.Component")

local Transform = Component:extend()
Transform.componentName = "Transform"

function Transform:init(gridX, gridY, cellSize, layer)
    Component.init(self)
    self.gridX = gridX
    self.gridY = gridY
    self.cellSize = cellSize or 64
    self.layer = layer or 0
    self.x = (gridX + 0.5) * self.cellSize
    self.y = (gridY + 0.5) * self.cellSize
    self.tween = nil
end

function Transform:isMoving()
    return self.tween ~= nil
end

function Transform:moveTo(gridX, gridY)
    local dx, dy = gridX - self.gridX, gridY - self.gridY
    if dx == 0 and dy == 0 then
        return false
    end

    local distance = math.max(math.abs(dx), math.abs(dy))
    self.tween = {
        startX = self.x,
        startY = self.y,
        targetX = (gridX + 0.5) * self.cellSize,
        targetY = (gridY + 0.5) * self.cellSize,
        elapsed = 0,
        duration = math.min(math.max(distance, 1) * 0.12, 0.36),
    }
    self.gridX, self.gridY = gridX, gridY
    return true
end

function Transform:restore(snapshot)
    local dx, dy = snapshot.gridX - self.gridX, snapshot.gridY - self.gridY
    local distance = math.max(math.abs(dx), math.abs(dy))
    self.tween = {
        startX = self.x,
        startY = self.y,
        targetX = snapshot.x,
        targetY = snapshot.y,
        elapsed = 0,
        duration = math.min(math.max(distance, 1) * 0.12, 0.36),
    }
    self.gridX, self.gridY = snapshot.gridX, snapshot.gridY
end

function Transform:update(dt)
    local tween = self.tween
    if not tween then
        return
    end

    tween.elapsed = tween.elapsed + dt
    local progress = math.min(tween.elapsed / tween.duration, 1)
    local eased = progress * progress * (3 - 2 * progress)
    self.x = tween.startX + (tween.targetX - tween.startX) * eased
    self.y = tween.startY + (tween.targetY - tween.startY) * eased
    if progress >= 1 then
        self.x, self.y = tween.targetX, tween.targetY
        self.tween = nil
    end
end

return Transform
