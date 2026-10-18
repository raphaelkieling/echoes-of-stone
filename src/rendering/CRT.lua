local Class = require("src.core.Class")

local CRT = Class:extend()

local shaderSource = [[
vec4 effect(vec4 color, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) {
    vec4 pixel = Texel(texture, textureCoordinates);
    float scanline = 0.86 + 0.14 * sin(screenCoordinates.y * 1.5707963);
    return vec4(pixel.rgb * scanline, pixel.a) * color;
}
]]

function CRT:init()
    self.shader = love.graphics.newShader(shaderSource)
    self:resize(love.graphics.getDimensions())
end

function CRT:resize(width, height)
    self.canvas = love.graphics.newCanvas(width, height)
    self.canvas:setFilter("nearest", "nearest")
end

function CRT:draw(drawScene)
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0.035, 0.045, 0.065, 1)
    love.graphics.setColor(1, 1, 1, 1)
    drawScene()
    love.graphics.setCanvas()
    love.graphics.setShader(self.shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, 0, 0)
    love.graphics.setShader()
end

return CRT
