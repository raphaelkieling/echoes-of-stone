local UI = require("src.ui.Theme")

local MobileControls = {}
MobileControls.__index = MobileControls

function MobileControls.new()
	local osName = love.system and love.system.getOS and love.system.getOS() or ""
	return setmetatable({
		enabled = osName == "Android" or osName == "iOS",
		joystickTouch = nil,
		joystickX = 0,
		joystickY = 0,
		buttons = {},
	}, MobileControls)
end

function MobileControls:layout()
	local width, height = love.graphics.getDimensions()
	local scale = UI.scale(width, height)
	local joystick = {
		x = 108 * scale,
		y = height - 122 * scale,
		radius = 78 * scale,
		knobRadius = 34 * scale,
	}
	local buttons = {
		A = {x = width - 172 * scale, y = height - 92 * scale, radius = 45 * scale},
		B = {x = width - 86 * scale, y = height - 184 * scale, radius = 45 * scale},
	}
	return joystick, buttons, scale
end

function MobileControls:touchpressed(id, x, y)
	if not self.enabled then return nil end
	local joystick, buttons = self:layout()
	for name, button in pairs(buttons) do
		local dx, dy = x - button.x, y - button.y
		if dx * dx + dy * dy <= button.radius * button.radius then
			self.buttons[id] = name
			return name:lower()
		end
	end
	local dx, dy = x - joystick.x, y - joystick.y
	if dx * dx + dy * dy <= (joystick.radius + 40) ^ 2 then
		self.joystickTouch = id
		self.joystickX, self.joystickY = x, y
	end
	return nil
end

function MobileControls:touchmoved(id, x, y)
	if self.enabled and self.joystickTouch == id then
		self.joystickX, self.joystickY = x, y
	end
end

function MobileControls:touchreleased(id)
	if self.joystickTouch == id then
		self.joystickTouch = nil
		self.joystickX, self.joystickY = 0, 0
	end
	self.buttons[id] = nil
end

function MobileControls:resetTouches()
	self.joystickTouch = nil
	self.joystickX, self.joystickY = 0, 0
	self.buttons = {}
end

function MobileControls:getDirection()
	if not self.enabled or not self.joystickTouch then return nil end
	local joystick = self:layout()
	local dx, dy = self.joystickX - joystick.x, self.joystickY - joystick.y
	local threshold = 16 * UI.scale(love.graphics.getDimensions())
	if math.max(math.abs(dx), math.abs(dy)) < threshold then return nil end
	if math.abs(dx) > math.abs(dy) then
		return {x = dx < 0 and -1 or 1, y = 0}
	end
	return {x = 0, y = dy < 0 and -1 or 1}
end

function MobileControls:draw()
	if not self.enabled then return end
	local joystick, buttons, scale = self:layout()
	love.graphics.push("all")
	love.graphics.setLineWidth(3 * scale)
	UI.setColor("panel", 0.58)
	love.graphics.circle("fill", joystick.x, joystick.y, joystick.radius)
	UI.setColor("muted", 0.78)
	love.graphics.circle("line", joystick.x, joystick.y, joystick.radius)

	local knobX, knobY = joystick.x, joystick.y
	if self.joystickTouch then
		local dx, dy = self.joystickX - joystick.x, self.joystickY - joystick.y
		local length = math.sqrt(dx * dx + dy * dy)
		local maxLength = joystick.radius - joystick.knobRadius
		if length > maxLength then dx, dy = dx * maxLength / length, dy * maxLength / length end
		knobX, knobY = joystick.x + dx, joystick.y + dy
	end
	UI.setColor("selected", 0.9)
	love.graphics.circle("fill", knobX, knobY, joystick.knobRadius)
	UI.setColor("accent", 0.9)
	love.graphics.circle("line", knobX, knobY, joystick.knobRadius)

	for name, button in pairs(buttons) do
		local pressed = false
		for _, activeName in pairs(self.buttons) do
			if activeName == name then pressed = true end
		end
		UI.setColor(pressed and "selected" or "panel", pressed and 0.94 or 0.72)
		love.graphics.circle("fill", button.x, button.y, button.radius)
		UI.setColor("accent", 0.95)
		love.graphics.circle("line", button.x, button.y, button.radius)
		UI.setFont(36, love.graphics.getDimensions())
		love.graphics.printf(name, button.x - button.radius, button.y - 19 * scale,
			button.radius * 2, "center")
	end
	love.graphics.pop()
end

return MobileControls
