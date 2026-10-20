local Component = require("src.core.Component")
local MovementEffects = Component:extend()
MovementEffects.componentName = "MovementEffects"

local SILHOUETTE_SHADER = [[
vec4 effect(vec4 color, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) {
    vec4 pixel = Texel(texture, textureCoordinates);
    return vec4(color.rgb, pixel.a * color.a);
}
]]

local function center(gridX, gridY, cellSize)
	return (gridX + 0.5) * cellSize, (gridY + 0.5) * cellSize
end

function MovementEffects:init()
	Component.init(self)
	self.effects = {}
	self.silhouetteShader = love.graphics.newShader(SILHOUETTE_SHADER)
end

function MovementEffects:add(kind, data, duration)
	data.kind = kind
	data.age = 0
	data.duration = duration or 0.28
	self.effects[#self.effects + 1] = data
end

function MovementEffects:characterTrail(actor, fromX, fromY, toX, toY)
	local renderer = actor:getComponent("SpriteRenderer")
	local animation = actor:getComponent("Animation")
	local transform = actor:getComponent("Transform")
	local startX, startY = center(fromX, fromY, transform.cellSize)
	local endX, endY = center(toX, toY, transform.cellSize)
	self:add("wizard-trail", {
		animation = animation.current,
		image = renderer.image,
		scale = renderer.scale,
		startX = startX,
		startY = startY,
		endX = endX,
		endY = endY,
	}, 0.24)
end

function MovementEffects:dust(gridX, gridY, cellSize, color)
	local x, y = center(gridX, gridY, cellSize)
	self:add("dust", {x = x, y = y, color = color}, 0.24)
end

function MovementEffects:update(dt)
	for index = #self.effects, 1, -1 do
		local effect = self.effects[index]
		effect.age = effect.age + dt
		if effect.age >= effect.duration then table.remove(self.effects, index) end
	end
end

local function setColor(color, alpha)
	love.graphics.setColor(color[1], color[2], color[3], alpha)
end

local function drawWizardTrail(self, effect, progress)
	local fade = 1 - progress
	love.graphics.setShader(self.silhouetteShader)
	for index = 0, 6 do
		local amount = index / 6
		local x = effect.startX + (effect.endX - effect.startX) * amount
		local y = effect.startY + (effect.endY - effect.startY) * amount
		local shade = amount
		local alpha = (0.52 - amount * 0.18) * fade
		love.graphics.setColor(shade, shade, shade, alpha)
		effect.animation:draw(effect.image, x, y, 0,
			effect.scale, effect.scale, 16, 16)
	end
	love.graphics.setShader()
end

local function drawDust(_manager, effect, progress)
	local fade = 1 - progress
	local offsets = {{-1, 0}, {1, 0}, {-0.6, -0.5}, {0.6, -0.5}}
	for index, offset in ipairs(offsets) do
		local spread = 10 + progress * 18
		setColor(effect.color, fade * 0.5)
		love.graphics.circle("fill", effect.x + offset[1] * spread,
			effect.y + offset[2] * spread + progress * 8, 3 + progress * 3)
	end
end

local DRAWERS = {
	["wizard-trail"] = drawWizardTrail,
	dust = drawDust,
}

function MovementEffects.registerDrawer(kind, draw)
	assert(type(kind) == "string" and type(draw) == "function", "invalid movement effect drawer")
	DRAWERS[kind] = draw
end

function MovementEffects:draw()
	if #self.effects == 0 then return end
	love.graphics.push("all")
	for _, effect in ipairs(self.effects) do
		local progress = math.min(effect.age / effect.duration, 1)
		local draw = DRAWERS[effect.kind]
		if draw then draw(self, effect, progress) end
	end
	love.graphics.pop()
end

function MovementEffects:clear()
	self.effects = {}
end

return MovementEffects
