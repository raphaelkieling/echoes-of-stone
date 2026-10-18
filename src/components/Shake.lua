local Component = require("src.core.Component")

local Shake = Component:extend()
Shake.componentName = "Shake"

function Shake:init(amplitude, duration, oscillations)
    Component.init(self)
    self.amplitude = amplitude or 1.4
    self.duration = duration or 0.18
    self.oscillations = oscillations or 3
    self.elapsed = nil
    self.directionX, self.directionY = 1, 0
end

function Shake:trigger(directionX, directionY)
    directionX, directionY = directionX or 1, directionY or 0
    local length = math.sqrt(directionX * directionX + directionY * directionY)
    if length == 0 then
        directionX, directionY, length = 1, 0, 1
    end
    self.directionX, self.directionY = directionX / length, directionY / length
    self.elapsed = 0
end

function Shake:update(dt)
    if self.elapsed == nil then return end
    self.elapsed = self.elapsed + dt
    if self.elapsed >= self.duration then
        self.elapsed = nil
    end
end

function Shake:offset()
    if self.elapsed == nil then return 0, 0 end
    local progress = self.elapsed / self.duration
    local wave = math.sin(progress * self.oscillations * math.pi * 2)
    local amount = self.amplitude * (1 - progress) * wave
    return self.directionX * amount, self.directionY * amount
end

return Shake
