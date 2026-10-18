local anim8 = require("vendor.anim8")
local SpriteRenderer = require("src.components.SpriteRenderer")

local Assets = {}
Assets.__index = Assets

local outlineShaderSource = [[
vec4 effect(vec4 color, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) {
    vec4 pixel = Texel(texture, textureCoordinates);
    return vec4(1.0, 1.0, 1.0, pixel.a) * color;
}
]]

function Assets.new()
    local tiles = love.graphics.newImage("assets/tiles.png")
    local players = love.graphics.newImage("assets/rogues.png")
    tiles:setFilter("nearest", "nearest")
    players:setFilter("nearest", "nearest")

    return setmetatable({
        tiles = tiles,
        players = players,
        tileGrid = anim8.newGrid(32, 32, tiles:getWidth(), tiles:getHeight()),
        playerGrid = anim8.newGrid(32, 32, players:getWidth(), players:getHeight()),
        outlineShader = love.graphics.newShader(outlineShaderSource),
    }, Assets)
end

function Assets:tileRenderer(scale, layer)
    return SpriteRenderer(self.tiles, scale or 2, layer)
end

function Assets:tileAnimation(tileX, tileY)
    return anim8.newAnimation(self.tileGrid(tileX + 1, tileY + 1), 1)
end

function Assets:playerAnimation(tileX, tileY)
    return anim8.newAnimation(self.playerGrid(tileX + 1, tileY + 1), 1)
end

function Assets:playerRenderer(scale, layer)
    return SpriteRenderer(self.players, scale or 2.25, layer or 3, self.outlineShader)
end

return Assets
