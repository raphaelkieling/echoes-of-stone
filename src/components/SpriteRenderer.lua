local Component = require("src.core.Component")

local SpriteRenderer = Component:extend()
SpriteRenderer.componentName = "SpriteRenderer"

function SpriteRenderer:init(image, scale, renderLayer, outlineShader)
    Component.init(self)
    self.image = image
    self.scale = scale or 1
    self.renderLayer = renderLayer or 0
    self.outlineShader = outlineShader
end

function SpriteRenderer:draw(context)
    local transform = self.owner:getComponent("Transform")
    local animation = self.owner:getComponent("Animation")
    local x, y = transform.x, transform.y
    local rotation = 0
    local stateMachine = self.owner:getComponent("StateMachine")
    if stateMachine then
        local swayRotation, offsetX, offsetY = stateMachine:visualOffset()
        x, y = x + offsetX, y + offsetY
        rotation = swayRotation
    end
    local shake = self.owner:getComponent("Shake")
    if shake then
        local offsetX, offsetY = shake:offset()
        x, y = x + offsetX, y + offsetY
    end
    animation:render(self.image, x, y, self.scale,
        context and context.selected and self.outlineShader or nil, rotation)
end

function SpriteRenderer:setAppearance(image, scale, renderLayer, outlineShader)
    self.image = image or self.image
    self.scale = scale or self.scale
    self.renderLayer = renderLayer or self.renderLayer
    self.outlineShader = outlineShader or self.outlineShader
end

return SpriteRenderer
