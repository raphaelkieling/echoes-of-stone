local Component = require("src.core.Component")

local Animation = Component:extend()
Animation.componentName = "Animation"

function Animation:init(animation)
    Component.init(self)
    self.current = assert(animation, "Animation needs an anim8 animation")
end

function Animation:update(dt)
    self.current:update(dt)
end

function Animation:set(animation)
    self.current = assert(animation, "Animation needs an anim8 animation")
end

function Animation:render(image, x, y, scale, shader, rotation)
    local animation = self.current
    rotation = rotation or 0
    if shader then
        love.graphics.setShader(shader)
        for _, offset in ipairs({
            {-1.5, 0}, {1.5, 0}, {0, -1.5}, {0, 1.5},
            {-1.1, -1.1}, {1.1, -1.1}, {-1.1, 1.1}, {1.1, 1.1},
        }) do
            animation:draw(image, x + offset[1], y + offset[2], rotation, scale, scale, 16, 16)
        end
        love.graphics.setShader()
    end
    animation:draw(image, x, y, rotation, scale, scale, 16, 16)
end

return Animation
