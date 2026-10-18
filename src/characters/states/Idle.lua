local Class = require("src.core.Class")

local Idle = Class:extend()

local ANGLE = math.rad(1.4)
local HORIZONTAL_SWAY = 0.65
local VERTICAL_SWAY = 0.45

function Idle:init(owner)
    self.owner = owner
    self.elapsed = 0
    self.weight = 0
    local transform = owner:getComponent("Transform")
    self.phase = ((transform.gridX * 7 + transform.gridY * 11) % 6) * math.pi / 3
end

function Idle:update(dt)
    self.elapsed = self.elapsed + dt
    local transform = self.owner:getComponent("Transform")
    local targetWeight = transform:isMoving() and 0 or 1
    local smoothing = 1 - math.exp(-dt * 12)
    self.weight = self.weight + (targetWeight - self.weight) * smoothing
end

function Idle:visualOffset()
    local wave = self.elapsed * 1.8 + self.phase
    local sway = math.sin(wave) * self.weight
    return sway * ANGLE,
        sway * HORIZONTAL_SWAY,
        math.cos(wave * 0.8) * VERTICAL_SWAY * self.weight
end

return Idle
