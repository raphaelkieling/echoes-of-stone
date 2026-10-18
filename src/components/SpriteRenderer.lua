local Component = require("src.core.Component")

local SpriteRenderer = Component:extend()
SpriteRenderer.componentName = "SpriteRenderer"

function SpriteRenderer:init(image, animation, scale, renderLayer, outlineShader)
    Component.init(self)
    self.image = image
    self.animation = animation
    self.scale = scale or 1
    self.renderLayer = renderLayer or 0
    self.outlineShader = outlineShader
end

function SpriteRenderer:update(dt)
    self.animation:update(dt)
end

function SpriteRenderer:draw(context)
    local transform = self.owner:getComponent("Transform")
    local x, y = transform.x, transform.y
    if context and context.selected and self.outlineShader then
        love.graphics.setShader(self.outlineShader)
        for _, offset in ipairs({
            {-1.5, 0}, {1.5, 0}, {0, -1.5}, {0, 1.5},
            {-1.1, -1.1}, {1.1, -1.1}, {-1.1, 1.1}, {1.1, 1.1},
        }) do
            self.animation:draw(self.image, x + offset[1], y + offset[2], 0, self.scale, self.scale, 16, 16)
        end
        love.graphics.setShader()
    end
    self.animation:draw(self.image, x, y, 0, self.scale, self.scale, 16, 16)
end

return SpriteRenderer
